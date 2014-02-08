require 'triplicity/dbus_loop_wrapper'
require 'triplicity/reactor'

module Triplicity
  class Application
    attr_reader :dbus_busses, :reactor, :notifications

    def self.start
      send(:new).setup_and_run
    end

    def system_bus
      @dbus_loop_wrapper.system_bus
    end

    def session_bus
      @dbus_loop_wrapper.session_bus
    end

    private

    def initialize
      setup_and_run
    end

    def setup_and_run
      @dbus_loop_wrapper = Triplicity::DbusLoopWrapper.new
      Reactor.new(@dbus_loop_wrapper) do |reactor|
        @reactor = reactor

        @notifications = Notifications.new(session_bus)

        setup
      end
    end

    def setup
    end
  end
end
