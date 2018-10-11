# frozen_string_literal: true

module PhiAttrs
  PHI_ACCESS_LOG_TAG = 'PHI Access Log'

  class Logger
    class << self
      def logger
        unless @logger
          logger = ActiveSupport::Logger.new(PhiAttrs.log_path)
          logger.formatter = Formatter.new
          @logger = ActiveSupport::TaggedLogging.new(logger)
        end
        @logger
      end

      delegate :debug, :info, :warn, :error, :fatal, :tagged, to: :logger
    end
  end
end
