# EXCERPT from config/initializers/doorkeeper.rb in the full FISH application (lines 23-25).
# OAuth scope configuration only; the rest of the initializer is omitted.

Doorkeeper.configure do
  # ...
  default_scopes :"school_content:read"
  optional_scopes :"calendar_imports:write", :openid, :email
  enforce_configured_scopes
  # ...
end
