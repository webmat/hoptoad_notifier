module HoptoadNotifier
  # Include this module in Controllers in which you want to be notified of errors.
  module Catcher

    def self.included(base) #:nodoc:
      if base.instance_methods.include? 'rescue_action_in_public' and
        !base.instance_methods.include? 'rescue_action_in_public_without_hoptoad'
        base.alias_method_chain :rescue_action_in_public, :hoptoad
      end
    end
    
    # Overrides the rescue_action method in ActionController::Base, but does not inhibit
    # any custom processing that is defined with Rails 2's exception helpers.
    def rescue_action_in_public_with_hoptoad exception
      notify_hoptoad(exception) unless ignore?(exception)
      rescue_action_in_public_without_hoptoad(exception)
    end 
        
    # This method should be used for sending manual notifications while you are still
    # inside the controller. Otherwise it works like HoptoadNotifier.notify. 
    def notify_hoptoad hash_or_exception
      if public_environment?
        send_to_hoptoad(Notice.new(hash_or_exception, self))
      end
    end

    alias_method :inform_hoptoad, :notify_hoptoad

    # Returns the default logger or a logger that prints to STDOUT. Necessary for manual
    # notifications outside of controllers.
    def logger
      ActiveRecord::Base.logger
    rescue
      @logger ||= Logger.new(STDERR)
    end

    private
    
    def public_environment? #nodoc:
      defined?(RAILS_ENV) and !['development', 'test'].include?(RAILS_ENV)
    end
    
    def ignore?(exception) #:nodoc:
      ignore_these = HoptoadNotifier.ignore.flatten
      ignore_these.include?(exception.class) || ignore_these.include?(exception.class.name)
    end

    def send_to_hoptoad data #:nodoc:
      require 'net/http'
      require 'net/https'
      
      url = HoptoadNotifier.url
      Net::HTTP.start(url.host, url.port) do |http|
        headers = {
          'Content-type' => 'application/x-yaml',
          'Accept' => 'text/xml, application/xml'
        }
        http.read_timeout = 5 # seconds
        http.open_timeout = 2 # seconds
        #http.use_ssl      = HoptoadNotifier.secure
        response = begin
                     http.post(url.path, data.to_yaml, headers)
                   rescue TimeoutError => e
                     logger.error "Timeout while contacting the Hoptoad server."
                     nil
                   end
        case response
        when Net::HTTPSuccess then
          logger.info "Hoptoad Success: #{response.class}"
        else
          logger.error "Hoptoad Failure: #{response.class}\n#{response.body if response.respond_to? :body}"
        end
      end
    end
  end
end
