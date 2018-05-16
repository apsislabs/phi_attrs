module PhiAttrs
  class Logger
    class << self
      cattr_accessor :logger
      delegate :debug, :info, :warn, :error, :fatal, :tagged, to: :logger
    end
  end
end
