require 'test/unit'
require 'rubygems'
require 'mocha'
require 'shoulda'
require 'action_controller'
require 'action_controller/test_process'
require 'active_record'
require 'net/http'
require 'net/https'
require File.join(File.dirname(__FILE__), "..", "lib", "hoptoad_notifier")

RAILS_ROOT = File.join( File.dirname(__FILE__), "rails_root" )
RAILS_ENV  = "test"

TEST_API_KEY = "1234567890abcdef"
HoptoadNotifier.api_key = TEST_API_KEY

class HoptoadController < ActionController::Base
  def rescue_action e
    raise e
  end
  
  def do_raise
    raise "Hoptoad"
  end
  
  def do_not_raise
    render :text => "Success"
  end
  
  def do_raise_ignored
    raise ActiveRecord::RecordNotFound.new("404")
  end
  
  def do_raise_not_ignored
    raise ActiveRecord::StatementInvalid.new("Statement invalid")
  end
  
  def manual_notify
    notify_hoptoad(Exception.new)
    render :text => "Success"
  end
  
  def manual_notify_ignored
    notify_hoptoad(ActiveRecord::RecordNotFound.new("404"))
    render :text => "Success"
  end
end
