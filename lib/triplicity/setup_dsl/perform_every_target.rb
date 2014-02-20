#
# perform_every_target.rb - DSL class for the perform_every block
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/duplicity_execution'
require 'triplicity/duplicity_time'

module Triplicity
  module SetupDsl
    class PerformEveryTarget
      def initialize(duplicity_arguments)
        @duplicity_arguments = duplicity_arguments
        @executions = []
      end

      def remove_older_than(seconds)
        segments = [
          'duplicity', 'remove-older-than',
          DuplicityTime.from_fixnum(seconds),
          *@duplicity_arguments.other_args,
          '--force',
          @duplicity_arguments.target_arg,
        ]
        @executions << DuplicityExecution.new(segments)
      end

      def remove_all_but_n_full(n)
        segments = [
          'duplicity', 'remove-all-but-n-full', n.to_s,
          *@duplicity_arguments.other_args,
          '--force',
          @duplicity_arguments.target_arg,
        ]
        @executions << DuplicityExecution.new(segments)
      end

      def remove_all_inc_of_but_n_full(n)
        segments = [
          'duplicity', 'remove-all-inc-of-but-n-full', n.to_s,
          *@duplicity_arguments.other_args,
          '--force',
          @duplicity_arguments.target_arg,
        ]
        @executions << DuplicityExecution.new(segments)
      end

      def cleanup
        segments = [
          'duplicity', 'cleanup',
          *@duplicity_arguments.other_args,
          '--force',
          @duplicity_arguments.target_arg,
        ]
        @executions << DuplicityExecution.new(segments)
      end

      def full
        segments = [
          'duplicity', 'full',
          *@duplicity_arguments.other_args,
          @duplicity_arguments.source_arg,
          @duplicity_arguments.target_arg,
        ]
        @executions << DuplicityExecution.new(segments)
      end

      def backup
        segments = [
          'duplicity',
          *@duplicity_arguments.other_args,
          @duplicity_arguments.source_arg,
          @duplicity_arguments.target_arg,
        ]
        @executions << DuplicityExecution.new(segments)
      end

      def _executions
        @executions
      end
    end
  end
end
