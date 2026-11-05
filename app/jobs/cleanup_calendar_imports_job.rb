class CleanupCalendarImportsJob < ApplicationJob
  queue_as :background

  def perform
    CalendarImport.with_expired_drafts.find_each { |calendar_import| calendar_import.update!(status: :expired) }

    CalendarImport.where(detail_purged_at: nil, created_at: ...30.days.ago).find_each do |calendar_import|
      calendar_import.items.delete_all
      calendar_import.update_columns(detail_purged_at: Time.current, source_label: nil)
    end

    CalendarImport.where(created_at: ...1.year.ago).find_each(&:destroy!)
  end
end
