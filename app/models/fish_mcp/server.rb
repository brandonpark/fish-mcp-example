module FishMcp
  class Server
    TOOLS = [
      Tools::ListSchools,
      Tools::ListCalendars,
      Tools::SearchEvents,
      Tools::GetEvent,
      Tools::ListClassrooms,
      Tools::ListGroups,
      Tools::ListPosts,
      Tools::SearchPosts,
      Tools::ListFundraisers,
      Tools::GetMyVolunteerSummary,
      Tools::DraftCalendarImport,
      Tools::GetCalendarImport
    ].freeze

    def self.transport(context)
      server = MCP::Server.new(
        name: "fish",
        title: "FISH School Information",
        version: "1.0.0",
        instructions: "Read only content the connected FISH user can access. Calendar writes always create a review draft and require approval in FISH.",
        tools: TOOLS,
        server_context: context
      )

      MCP::Server::Transports::StreamableHTTPTransport.new(
        server,
        stateless: true,
        enable_json_response: true,
        serve_subscriptions_listen: false,
        allowed_hosts: [ context.request.host ]
      )
    end
  end
end
