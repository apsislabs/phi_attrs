# frozen_string_literal: true

module PhiAttrs
  module Exceptions
    class PhiAccessException < StandardError
      TAG = 'UNAUTHORIZED ACCESS'

      def initialize(msg)
        PhiAttrs::Logger.tagged(TAG) { PhiAttrs::Logger.error(msg) }
        super(msg)
      end
    end
  end
end
