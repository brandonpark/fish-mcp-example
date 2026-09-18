module FishMcp
  class Tool < MCP::Tool
    class << self
      def success(payload, message: "Request completed.")
        MCP::Tool::Response.new(
          [ { type: "text", text: message } ],
          structured_content: payload.deep_stringify_keys
        )
      end

      def execute(server_context, scope: "school_content:read")
        server_context.require_scope!(scope)
        yield server_context
      rescue FishMcp::Error => error
        failure(error.kind, error.code, error.message, details: error.details)
      rescue ActiveRecord::RecordNotFound
        failure("not_found", "not_found", "The requested record was not found.")
      rescue ArgumentError, TypeError => error
        failure("validation", "invalid_arguments", error.message)
      end

      def failure(kind, code, message, details: nil)
        payload = { error: { kind: kind, code: code, message: message, details: details }.compact }
        MCP::Tool::Response.new(
          [ { type: "text", text: "#{code}: #{message}" } ],
          error: true,
          structured_content: payload.deep_stringify_keys
        )
      end

      def page(scope, cursor:, limit:)
        size = Integer(limit || 30).clamp(1, 100)
        primary_key = scope.klass.arel_table[scope.klass.primary_key]
        records = scope.where(primary_key.gt(Integer(cursor || 0))).order(primary_key.asc).limit(size + 1).to_a
        next_cursor = records.length > size ? records[size - 1].id.to_s : nil
        [ records.first(size), next_cursor ]
      end

      def read_annotations
        { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false }
      end
    end
  end
end
