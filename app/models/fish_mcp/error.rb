module FishMcp
  class Error < StandardError
    attr_reader :code, :kind, :details

    def initialize(kind, code, message, details: nil)
      @kind = kind
      @code = code
      @details = details
      super(message)
    end

    class << self
      def not_found(code, message) = new("not_found", code, message)
      def forbidden(code, message) = new("forbidden", code, message)
      def validation(code, message, details: nil) = new("validation", code, message, details: details)
    end
  end
end
