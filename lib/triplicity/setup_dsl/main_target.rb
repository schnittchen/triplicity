#
# main_target.rb - main DSL target class
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/setup_dsl/primary_at_target'
require 'triplicity/setup_dsl/backup_to_target'

module Triplicity
  module SetupDsl
    class MainTarget
      def initialize(executor)
        @executor = executor
      end

      def PrimaryAt(path)
        PrimaryAtTarget.new(@executor, path).tap do |primary|
          @executor.register_primary primary
        end
      end

      def BackupTo(primary, &block)
        target = BackupToTarget.new(primary)
        target.instance_exec(&block)
        target._backup_schedules.each do |seconds, executions|
          @executor.register_backup_schedule primary, seconds, executions
        end
        @executor.primary_backs_up_path(primary, target._source)
      end
    end
  end
end
