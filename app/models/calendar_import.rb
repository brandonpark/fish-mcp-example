class CalendarImport < ApplicationRecord
  REVIEW_TOKEN_PURPOSE = :calendar_import_review
  MAX_EVENTS = 100

  belongs_to :school
  belongs_to :calendar
  belongs_to :user
  belongs_to :oauth_application, optional: true
  has_many :items, -> { order(:position) }, class_name: "CalendarImportItem", dependent: :destroy
  has_many :imported_events, class_name: "Event", dependent: :nullify

  enum :status, { draft: "draft", imported: "imported", rejected: "rejected", expired: "expired" }, validate: true

  validates :payload_digest, :expires_at, presence: true
  validates :source_label, length: { maximum: 200 }, allow_blank: true

  scope :with_expired_drafts, -> { draft.where(expires_at: ...Time.current) }

  def self.create_draft!(user:, application:, calendar:, source_label:, proposals:)
    proposals = Array(proposals)
    raise FishMcp::Error.validation("empty_import", "At least one proposed event is required.") if proposals.empty?
    raise FishMcp::Error.validation("batch_too_large", "A calendar import may contain at most #{MAX_EVENTS} events.") if proposals.size > MAX_EVENTS

    school = calendar.school
    authorize_draft!(user, school, calendar)
    digest = Digest::SHA256.hexdigest(JSON.generate(proposals.as_json))

    transaction do
      import = create!(school: school, calendar: calendar, user: user, oauth_application: application,
        source_label: source_label, payload_digest: digest, expires_at: 24.hours.from_now, item_count: proposals.size)
      proposals.each_with_index do |proposal, index|
        import.items.create!(position: index, included: true).tap do |item|
          item.assign_proposal(proposal)
          item.validate_proposal!
          item.save!(validate: false)
        end
      end
      import
    end
  end

  def self.authorize_draft!(user, school, calendar)
    raise FishMcp::Error.forbidden("ai_access_disabled", "AI access is disabled for this school.") unless school.mcp_enabled?
    unless user.admin? || school.users.exists?(user.id)
      raise FishMcp::Error.forbidden("membership_revoked", "You are no longer a member of this school.")
    end
    raise FishMcp::Error.forbidden("events_disabled", "Calendar events are disabled for this school.") unless school.feature_enabled?(:events)
    raise FishMcp::Error.forbidden("calendar_forbidden", "You may not post to this calendar.") unless calendar.school_id == school.id && calendar.manageable_by?(user)
  end

  def review_token
    signed_id(purpose: REVIEW_TOKEN_PURPOSE, expires_in: [ expires_at - Time.current, 1.second ].max)
  end

  def review_path
    Rails.application.routes.url_helpers.calendar_import_path(review_token)
  end

  def expire_if_needed!
    update!(status: :expired) if draft? && expires_at <= Time.current
    expired?
  end

  def approve!(approving_user)
    event_ids = []
    with_lock do
      return imported_events.order(:id).to_a if imported?
      raise FishMcp::Error.validation("import_not_draft", "This import is no longer awaiting review.") if rejected? || expire_if_needed!
      raise FishMcp::Error.forbidden("wrong_user", "Only the user who created this draft may approve it.") unless user == approving_user

      self.class.authorize_draft!(approving_user, school.reload, calendar.reload)
      selected = items.reload.select(&:included?)
      selected.each(&:validate_proposal!)
      invalid = selected.select { |item| item.errors_payload.any? || item.duplicate_event_id.present? }
      if invalid.any?
        invalid.each { |item| item.save!(validate: false) }
        raise FishMcp::Error.validation("invalid_items", "Fix or remove every invalid or duplicate item before importing.", details: invalid.map(&:position))
      end

      selected.each do |item|
        attributes = {
          title: item.title, starts_at: item.starts_at, ends_at: item.ends_at, all_day: item.all_day,
          time_zone: item.time_zone, description: item.description, invite_level: :mandatory,
          created_by: approving_user, calendars: [ calendar ], calendar_import: self
        }
        attributes[:address_attributes] = { line1: item.location } if item.location.present?
        event = school.events.create!(attributes)
        item.update!(event: event)
        event_ids << event.id
      end
      update!(status: :imported, approved_at: Time.current, committed_at: Time.current, imported_count: event_ids.size)
    end

    event_ids.each do |event_id|
      NotifyEventAudienceJob.perform_later(event_id)
      NotifyEventPushJob.perform_later(event_id, "created")
    end
    Event.where(id: event_ids).order(:id).to_a
  end

  def reject!(rejecting_user)
    with_lock do
      raise FishMcp::Error.forbidden("wrong_user", "Only the user who created this draft may reject it.") unless user == rejecting_user
      update!(status: :rejected, rejected_at: Time.current) if draft?
    end
  end
end
