#
# setup_dsl.rb - DSL for configuration
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/primary'
require 'triplicity/backup_job'
require 'triplicity/duplicity_execution'

require 'triplicity/core_ext/fixnum'
require 'triplicity/util/parse_space'

require 'pathname'

module Triplicity
  class SetupDsl

    class Executor
      def initialize(application)
        @application = application
        @backup_schedule_targets = []
        @dsl_primaries = []
        @primary_duplications = Hash.new { |hash, key| hash[key] = [] }
      end

      def primary(p)
        @dsl_primaries << p
      end

      def backup_schedule_target(&block)
        @backup_schedule_targets << block
      end

      def duplication(primary, kind, hash)
        @primary_duplications[primary.object_id] << hash
      end

      def perform
        primaries = @dsl_primaries.map do |p|
          [
            p,
            Triplicity::Primary.new(p.path, 'currently unused')
          ]
        end

        @backup_schedule_targets.each do |block|
          builder, seconds = block.call

          backup_config = {
            'executions' => DuplicityExecution.new([builder.assemble]),
            'seconds' => seconds
          }

          primary = primaries.find do |dsl_primary, p|
            dsl_primary.equal? builder.primary
          end.last

          Triplicity::BackupJob.new(@application, primary, backup_config)
        end

        @primary_duplications.each_pair do |primary_id, hashes|
          primary = primaries.find do |dsl_primary, p|
            dsl_primary.object_id == primary_id
          end.last

          options = {
            destinations: hashes
          }

          DuplicationPlan.new(options, primary, @application)
        end
      end
    end

    class DuplicationToExternalDiskTarget
      include Util::ParseSpace

      def initialize
        config_getter = Proc.new do
          {
            'max_space' => @max_space,
            'device_uuid' => @uuid,
            'rel_path' => @relative_path
          }
        end
        yield config_getter
      end

      def max_space(space)
        @max_space = parse_space(space)
      end

      def uuid(uuid)
        @uuid = uuid
      end

      def relative_path(path)
        @relative_path = path
      end
    end

    class Primary
      attr_reader :path

      def initialize(executor, path)
        @executor, @path = executor, Pathname(path)
        @executor.primary self
      end

      def duplicate_to_external_disk
        config_getter = nil
        target = DuplicationToExternalDiskTarget.new do |cg|
          config_getter = cg
        end

        target.instance_exec(&Proc.new)

        @executor.duplication(self, 'fs_path_on_device', config_getter.call)
      end
    end

    class DuplicityCommandBuilder
      attr_reader :primary

      def initialize(primary)
        @primary = primary
        @extra_arguments = []
      end

      def source(path)
        @source = path
      end

      def extra_arguments(*args)
        @extra_arguments += args
      end

      def no_encryption
        extra_arguments '--no-encryption'
      end

      def exclude_globbing_filelist(file)
        extra_arguments '--exclude-globbing-filelist', file
      end

      def exclude_source_relative(*args)
        raise "please declare source before you use exclude_source_relative" unless @source
        source = Pathname(@source)
        args.each do |arg|
          extra_arguments '--exclude', (source + arg).to_s
        end
      end

      def configure_with_block(&block)
        instance_exec(&block)
      end

      def assemble
        [
          'duplicity',
          *@extra_arguments,
          @source,
          "file://#{@primary.path}"
        ]
      end
    end

    class BackupScheduleTarget
      def initialize(executor, builder)
        executor.backup_schedule_target do
          [builder, @seconds]
        end
      end

      def every(seconds)
        @seconds = seconds
      end
    end

    class Target
      def initialize(executor)
        @executor = executor
      end

      def PrimaryAt(path)
        Primary.new(@executor, path)
      end

      def DuplicityCommandFor(primary)
        builder = DuplicityCommandBuilder.new(primary)
        builder.configure_with_block(&Proc.new)
        builder
      end

      def backup_with(builder)
        BackupScheduleTarget.new(@executor, builder)
      end
    end

    def execute(application)
      executor = Executor.new(application)
      Target.new(executor).instance_exec(&Proc.new)
      executor.perform
    end
  end
end
