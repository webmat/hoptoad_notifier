require File.join(File.dirname(__FILE__), 'test_helper')

class RequestTest < Test::Unit::TestCase
  context "A request" do
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
        @request = HoptoadNotifier::Notice::Request.from_controller(@controller)
      end

      should "have the params we expect" do
        assert_equal @controller.request.parameters, @request.params
      end

      should "have the rails_root we expect" do
        assert_equal File.expand_path(RAILS_ROOT), @request.rails_root
      end

      should "have the url we expect" do
        assert_equal @controller.request.url, @request.url
      end
    end
  end
end


