require 'triplicity/dbus_loop_wrapper'
require 'triplicity/reactor'

require 'triplicity/cache'
require 'triplicity/udisk2'

module Triplicity
  class Application
    attr_reader :dbus_busses, :reactor, :notifications, :udisk2, :cache

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

        @notifications = Notifications.new(@reactor, session_bus)
        @cache = Cache.new('triplicity')
        @udisk2 = Udisk2.new(self)

        setup
      end
    end

    def setup
    end
  end
end
