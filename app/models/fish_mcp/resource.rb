module FishMcp
  module Resource
    module_function

    def url(request = nil)
      ENV["MCP_RESOURCE_URL"].presence || "#{request&.base_url || default_base_url}/mcp"
    end

    def authorization_server(request = nil)
      ENV["MCP_OIDC_ISSUER"].presence || request&.base_url || default_base_url
    end

    def metadata_url(request = nil)
      "#{request&.base_url || default_base_url}/.well-known/oauth-protected-resource"
    end

    def default_base_url
      Rails.application.routes.default_url_options[:host].presence&.then { |host| "https://#{host}" } || "http://localhost:3000"
    end
  end
end
