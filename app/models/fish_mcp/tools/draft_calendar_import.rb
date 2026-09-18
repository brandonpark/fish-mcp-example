module FishMcp
  module Tools
    class DraftCalendarImport < Tool
      tool_name "draft_calendar_import"
      title "Draft calendar import"
      description "Creates an expiring FISH review draft. It never creates calendar events directly."
      input_schema({ type: "object", properties: {
        school_id: { type: "string" }, calendar_id: { type: "string" },
        source_label: { type: "string", maxLength: 200 },
        events: { type: "array", minItems: 1, maxItems: 100, items: {
          type: "object", properties: {
            title: { type: "string", maxLength: 255 }, start: { type: "string" }, end: { type: "string" },
            all_day: { type: "boolean" }, time_zone: { type: "string" },
            description: { type: "string", maxLength: 10_000 }, location: { type: "string", maxLength: 500 }
          }, additionalProperties: false
        } }
      }, required: [ "school_id", "calendar_id", "events" ], additionalProperties: false })
      output_schema({ type: "object", properties: { calendar_import: { type: "object" } }, required: [ "calendar_import" ] })
      annotations({ read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false })

      def self.call(school_id:, calendar_id:, events:, source_label: nil, server_context:)
        execute(server_context, scope: "calendar_imports:write") do |context|
          school = context.school!(school_id)
          calendar = school.calendars.find(calendar_id)
          import = CalendarImport.create_draft!(user: context.user, application: context.application,
            calendar: calendar, source_label: source_label, proposals: events)
          success({ calendar_import: import_payload(import, context, include_items: true) },
            message: "Draft created. The user must review it in FISH before any events are added.")
        end
      end

      def self.import_payload(import, context, include_items: false)
        import.expire_if_needed!
        payload = {
          id: import.id.to_s, status: import.status, source_label: import.source_label,
          calendar_id: import.calendar_id.to_s, item_count: import.item_count,
          imported_count: import.imported_count, expires_at: import.expires_at.iso8601,
          review_url: import.draft? ? context.school_url(import.school, import.review_path) : nil
        }
        if include_items && import.detail_purged_at.nil?
          payload[:items] = import.items.map do |item|
            { position: item.position, included: item.included, title: item.title,
              starts_at: item.starts_at&.iso8601, ends_at: item.ends_at&.iso8601, all_day: item.all_day,
              time_zone: item.time_zone, errors: item.errors_payload, warnings: item.warnings_payload,
              duplicate_event_id: item.duplicate_event_id&.to_s, event_id: item.event_id&.to_s }
          end
        end
        payload
      end
    end
  end
end
