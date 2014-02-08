require 'dbus'

module Triplicity
  class Notifications
    attr_accessor :app_name

    class Notification
      attr_accessor :app_name, :icon, :summary, :body, :buttons, :hints, :timeout
      attr_reader :id

      def initialize(interface)
        @interface = interface
        default_expire!
        if block_given?
          yield self
          issue
        end
      end

      def default_expire!
        self.timeout = -1
      end

      def never_expire!
        self.timeout = 0
      end

      def issue
        yield self if block_given?

        app_name = self.app_name || ''
        icon = self.icon || ''
        summary = self.summary || ''
        body = self.body || ''
        buttons = self.buttons || []
        hints = self.hints || {}
        replaces_id = @id || 0

        result = @interface.Notify(app_name, replaces_id, icon, summary, body, buttons, hints, timeout)
        @id = result.first

        self
      end
    end

    def issue
      Notification.new(interface) do |notification|
        notification.app_name = @app_name if @app_name
        yield notification
      end
    end

    def initialize(session_bus)
      @session_bus = session_bus
    end

    private

    def interface
      object['org.freedesktop.Notifications']
    end

    def object
      service.object('/org/freedesktop/Notifications').tap(&:introspect)
    end

    def service
      @session_bus["org.freedesktop.Notifications"]
    end
  end
end
