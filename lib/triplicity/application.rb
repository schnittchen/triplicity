#
# application.rb - provides reactor and services
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/dbus_loop_wrapper'
require 'triplicity/reactor'

require 'triplicity/cache'
require 'triplicity/service/udisk2'
require 'triplicity/service/notifications'

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

        @notifications = Service::Notifications.new(@reactor, session_bus)
        @cache = Cache.new('triplicity')
        @udisk2 = Service::Udisk2.new(self)

        setup
      end
    end

    def setup
    end
  end
end
