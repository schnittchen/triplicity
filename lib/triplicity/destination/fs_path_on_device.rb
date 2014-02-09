#
# fs_path_on_device.rb - a backup duplication target residing on a local filesystem
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/destination/base'
require 'triplicity/site/local'

module Triplicity
  module Destination
    class FsPathOnDevice < Base
      def human_name
        "target 1"
      end

      private

      def initialize_destination(options)
        @device_uuid = options['device_uuid']
        @rel_path = options['rel_path']
        @max_space = options['max_space']

        @disk = @application.udisk2.disk_by_uuid(@device_uuid)
        @disk.when_available do
          maybe_ready_for_operation!
        end
      end

      def cache_ident_data
        [@device_uuid, @rel_path]
      end

      def ready_for_operation?
        super and @disk.available?
      end

      def with_accessible_site
        return unless mountpoint = @disk.mountpoint

        path = Pathname(mountpoint) + @rel_path
        Dir.chdir(path) do
          yield Site::Local.new(path)
        end

        true
      end
    end
  end
end
