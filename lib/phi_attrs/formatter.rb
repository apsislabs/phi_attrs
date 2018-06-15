module PhiAttrs
  Format = "%s %5s: %s\n".freeze

  # https://github.com/ruby/ruby/blob/trunk/lib/logger.rb#L587
  class Formatter < ::Logger::Formatter
    def call(severity, timestamp, progname, msg)
      Format % [format_datetime(timestamp), severity, msg2str(msg)]
    end
  end
end
