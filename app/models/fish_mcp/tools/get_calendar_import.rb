module FishMcp
  module Tools
    class GetCalendarImport < Tool
      tool_name "get_calendar_import"
      title "Get calendar import"
      description "Reports whether a calendar draft awaits review, was imported, expired, or was rejected."
      input_schema({ type: "object", properties: { calendar_import_id: { type: "string" } }, required: [ "calendar_import_id" ], additionalProperties: false })
      output_schema({ type: "object", properties: { calendar_import: { type: "object" } }, required: [ "calendar_import" ] })
      annotations read_annotations

      def self.call(calendar_import_id:, server_context:)
        execute(server_context) do |context|
          import = context.user.calendar_imports.where(oauth_application: context.application).find(calendar_import_id)
          context.school!(import.school_id)
          success({ calendar_import: DraftCalendarImport.import_payload(import, context, include_items: true) })
        end
      end
    end
  end
end
