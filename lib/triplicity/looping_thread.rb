#
# looping_thread.rb - worker thread with a wait condition
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'thread'

module Triplicity
  class LoopingThread < Thread
    class DslTarget
      def initialize(&constructor)
        @constructor = constructor
      end

      def whenever(&condition_block)
        @constructor.call(condition_block)
      end
    end

    def self.performing(&action_block)
      DslTarget.new do |condition_block|
        new(condition_block, action_block)
      end
    end

    def initialize(condition_block, action_block)
      @condition_block, @action_block = condition_block, action_block

      @mutex = Mutex.new
      @condition_variable = ConditionVariable.new
      super(&method(:body))
    end

    def poke!
      @condition_variable.signal
    end

    private

    def body
      loop do
        @mutex.synchronize do
          @condition_variable.wait(@mutex) while !@condition_block.call
        end

        @action_block.call
      end
    end
  end
end
