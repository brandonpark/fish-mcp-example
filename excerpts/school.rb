# EXCERPT from app/models/school.rb in the full FISH application (lines 281-287).
# Only the methods used by FishMcp::Context and CalendarImport.authorize_draft! are shown.

class School < ApplicationRecord
  # ...
  def feature_enabled?(key)
    !disabled_features.include?(key.to_s)
  end

  def mcp_enabled?
    mcp_enabled_at.present?
  end
  # ...
end
