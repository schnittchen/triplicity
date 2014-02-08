require 'thread'

module OnWhen
  module HasInstanceHandle
    def on_when
      @on_when || 'you forgot to set up @on_when in your initialize method'
    end
  end
  include HasInstanceHandle

  class ClassHandle
    attr_reader :instance_handle_class, :names, :subscription_delegate_module

    def initialize(kls)
      if kls.superclass < OnWhen
        superclass_handle = kls.superclass.on_when
        @instance_handle_class = Class.new(superclass_handle.instance_handle_class)
        @names = superclass_handle.names.dup
        @subscription_delegate_module = Module.new.tap do |mod|
          mod.include superclass_handle.subscription_delegate_module
        end
      else
        @instance_handle_class = Class.new(InstanceHandleBase)
        @names = []
        @subscription_delegate_module = Module.new
      end
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

      instance_handle_class.send(:define_method, "signal_#{name}") do |state = true, &block|
        state = !!state
        recipients = @mutex.synchronize do
          old_state = @states[name]
          @states[name] = block ? block.call : state

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

      condition_method_name = name + '?'

      instance_handle_class.send(:define_method, condition_method_name) do
        @states[name]
      end
      subscription_delegate_module.send(:define_method, condition_method_name) do
        on_when.send(condition_method_name)
      end
    end

    def delegates_subscriptions(klass)
      klass.include subscription_delegate_module
      klass.include HasInstanceHandle
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
      @on_when ||= ClassHandle.new(self)
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
