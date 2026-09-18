module FishMcp
  module Tools
    class ListCalendars < Tool
      tool_name "list_calendars"
      title "List calendars"
      description "Lists calendars visible to the user, including whether the user may draft imports for each one."
      input_schema({ type: "object", properties: { school_id: { type: "string" } }, required: [ "school_id" ], additionalProperties: false })
      output_schema({ type: "object", properties: { calendars: { type: "array" } }, required: [ "calendars" ] })
      annotations read_annotations

      def self.call(school_id:, server_context:)
        execute(server_context) do |context|
          school = context.school!(school_id)
          postable_ids = Calendar.postable_by(context.user, school: school).map(&:id).to_set
          calendars = Calendar.visible_to(context.user, school: school).ordered.map do |calendar|
            { id: calendar.id.to_s, name: calendar.name, kind: calendar.owner_type.presence || "Custom",
              can_import: school.feature_enabled?(:events) && postable_ids.include?(calendar.id),
              url: context.school_url(school, "/calendars/#{calendar.id}") }
          end
          success({ calendars: calendars })
        end
      end
    end
  end
end
