module CopyBackupsToDrive
  class Reactor

    def initialize
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
      @running = fasle
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
      sleep 5
    rescue InterruptSleep
      @sleeping = false
    end
  end
end
