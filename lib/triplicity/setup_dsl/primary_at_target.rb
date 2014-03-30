#
# primary_at_target.rb - DSL class representing a backup primary
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/setup_dsl/duplication_target/to_external_disk'
require 'triplicity/core_ext/fixnum'

module Triplicity
  module SetupDsl
    class PrimaryAtTarget
      attr_reader :path

      def initialize(executor, path)
        @executor, @path = executor, Pathname(path)
        @executor.register_primary self
      end

      def name=(name)
        @executor.primary_named(self, name)
      end

      def duplicate_to_external_disk
        target = DuplicationTarget::ToExternalDisk.new
        target.instance_exec(&Proc.new)

        options = target._config
        @executor.register_duplication_for(self, 'fs_path_on_device', options)
      end
    end
  end
end
