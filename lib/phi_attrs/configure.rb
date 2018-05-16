module PhiAttrs
  module Configure
    @@log_path = nil

    def configure
      yield self if block_given?
    end

    def log_path
      @@log_path
    end

    def log_path=(value)
      @@log_path = value
    end
  end
end
