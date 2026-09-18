module FishMcp
  module Tools
    class SearchEvents < Tool
      tool_name "search_events"
      title "Search events"
      description "Searches accessible events in a required ISO-8601 range of at most 366 days."
      input_schema({ type: "object", properties: {
        school_id: { type: "string" }, starts_at: { type: "string", format: "date-time" },
        ends_at: { type: "string", format: "date-time" }, query: { type: "string", maxLength: 200 },
        cursor: { type: "string" }, limit: { type: "integer", minimum: 1, maximum: 100 }
      }, required: [ "school_id", "starts_at", "ends_at" ], additionalProperties: false })
      output_schema({ type: "object", properties: { events: { type: "array" }, next_cursor: { type: [ "string", "null" ] } }, required: [ "events" ] })
      annotations read_annotations

      def self.call(school_id:, starts_at:, ends_at:, query: nil, cursor: nil, limit: 30, server_context:)
        execute(server_context) do |context|
          school = context.school!(school_id)
          start_time, end_time = Time.iso8601(starts_at), Time.iso8601(ends_at)
          raise Error.validation("invalid_range", "End must be after start and the range may not exceed 366 days.") unless end_time > start_time && end_time - start_time <= 366.days

          scope = Event.visible_to(context.user, school: school).active
            .where("events.starts_at < ? AND events.ends_at > ?", end_time, start_time)
          scope = scope.where("LOWER(events.title) LIKE ?", "%#{Event.sanitize_sql_like(query.downcase)}%") if query.present?
          records, next_cursor = page(scope, cursor: cursor, limit: limit)
          success({ events: records.map { |event| event_payload(event, context) }, next_cursor: next_cursor })
        end
      end

      def self.event_payload(event, context)
        { id: event.id.to_s, title: event.title, starts_at: event.starts_at.iso8601,
          ends_at: event.ends_at.iso8601, all_day: event.all_day, time_zone: event.time_zone_identifier,
          description: event.description.to_plain_text.presence, location: event.address&.line1,
          calendar_ids: event.calendar_ids.map(&:to_s), url: context.school_url(event.school, "/calendar?event_id=#{event.id}") }
      end
    end
  end
end
