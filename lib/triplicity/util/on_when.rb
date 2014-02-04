require 'thread'

module OnWhen
  module HasInstanceHandle
    def on_when
      @on_when || 'you forgot to set up @on_when in your initialize method'
    end
  end
  include HasInstanceHandle

  class ClassHandle
    def instance_handle_class
      @instance_handle_class ||= Class.new(InstanceHandleBase)
    end

    def names
      @names ||= []
    end

    def event(name)
      name = name.to_s
      names << name

      instance_handle_class.send(:define_method, "trigger_#{name}") do |*payload|
        @listeners[name].dup.each { |listener| listener.call(*payload) }
      end

      subscribe_method_name = "on_#{name}"

      instance_handle_class.send(:define_method, subscribe_method_name) do |&listener|
        @listeners[name] << listener
      end
      subscription_delegate_module.send(:define_method, subscribe_method_name) do |*args, &listener|
        on_when.send(subscribe_method_name, &listener)
      end
    end

    def condition(name)
      name = name.to_s
      names << name

      instance_handle_class.send(:define_method, "signal_#{name}") do |state|
        state = !!state
        recipients = @mutex.synchronize do
          old_state = @states[name]
          @states[name] = state

          @listeners[name].dup if state && !old_state
        end || []

        recipients.each(&:call)
      end

      subscribe_method_name = "when_#{name}"

      instance_handle_class.send(:define_method, subscribe_method_name) do |&listener|
        invoke_now = @mutex.synchronize do
          @listeners[name] << listener

          @states[name]
        end

        listener.call if invoke_now
      end
      subscription_delegate_module.send(:define_method, subscribe_method_name) do |&listener|
        on_when.send(subscribe_method_name, &listener)
      end
    end

    def delegates_subscriptions(klass)
      klass.include subscription_delegate_module
      klass.include HasInstanceHandle
    end

    private

    def subscription_delegate_module
      @subscription_delegate_module ||= Module.new
    end
  end

  class InstanceHandleBase
    attr_reader :mutex

    def initialize(names)
      @mutex = Mutex.new

      @listeners = {}
      @states = {}

      names.each do |name|
        @listeners[name] = []
        @states[name] = false
      end
    end
  end

  module ClassMethods
    def on_when
      @on_when ||= ClassHandle.new
    end
  end

  def self.included(cls)
    cls.extend ClassMethods
  end

  private

  def on_when_new
    class_handle = self.class.on_when
    class_handle.instance_handle_class.new(class_handle.names)
  end
end
