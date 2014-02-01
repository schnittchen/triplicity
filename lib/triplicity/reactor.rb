module Triplicity
  class Reactor
    def initialize(dbus_wrapper)
      Thread.abort_on_exception = true
      @rendezvous_mutex = Mutex.new
      @dbus_wrapper = dbus_wrapper
      @dbus_thread = Thread.current
      yield self
      @dbus_wrapper.run_loop
    end

    # def quit
    # end

    def asap
      @dbus_wrapper.asap(&Proc.new)
    end

    def schedule_in(seconds)
      @dbus_wrapper.schedule_in(seconds, &Proc.new)
    end

    def on_dbus_thread
      return yield if on_dbus_thread?

      cv = ConditionVariable.new
      executed = false
      result = nil
      exception = nil

      @rendezvous_mutex.synchronize do
        asap do
          begin
            result = yield
          rescue => e
            exception = e
          end
          @rendezvous_mutex.synchronize do
            executed = true
            cv.signal
          end
        end
        cv.wait(@rendezvous_mutex) until executed
      end

      raise exception if exception
      result
    end

    private

    def on_dbus_thread?
      Thread.current == @dbus_thread
    end
  end
end
