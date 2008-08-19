module HoptoadNotifier
  class Notice
    attr_accessor :api_key,
                  :error_message,
                  :error_class,
                  :backtrace,
                  :request,
                  :session,
                  :environment

    def initialize(notice, controller = nil) #:nodoc:
      self.api_key = HoptoadNotifier.api_key
      case notice
      when Hash
        initialize_from_hash(notice, controller)
      when Exception
        initialize_from_exception(notice, controller)
      end
      clean_params
      clean_backtrace
    end

    def initialize_from_hash(notice, controller)
      notice = notice.merge(self.class.default_options)
      self.error_message = notice[:error_message]
      self.backtrace     = notice[:backtrace]
      self.request       = notice[:request]
      self.session       = notice[:session]
      self.environment   = notice[:environment]
    end

    def initialize_from_exception(notice, controller)
      self.error_class   = notice.class.name
      self.error_message = "#{notice.class.name}: #{notice.message}",
      self.backtrace     = notice.backtrace
      self.environment   = ENV.to_hash
      if controller
        self.request     = {
          :params     => controller.request.parameters.to_hash,
          :rails_root => File.expand_path(RAILS_ROOT),
          :url        => "#{request.protocol}#{request.host}#{request.request_uri}"
        }
        self.session     = {
          :key   => controller.session.instance_variable_get("@session_id"),
          :value => controller.session.instance_variable_get("@data")
        }
      end
    end

    def self.default_options #:nodoc:
      {
        :api_key       => HoptoadNotifier.api_key,
        :error_message => 'Notification',
        :backtrace     => caller,
        :request       => {},
        :session       => {},
        :environment   => ENV.to_hash
      }
    end

    def clean_backtrace #:nodoc:
      if backtrace.to_a.size == 1
        backtrace = backtrace.to_a.first.split(/\n\s*/)
      end
    
      backtrace.to_a.map do |line|
        HoptoadNotifier.backtrace_filters.inject(line) do |line, proc|
          proc.call(line)
        end
      end
    end
    
    def clean_params #:nodoc:
      params = request[:params]
      return unless params

      params.dup.each do |k, v|
        params[k] = "<filtered>" if HoptoadNotifier.params_filters.any? do |filter|
          k.to_s.match(/#{filter}/)
        end
      end
    end
    
    def stringify_keys(hash) #:nodoc:
      hash.inject({}) do |h, pair|
        h[pair.first.to_s] = pair.last.is_a?(Hash) ? stringify_keys(pair.last) : pair.last
        h
      end
    end

    def to_yaml
      stringify_keys(:notice => {
        :api_key       => api_key,
        :error_class   => error_class,
        :error_message => error_message,
        :backtrace     => backtrace,
        :request       => request,
        :session       => session,
        :environment   => environment
      }).to_yaml
    end

  end
end
