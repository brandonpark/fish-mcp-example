module FishMcp
  class Context
    attr_reader :user, :access_token, :application, :request

    def initialize(user:, access_token:, application:, request:)
      @user = user
      @access_token = access_token
      @application = application
      @request = request
    end

    def require_scope!(scope)
      raise Error.forbidden("missing_scope", "The connection does not have the #{scope} scope.") unless access_token.acceptable?([ scope ])
    end

    def school!(id)
      school = accessible_schools.find_by(id: id)
      raise Error.not_found("school_not_found", "School not found.") unless school
      raise Error.forbidden("ai_access_disabled", "AI access is disabled for this school.") unless school.mcp_enabled?

      school
    end

    def accessible_schools
      user.admin? ? School.all : user.schools.distinct
    end

    def canonical_url(path)
      URI.join("#{request.base_url}/", path.sub(%r{\A/}, "")).to_s
    end

    def school_url(school, path = "/")
      app_host = ENV.fetch("APP_HOST", request.host)
      app_uri = URI.parse("http://#{app_host}")
      host = "#{school.slug}.#{app_uri.host}"
      port = app_uri.port == 80 ? (request.port.in?([ 80, 443 ]) ? nil : request.port) : app_uri.port
      URI::Generic.build(scheme: request.protocol.delete_suffix("://"), host: host,
        port: port, path: path.split("?", 2).first, query: path.split("?", 2).second).to_s
    end
  end
end
