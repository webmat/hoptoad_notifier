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
      clean_environment
    end

    def initialize_from_hash(notice, controller)
      notice = self.class.default_options.merge(notice)
      self.error_class   = notice[:error_class]
      self.error_message = notice[:error_message]
      self.error_message = "#{notice[:error_class]}: #{notice[:error_message]}" if notice[:error_class]
      self.backtrace     = notice[:backtrace]
      self.request       = Request.from_hash(notice[:request])
      self.session       = Session.from_hash(notice[:session])
      self.environment   = notice[:environment]
    end

    def initialize_from_exception(notice, controller)
      self.error_class   = notice.class.name
      self.error_message = "#{notice.class.name}: #{notice.message}"
      self.backtrace     = notice.backtrace
      self.environment   = ENV.to_hash
      self.request     = Request.from_controller(controller)
      self.session     = Session.from_controller(controller)
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
      if [backtrace].flatten.size == 1
        self.backtrace = [backtrace].flatten.first.split(/\n\s*/).map(&:strip)
      end
    
      self.backtrace = backtrace.map do |line|
        HoptoadNotifier.backtrace_filters.inject(line) do |line, proc|
          proc.call(line)
        end
      end
    end

    def clean_environment #:nodoc:
      environment.each do |k, v|
        environment[k] = "<filtered>" if HoptoadNotifier.environment_filters.any? do |filter|
          k.to_s.match(/#{filter}/)
        end
      end
    end
    
    def clean_params #:nodoc:
      params = request.params
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
        :request       => request.to_hash,
        :session       => session.to_hash,
        :environment   => environment
      }).to_yaml
    end

    class Request
      attr_accessor :params, :rails_root, :url

      def initialize
        yield self if block_given?
      end

      def self.from_hash(hash = nil)
        return new if hash.nil?
        new do |r|
          r.params     = hash[:params]
          r.rails_root = hash[:rails_root]
          r.url        = hash[:url]
        end
      end

      def self.from_controller(controller = nil)
        return new if controller.nil?
        req = controller.request
        new do |r|
          r.params     = req.parameters.to_hash
          r.rails_root = File.expand_path(RAILS_ROOT)
          r.url        = "#{req.protocol}#{req.host}#{req.request_uri}"
        end
      end

      def to_hash
        {
          :params => params,
          :rails_root => rails_root,
          :url => url
        }
      end

      def ==(other)
        %w(params rails_root url).all?{|p| self.send(p) == other.send(p) }
      end
    end

    class Session
      attr_accessor :key, :data
      
      def initialize
        yield self if block_given?
      end

      def self.from_hash(hash)
        return new if hash.nil?
        new do |s|
          s.key  = hash[:key]
          s.data = hash[:data]
        end
      end

      def self.from_controller(controller)
        return new if controller.nil?
        new do |s|
          s.key  = controller.session.instance_variable_get("@session_id")
          s.data = controller.session.instance_variable_get("@data")
        end
      end

      def to_hash
        {
          :key => key,
          :data => data
        }
      end

      def ==(other)
        %w(key data).all?{|p| self.send(p) == other.send(p) }
      end
    end

  end
end
