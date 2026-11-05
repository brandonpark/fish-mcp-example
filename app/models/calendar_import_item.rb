class CalendarImportItem < ApplicationRecord
  belongs_to :calendar_import, inverse_of: :items
  belongs_to :event, optional: true
  belongs_to :duplicate_event, class_name: "Event", optional: true

  validates :position, uniqueness: { scope: :calendar_import_id }

  def assign_proposal(proposal)
    values = proposal.to_h.with_indifferent_access
    self.title = values[:title].to_s.strip.presence
    self.all_day = ActiveModel::Type::Boolean.new.cast(values[:all_day]) || false
    self.description = values[:description].to_s.presence
    self.location = values[:location].to_s.strip.presence
    zone = resolve_zone(values[:time_zone])
    self.time_zone = zone&.name
    self.starts_at = parse_time(values[:start] || values[:starts_at], zone)
    self.ends_at = parse_time(values[:end] || values[:ends_at], zone)
  rescue ArgumentError
    self.starts_at = self.ends_at = nil
  end

  def validate_proposal!
    messages = []
    messages << "Title is required." if title.blank?
    messages << "Title may not exceed 255 characters." if title.to_s.length > 255
    messages << "Start and end must be valid ISO-8601 dates or times." if starts_at.blank? || ends_at.blank?
    messages << "End must be after start." if starts_at && ends_at && ends_at <= starts_at
    messages << "An event may not last longer than 366 days." if starts_at && ends_at && ends_at - starts_at > 366.days
    messages << "Time zone is invalid." if time_zone.blank?
    messages << "Description may not exceed 10,000 characters." if description.to_s.length > 10_000
    messages << "Location may not exceed 500 characters." if location.to_s.length > 500

    self.duplicate_event = find_duplicate if messages.empty?
    warnings = []
    if duplicate_event
      warnings << "An active event with the same title, start, and end already exists."
      self.included = false if new_record? || event_id.nil?
    elsif messages.empty? && overlapping_events.exists?
      warnings << "This time overlaps another active event on the target calendar."
    end
    self.errors_payload = messages
    self.warnings_payload = warnings
    self
  end

  def errors_payload
    validation_errors || []
  end

  def errors_payload=(value)
    self.validation_errors = value
  end

  def warnings_payload
    self[:warnings] || []
  end

  def warnings_payload=(value)
    self[:warnings] = value
  end

  private
    def resolve_zone(value)
      ActiveSupport::TimeZone[value.presence || calendar_import.school.time_zone]
    end

    def parse_time(value, zone)
      return if value.blank? || zone.nil?
      string = value.to_s
      if all_day? && string.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        zone.parse(string).beginning_of_day
      elsif string.match?(/(?:Z|[+-]\d{2}:?\d{2})\z/)
        Time.iso8601(string)
      else
        zone.parse(string)
      end
    end

    def candidate_events
      calendar_import.calendar.events.active.where.not(id: event_id)
    end

    def find_duplicate
      candidate_events.where(starts_at: starts_at, ends_at: ends_at).detect { |candidate| candidate.title.casecmp?(title) }
    end

    def overlapping_events
      candidate_events.where("events.starts_at < ? AND events.ends_at > ?", ends_at, starts_at)
    end
end
