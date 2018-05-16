module PhiAttrs
  module Exceptions
    class PhiAccessException < StandardError
      def initialize(msg)
        PhiAttrs::Logger.tagged('UNAUTHORIZED ACCESS') { PhiAttrs::Logger.error(msg) }
        super(msg)
      end
    end
  end
end
