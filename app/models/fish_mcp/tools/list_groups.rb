module FishMcp
  module Tools
    class ListGroups < Tool
      tool_name "list_groups"
      title "List groups"
      description "Lists accessible group summaries. It never returns member rosters."
      input_schema({ type: "object", properties: { school_id: { type: "string" }, cursor: { type: "string" }, limit: { type: "integer", minimum: 1, maximum: 100 } }, required: [ "school_id" ], additionalProperties: false })
      output_schema({ type: "object", properties: { groups: { type: "array" }, next_cursor: { type: [ "string", "null" ] } }, required: [ "groups" ] })
      annotations read_annotations

      def self.call(school_id:, cursor: nil, limit: 30, server_context:)
        execute(server_context) do |context|
          school = context.school!(school_id)
          records, next_cursor = page(Group.feed_parents_for(context.user, school).reorder(nil), cursor: cursor, limit: limit)
          groups = records.map do |group|
            { id: group.id.to_s, name: group.name, administrators: group.admins.map(&:display_name),
              url: context.school_url(school, group.feed_path) }
          end
          success({ groups: groups, next_cursor: next_cursor })
        end
      end
    end
  end
end
