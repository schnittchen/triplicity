module Triplicity
  class Reactor

    attr_accessor :sleep_time

    def initialize
      @sleep_time = 5 # raise this some time...
      @running = true
      @scheduled_tasks = []
      @pending_work_handler = ->{}
    end

    def schedule
      @scheduled_tasks << Proc.new
    end

    def pending_work_handler
      @pending_work_handler = Proc.new
    end

    def run
      run_round while running?
    end

    def interrupt_sleep
      return unless @sleeping

      raise InterruptSleep
    end

    def shutdown
      @running = false
    end

    def running?
      @running
    end

    private

    def run_round
      sleep_some_time

      while running? and task = @scheduled_tasks.pop
        task.call
      end

      @pending_work_handler.call if running?
    end

    InterruptSleep = Class.new(Exception)

    def sleep_some_time
      interruptible_sleep
    end

    def interruptible_sleep
      @sleeping = true
      sleep @sleep_time
    rescue InterruptSleep
      @sleeping = false
    end
  end
end
