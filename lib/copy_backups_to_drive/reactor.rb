module CopyBackupsToDrive
  class Reactor

    def run_round
      sleep_some_time
      puts "no longer sleeping"
    end

    def interrupt_sleep
      return unless @sleeping

      raise InterruptSleep
    end

    private

    InterruptSleep = Class.new(Exception)

    def sleep_some_time
      interruptible_sleep
    end

    def interruptible_sleep
      @sleeping = true
      sleep 20
    rescue InterruptSleep
      @sleeping = false
    end
  end
end
