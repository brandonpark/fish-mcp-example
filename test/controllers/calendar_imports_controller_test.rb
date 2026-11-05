require "test_helper"

class CalendarImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = schools(:lincoln)
    @user = users(:staff)
    @membership = SchoolMembership.find_or_create_by!(user: @user, school: @school, role: :staff)
    @membership.update!(permissions: [ "school_admin" ])
    @school.update!(mcp_enabled_at: Time.current, mcp_enabled_by: @user)
    @application = OauthApplication.create!(name: "Test AI", redirect_uri: "https://client.example/callback",
      scopes: "school_content:read calendar_imports:write", confidential: false)
    @calendar = @school.calendar!
    @calendar_import = CalendarImport.create_draft!(user: @user, application: @application, calendar: @calendar,
      source_label: "Schedule.pdf", proposals: [ {
        title: "Basketball", start: "2026-11-02T18:00:00-05:00", end: "2026-11-02T20:00:00-05:00",
        time_zone: "America/Detroit"
      } ])
    @token = @calendar_import.review_token
    sign_in_as(@user)
  end

  test "owner can review and approve the signed draft" do
    get calendar_import_path(@token)
    assert_response :success
    assert_match "Nothing is added until you approve", response.body

    assert_difference -> { @school.events.where(calendar_import: @calendar_import).count }, 1 do
      post approve_calendar_import_path(@token)
    end

    assert_redirected_to calendar_import_path(@token)
    assert_predicate @calendar_import.reload, :imported?
  end

  test "another user cannot use the signed review URL" do
    sign_in_as(users(:teacher))

    get calendar_import_path(@token)

    assert_response :not_found
  end
end
