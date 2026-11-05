# EXCERPT from app/models/calendar.rb in the full FISH application (lines 155-174).
# Only the methods used by CalendarImport.authorize_draft! are shown.

class Calendar < ApplicationRecord
  # ...
  def self.school_wide_manager?(user, school)
    user.admin? || user.can?(:school_admin, school: school) || user.can?(:manage_events, school: school)
  end

  # Can this user rename, recolor, or delete this calendar — and post events to
  # it? The school-wide permission covers everything; beyond that, a class's
  # teachers and a group's admins own their own calendar.
  #
  # Checking several calendars at once? Use .postable_by — this re-asks the
  # school-wide question every call.
  def manageable_by?(user)
    return false if user.nil?
    return true if self.class.school_wide_manager?(user, school)

    case owner
    when Classroom then owner.teachers.exists?(user.id)
    when Group then owner.admin?(user)
    else false
    end
  end
  # ...
end
