# frozen_string_literal: true

module PhiAttrs
  # https://github.com/ruby/ruby/blob/trunk/lib/logger.rb#L587
  class Formatter < ::Logger::Formatter
    FORMAT = "%s %5s: %s\n"

    def call(severity, timestamp, _progname, msg)
      format(FORMAT, format_datetime(timestamp), severity, msg2str(msg))
    end
  end
end
