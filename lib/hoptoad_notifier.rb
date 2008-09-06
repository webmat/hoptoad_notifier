require 'hoptoad_notifier/notice'
require 'hoptoad_notifier/catcher'
require 'hoptoad_notifier/sender'

# Plugin for applications to automatically post errors to the Hoptoad of their choice.
module HoptoadNotifier

  IGNORE_DEFAULT = ['ActiveRecord::RecordNotFound',
                    'ActionController::RoutingError',
                    'ActionController::InvalidAuthenticityToken',
                    'CGI::Session::CookieStore::TamperedWithCookie']

  # Some of these don't exist for Rails 1.2.*, so we have to consider that.
  IGNORE_DEFAULT.map!{|e| eval(e) rescue nil }.compact!
  IGNORE_DEFAULT.freeze
  
  class << self
    attr_accessor :host, :port, :secure, :api_key, :filter_params
    attr_reader   :backtrace_filters

    # Takes a block and adds it to the list of backtrace filters. When the filters
    # run, the block will be handed each line of the backtrace and can modify
    # it as necessary. For example, by default a path matching the RAILS_ROOT
    # constant will be transformed into "[RAILS_ROOT]"
    def filter_backtrace &block
      (@backtrace_filters ||= []) << block
    end

    # The port on which your Hoptoad server runs.
    def port
      @port || (secure ? 443 : 80)
    end

    # The host to connect to.
    def host
      @host ||= 'hoptoadapp.com'
    end
    
    # Returns the list of errors that are being ignored. The array can be appended to.
    def ignore
      @ignore ||= (HoptoadNotifier::IGNORE_DEFAULT.dup)
      @ignore.flatten!
      @ignore
    end
    
    # Sets the list of ignored errors to only what is passed in here. This method
    # can be passed a single error or a list of errors.
    def ignore_only=(names)
      @ignore = [names].flatten
    end

    # Returns a list of parameters that should be filtered out of what is sent to Hoptoad.
    # By default, all "password" attributes will have their contents replaced.
    def params_filters
      @params_filters ||= %w(password)
    end

    def environment_filters
      @environment_filters ||= %w()
    end
    
    # Call this method to modify defaults in your initializers.
    def configure
      yield self
    end
    
    def protocol #:nodoc:
      secure ? "https" : "http"
    end
    
    def url #:nodoc:
      URI.parse("#{protocol}://#{host}:#{port}/notices/")
    end
    
    
    # You can send an exception manually using this method, even when you are not in a
    # controller. You can pass an exception or a hash that contains the attributes that
    # would be sent to Hoptoad:
    # * api_key: The API key for this project. The API key is a unique identifier that Hoptoad
    #   uses for identification.
    # * error_message: The error returned by the exception (or the message you want to log).
    # * backtrace: A backtrace, usually obtained with +caller+.
    # * request: The controller's request object.
    # * session: The contents of the user's session.
    # * environment: ENV merged with the contents of the request's environment.
    def notify notice = {}
      Sender.new.notify_hoptoad( notice )
    end
  end

  filter_backtrace do |line|
    line.gsub(/#{RAILS_ROOT}/, "[RAILS_ROOT]")
  end

  filter_backtrace do |line|
    line.gsub(/^\.\//, "")
  end

  filter_backtrace do |line|
    Gem.path.inject(line) do |line, path|
      line.gsub(/#{path}/, "[GEM_ROOT]")
    end
  end
end
