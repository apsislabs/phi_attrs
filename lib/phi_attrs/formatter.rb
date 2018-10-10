# frozen_string_literal: true

module PhiAttrs
  FORMAT = "%s %5s: %s\n"

  # https://github.com/ruby/ruby/blob/trunk/lib/logger.rb#L587
  class Formatter < ::Logger::Formatter
    def call(severity, timestamp, _progname, msg)
      format(FORMAT, format_datetime(timestamp), severity, msg2str(msg))
    end
  end
end
