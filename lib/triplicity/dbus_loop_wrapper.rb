#
# dbus_loop_wrapper.rb - wrap DBus::Main to also provide scheduled tasks
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'thread'

require 'dbus'

module Triplicity
  class DbusLoopWrapper
    def initialize
      @buses = []
      @waking_up_block = -> {}
      @wakeup_time_calculator = -> {}
      @mutex = Mutex.new
      @dbus_main = DBus::Main.new
      @asap_blocks = []
      @bomb = nil

      @breaker = SelectBreakerFakeBus.new do
        handle_select_break_on_loop
      end
      @dbus_main << @breaker
    end

    def system_bus
      @system_bus ||= DBus.system_bus.tap { |bus| @buses << bus }
    end

    def session_bus
      @session_bus ||= DBus.session_bus.tap { |bus| @buses << bus }
    end

    def run_loop
      @buses.each { |bus| @dbus_main << bus }
      schedule_wakeup
      @dbus_main.run
    end

    def asap(&block)
      @mutex.synchronize { @asap_blocks << block }
      @breaker.schedule_break
    end

    def calculating_wakeup_time
      @wakeup_time_calculator = Proc.new
    end

    # block may be called prematurely or even when last calculating_wakeup_time block returned nil
    def waking_up
      @waking_up_block = Proc.new
    end

    def schedule_wakeup
      time = @wakeup_time_calculator.call

      bomb = if time
        TimeBomb.plant(time) do
          @breaker.schedule_break
        end
      end

      old_bomb = @mutex.synchronize do
        ob = @bomb
        @bomb = bomb
        ob
      end

      old_bomb.suspend if old_bomb
    end

    private

    def handle_select_break_on_loop
      while asap_block = pop_asap_block
        asap_block.call
      end

      @waking_up_block.call

      schedule_wakeup
    end

    def pop_asap_block
      @mutex.synchronize { @asap_blocks.pop }
    end

    class TimeBomb
      def self.plant(time, &block)
        new(time, block)
      end

      def suspend
        @suspended = true
        @thread.kill
      end

      private

      def initialize(time, block)
        @thread = Thread.new do
          while remaining_seconds = time - Time.now and remaining_seconds > 0
            # avoid sleeping for long since suspend-to-ram time adds to sleep time
            if remaining_seconds < 60
              sleep remaining_seconds
            else
              sleep 60
            end

            break if @suspended
          end
          block.call unless @suspended
        end
      end
    end

    class SelectBreakerFakeBus
      def initialize(&break_handler)
        @rd, @wr = IO.pipe
        @break_handler = break_handler
      end

      def schedule_break
        @wr.write '.'
      end

      # remaining methods are interface towards DBus::Main

      def socket
        @rd
      end

      def update_buffer
        @rd.read(1)
        @break_handler.call
      end

      def pop_message
        nil
      end
    end
  end
end
