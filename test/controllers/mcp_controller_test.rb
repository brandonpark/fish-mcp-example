require "test_helper"
require "base64"
require "digest"

class McpControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @application = OauthApplication.create!(name: "Test AI", redirect_uri: "https://client.example/callback",
      scopes: "school_content:read calendar_imports:write", confidential: false)
  end

  test "publishes protected resource metadata" do
    get "/.well-known/oauth-protected-resource"

    assert_response :success
    assert_equal "http://www.example.com/mcp", response.parsed_body["resource"]
    assert_includes response.parsed_body["scopes_supported"], "calendar_imports:write"
  end

  test "requires an audience-bound approved token" do
    post "/mcp", params: initialize_payload.to_json, headers: { "Content-Type" => "application/json" }

    assert_response :unauthorized
    assert_includes response.headers["WWW-Authenticate"], "oauth-protected-resource"
  end

  test "negotiates MCP over streamable HTTP" do
    access_token = OauthAccessToken.create!(resource_owner: @user, application: @application,
      scopes: "school_content:read calendar_imports:write", resource: "http://www.example.com/mcp", expires_in: 1.hour.to_i)

    post "/mcp", params: initialize_payload.to_json, headers: {
      "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream",
      "Authorization" => "Bearer #{access_token.plaintext_token}"
    }

    assert_response :success
    assert_equal "2.0", response.parsed_body["jsonrpc"]
    assert_equal "fish", response.parsed_body.dig("result", "serverInfo", "name")
  end

  test "advertises focused tools with accurate annotations" do
    access_token = OauthAccessToken.create!(resource_owner: @user, application: @application,
      scopes: "school_content:read calendar_imports:write", resource: "http://www.example.com/mcp", expires_in: 1.hour.to_i)

    post "/mcp", params: { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} }.to_json, headers: {
      "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream",
      "Authorization" => "Bearer #{access_token.plaintext_token}", "MCP-Protocol-Version" => "2025-06-18"
    }

    assert_response :success
    tools = response.parsed_body.dig("result", "tools").index_by { |tool| tool["name"] }
    assert_equal true, tools.dig("list_schools", "annotations", "readOnlyHint")
    assert_equal false, tools.dig("draft_calendar_import", "annotations", "readOnlyHint")
    assert_equal 100, tools.dig("draft_calendar_import", "inputSchema", "properties", "events", "maxItems")
  end

  test "tool calls return structured authorized data without excluded fields" do
    schools(:lincoln).update!(mcp_enabled_at: Time.current, mcp_enabled_by: @user)
    access_token = OauthAccessToken.create!(resource_owner: @user, application: @application,
      scopes: "school_content:read", resource: "http://www.example.com/mcp", expires_in: 1.hour.to_i)

    post "/mcp", params: { jsonrpc: "2.0", id: 3, method: "tools/call",
      params: { name: "list_schools", arguments: {} } }.to_json, headers: {
      "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream",
      "Authorization" => "Bearer #{access_token.plaintext_token}", "MCP-Protocol-Version" => "2025-06-18"
    }

    assert_response :success
    payload = response.parsed_body.dig("result", "structuredContent")
    assert_equal [ "Lincoln Elementary" ], payload.fetch("schools").pluck("name")
    assert_not_includes payload.to_json, "email"
  end

  test "authorization code flow requires S256 PKCE and binds the resource through token exchange" do
    sign_in_as(@user)
    verifier = "a" * 64
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    authorization_params = {
      client_id: @application.uid, redirect_uri: "https://client.example/callback", response_type: "code",
      scope: "school_content:read calendar_imports:write", state: "opaque-state",
      code_challenge: challenge, code_challenge_method: "S256", resource: "http://www.example.com/mcp"
    }

    get oauth_authorization_path, params: authorization_params
    assert_response :success
    assert_select "input[name=resource][value=?]", "http://www.example.com/mcp"

    post oauth_authorization_path, params: authorization_params
    assert_response :redirect
    code = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("code")

    post oauth_token_path, params: { grant_type: "authorization_code", client_id: @application.uid,
      redirect_uri: "https://client.example/callback", code: code, code_verifier: verifier }

    assert_response :success
    first_tokens = response.parsed_body
    assert first_tokens["access_token"].present?
    assert_equal "http://www.example.com/mcp", OauthAccessToken.order(:id).last.resource

    post oauth_token_path, params: { grant_type: "refresh_token", client_id: @application.uid,
      refresh_token: first_tokens.fetch("refresh_token") }

    assert_response :success
    refreshed_tokens = response.parsed_body
    assert_not_equal first_tokens["refresh_token"], refreshed_tokens["refresh_token"]
    assert_equal "http://www.example.com/mcp", OauthAccessToken.order(:id).last.resource

    post oauth_revoke_path, params: { client_id: @application.uid, token: refreshed_tokens.fetch("access_token") }
    assert_response :success
    assert OauthAccessToken.by_token(refreshed_tokens.fetch("access_token")).revoked?
  end

  test "authorization rejects a missing resource and plain PKCE" do
    sign_in_as(@user)

    get oauth_authorization_path, params: { client_id: @application.uid,
      redirect_uri: "https://client.example/callback", response_type: "code",
      scope: "school_content:read", code_challenge: "unsafe", code_challenge_method: "plain" }

    assert_response :bad_request
    assert_equal [ "S256" ], Doorkeeper.configuration.pkce_code_challenge_methods
  end

  private
    def initialize_payload
      { jsonrpc: "2.0", id: 1, method: "initialize", params: {
        protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" }
      } }
    end
end
