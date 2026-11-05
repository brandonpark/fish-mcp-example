class CalendarImportsController < ApplicationController
  before_action :set_calendar_import
  before_action :require_owner

  def show
    @calendar_import.expire_if_needed!
  end

  def update
    update_items
    redirect_to calendar_import_path(params[:token]), notice: "Draft updated."
  rescue FishMcp::Error => error
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  end

  def approve
    events = @calendar_import.approve!(Current.user)
    redirect_to calendar_import_path(params[:token]), notice: "Imported #{events.size} event(s)."
  rescue FishMcp::Error => error
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  end

  def reject
    @calendar_import.reject!(Current.user)
    redirect_to calendar_import_path(params[:token]), notice: "Import rejected."
  end

  private
    def set_calendar_import
      @calendar_import = CalendarImport.find_signed!(params[:token], purpose: CalendarImport::REVIEW_TOKEN_PURPOSE)
      @school = @calendar_import.school
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      raise ActionController::RoutingError, "Not Found"
    end

    def require_owner
      raise ActionController::RoutingError, "Not Found" unless @calendar_import.user == Current.user
    end

    def update_items
      raise FishMcp::Error.validation("import_not_draft", "This import is no longer editable.") unless @calendar_import.draft? && !@calendar_import.expire_if_needed!

      @calendar_import.transaction do
        item_params.each do |id, attributes|
          item = @calendar_import.items.find(id)
          item.included = ActiveModel::Type::Boolean.new.cast(attributes[:included])
          item.assign_proposal(attributes)
          item.validate_proposal!
          item.save!(validate: false)
        end
      end
    end

    def item_params
      items = params.fetch(:items, ActionController::Parameters.new)
      items.keys.index_with do |id|
        items.require(id).permit(:included, :title, :start, :end, :all_day, :time_zone, :description, :location)
      end
    end
end
