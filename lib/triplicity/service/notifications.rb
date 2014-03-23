#
# notifications.rb - Notifications via DBus abstraction
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'dbus'

module Triplicity
  module Service
    class Notifications
      attr_accessor :app_name

      class Notification
        attr_accessor :app_name, :icon, :summary, :body, :buttons, :hints, :timeout
        attr_reader :id

        def initialize(reactor, interface)
          @reactor = reactor
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

          result = @reactor.on_dbus_thread do
            @interface.Notify(app_name, replaces_id, icon, summary, body, buttons, hints, timeout)
          end
          @id = result.first

          self
        end

        def close
          @interface.CloseNotification(@id) if @id
        end
      end

      def issue
        Notification.new(@reactor, @interface) do |notification|
          notification.app_name = @app_name if @app_name
          yield notification
        end
      end

      def initialize(reactor, session_bus)
        @reactor = reactor
        @interface = obtain_interface(session_bus)
      end

      private

      def obtain_interface(session_bus)
        @reactor.on_dbus_thread do
          service = session_bus["org.freedesktop.Notifications"]
          object = service.object('/org/freedesktop/Notifications').tap(&:introspect)
          object['org.freedesktop.Notifications']
        end
      end
    end
  end
end
