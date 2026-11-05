require "test_helper"

class CalendarImportTest < ActiveSupport::TestCase
  setup do
    @school = schools(:lincoln)
    @user = users(:admin)
    @school.update!(mcp_enabled_at: Time.current, mcp_enabled_by: @user)
    @calendar = @school.calendar!
    @application = OauthApplication.create!(name: "Test AI", redirect_uri: "https://client.example/callback",
      scopes: "school_content:read calendar_imports:write", confidential: false)
  end

  test "draft requires review and imports selected events atomically" do
    import = CalendarImport.create_draft!(user: @user, application: @application, calendar: @calendar,
      source_label: "Fall sports.pdf", proposals: [ {
        title: "Varsity Soccer vs Central", start: "2026-09-14T18:00:00-04:00",
        end: "2026-09-14T20:00:00-04:00", time_zone: "America/Detroit", location: "Main Field"
      } ])

    assert_predicate import, :draft?
    assert_equal 0, @school.events.where(calendar_import: import).count

    events = import.approve!(@user)

    assert_equal 1, events.size
    assert_predicate import.reload, :imported?
    assert_equal @user, events.first.created_by
    assert_equal @calendar, events.first.calendars.first
    assert_equal "mandatory", events.first.invite_level
    assert_equal "Main Field", events.first.address.line1
  end

  test "exact duplicates are excluded by default" do
    event = @school.events.create!(title: "Soccer", starts_at: Time.zone.parse("2026-09-14 18:00"),
      ends_at: Time.zone.parse("2026-09-14 20:00"), time_zone: @school.time_zone,
      calendars: [ @calendar ], created_by: @user)

    import = CalendarImport.create_draft!(user: @user, application: @application, calendar: @calendar,
      proposals: [ { title: "soccer", start: event.starts_at.iso8601, end: event.ends_at.iso8601,
        time_zone: @school.time_zone } ], source_label: nil)

    item = import.items.first
    assert_not item.included?
    assert_equal event, item.duplicate_event
    assert_predicate item.warnings_payload, :any?
  end

  test "disabled school cannot create a draft" do
    @school.update!(mcp_enabled_at: nil, mcp_enabled_by: nil)

    error = assert_raises(FishMcp::Error) do
      CalendarImport.create_draft!(user: @user, application: @application, calendar: @calendar,
        proposals: [ { title: "Game", start: "2026-09-14T18:00:00Z", end: "2026-09-14T20:00:00Z" } ], source_label: nil)
    end
    assert_equal "ai_access_disabled", error.code
  end
end
