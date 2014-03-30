#
# backup_to_target.rb - DSL target for the BackupTo block
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/setup_dsl/perform_every_target'
require 'triplicity/setup_dsl/duplicity_arguments'

require 'pathname'

module Triplicity
  module SetupDsl
    class BackupToTarget
      def initialize(primary)
        @primary = primary
        @schedules = []
      end

      def from(source)
        @source = Pathname(source)
      end

      DuplicityArguments.dsl_methods.each do |method|
        define_method(method) { |*args| _arguments.send(method, *args) }
      end

      def perform_every(seconds, &block)
        perform_every_target = PerformEveryTarget.new(_arguments)
        perform_every_target.instance_exec(&block)
        @schedules << [seconds, perform_every_target._executions]
      end

      def _arguments
        @source or raise("Declare the backup source using 'from' first")
        @_arguments ||= DuplicityArguments.new(@primary, @source)
      end

      def _backup_schedules
        @schedules
      end

      def _source
        @source.to_s
      end
    end
  end
end
