require 'thread'

require 'dbus'

module Triplicity
  class DbusWrapper
    def initialize
      @buses = []
    end

    def system_bus
      @system_bus ||= DBus.system_bus.tap { |bus| @buses << bus }
    end

    def session_bus
      @session_bus ||= DBus.session_bus.tap { |bus| @buses << bus }
    end

    def run_loop
      loop.run(@buses)
    end

    def asap(&block)
      loop.asap(&block)
    end

    def schedule_in(seconds, &block)
      loop.schedule_in(seconds, &block)
    end

    private

    def loop
      @loop ||= Loop.new
    end

    class Loop
      def initialize
        @mutex = Mutex.new
        @dbus_main = DBus::Main.new

        @asap_blocks = []
        @scheduled_tasks = []

        @breaker = SelectBreakerFakeBus.new do
          handle_select_break_on_loop
        end
        @dbus_main << @breaker
      end

      def run(buses)
        buses.each { |bus| @dbus_main << bus }
        schedule_wakeup
        @dbus_main.run
      end

      def asap(&block)
        @asap_blocks << block
        @breaker.schedule_break
      end

      def schedule_in(seconds, &block)
        at = Time.now + seconds
        tuple = [at, block]

        @mutex.synchronize do
          @scheduled_tasks = [tuple, *@scheduled_tasks].sort_by(&:first)
        end

        schedule_wakeup
      end

      private

      def schedule_wakeup
        bomb = @mutex.synchronize do
          b = @bomb
          @bomb = nil
          b
        end
        bomb.suspend if bomb

        delay = calculate_wakeup_delay

        TimeBomb.plant(delay) do
          @breaker.schedule_break
        end if delay
      end

      def calculate_wakeup_delay
        task = @scheduled_tasks.first
        return unless task

        task.first - Time.now
      end

      def handle_select_break_on_loop
        while task = pop_due_task
          task.call
        end

        while task = pop_asap_task
          task.call
        end

        schedule_wakeup
      end

      def pop_asap_task
        @mutex.synchronize do
          @asap_blocks.shift
        end
      end

      def pop_due_task
        @mutex.synchronize do
          at, task = @scheduled_tasks.first
          return unless at && at <= Time.now

          @scheduled_tasks.shift
          return task
        end
      end

      class TimeBomb
        def self.plant(seconds, &block)
          new(seconds, block)
        end

        def suspend
          @suspended = true
          @thread.kill
        end

        private

        def initialize(seconds, block)
          @thread = Thread.new do
            sleep seconds if seconds > 0
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
end
