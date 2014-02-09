#
# reactor.rb - main loop integrating DBus I/O
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

module Triplicity
  class Reactor
    def initialize(dbus_loop_wrapper)
      Thread.abort_on_exception = true
      @mutex = Mutex.new
      @dbus_loop_wrapper = dbus_loop_wrapper
      @scheduled_tasks = []
      @dbus_thread = Thread.current
      @earlier_tasks_need_rescheduling = false

      @dbus_loop_wrapper.calculating_wakeup_delay do
        @earlier_tasks_need_rescheduling = true
        calculate_wakeup_delay
      end

      @dbus_loop_wrapper.waking_up do
        handle_loop_wakeup
      end

      yield self
      @dbus_loop_wrapper.run_loop
    end

    # def quit
    # end

    def asap
      @dbus_loop_wrapper.asap(&Proc.new)
    end

    class ScheduledTask
      attr_reader :earliest_time, :block

      def initialize(earliest_time, block, &unschedule_block)
        @earliest_time, @block = earliest_time, block
        @unschedule_block = unschedule_block
      end

      def unschedule
        @unschedule_block.call self
      end
    end

    def schedule_in(seconds)
      earliest_time = Time.now + seconds
      ScheduledTask.new(earliest_time, Proc.new) do |task|
        unschedule_task task
      end.tap do |task|
        needs_wakeup_scheduled = false

        @mutex.synchronize do
          if @scheduled_tasks.empty?
            needs_wakeup_scheduled = true
          else
            earliest_time_before = @scheduled_tasks.map(&:earliest_time).min
            needs_wakeup_scheduled = earliest_time_before > earliest_time
          end

          @scheduled_tasks << task
        end

        @dbus_loop_wrapper.schedule_wakeup if needs_wakeup_scheduled && @earlier_tasks_need_rescheduling
      end
    end

    def on_dbus_thread
      return yield if on_dbus_thread?

      cv = ConditionVariable.new
      executed = false
      result = nil
      exception = nil

      @mutex.synchronize do
        asap do
          begin
            result = yield
          rescue => e
            exception = e
          end
          @mutex.synchronize do
            executed = true
            cv.signal
          end
        end
        cv.wait(@mutex) until executed
      end

      raise exception if exception
      result
    end

    def safe_trap(signal)
      # Avoid deadlock by spawning a thread
      # https://www.ruby-forum.com/topic/4411227
      trap(signal) do
        Thread.new { yield }
      end
    end

    private

    def calculate_wakeup_delay
      @mutex.synchronize do
        return if @scheduled_tasks.empty?

        @scheduled_tasks.map(&:earliest_time).min - Time.now
      end
    end

    def unschedule_task(task)
      @mutex.synchronize { @scheduled_tasks.delete task }
    end

    def handle_loop_wakeup
      while task = remove_due_task
        task.block.call
      end
    end

    def remove_due_task
      @mutex.synchronize do
        result = nil
        @scheduled_tasks.delete_if do |task|
          break if result

          next false unless task.earliest_time <= Time.now
          result = task
        end

        result
      end
    end

    def on_dbus_thread?
      Thread.current == @dbus_thread
    end
  end
end
