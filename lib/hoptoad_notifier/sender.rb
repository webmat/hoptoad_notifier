module HoptoadNotifier
  # A dummy class for sending notifications manually outside of a controller.
  class Sender
    include HoptoadNotifier::Catcher
    def rescue_action_in_public(exception); end
  end
end
