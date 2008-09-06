require File.join(File.dirname(__FILE__), 'test_helper')

class SessionTest < Test::Unit::TestCase
  context "A session" do
    setup do
    end

    context "when initialized with a controller" do
      setup do
        class ::HoptoadController < ActionController::Base
          def index
            render :nothing => true
          end
        end
        request = ActionController::TestRequest.new
        response = ActionController::TestResponse.new
        @controller = HoptoadController.new
        @controller.stubs(:rescue_action)
        @controller.process(request, response)
        @session = HoptoadNotifier::Notice::Session.from_controller(@controller)
      end

      should "have the data we expect" do
        assert_equal @controller.session.instance_variable_get("@data"), @session.data
      end

      should "have the key we expect" do
        assert_equal @controller.session.instance_variable_get("@session_id"), @session.key
      end
    end
  end
end



