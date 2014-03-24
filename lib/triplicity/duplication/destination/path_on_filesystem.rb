#
# path_on_filesystem.rb - a backup duplication destination residing on a local filesystem
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/site/local'

require 'pathname'

module Triplicity
  module Duplication
    module Destination
      class PathOnFilesystem
        def initialize(application, options)
          @device_uuid = options['device_uuid']
          @rel_path = options['rel_path']
          @max_space = options['max_space']

          @disk = application.udisk2.disk_by_uuid(@device_uuid)
        end

        def becoming_available_handler
          @becoming_available_handler = Proc.new
        end

        def activate
          @disk.when_available(&@becoming_available_handler)
        end

        class << self
          def cache_ident_data(options)
            [options['device_uuid'], options['rel_path']]
          end

          def create(application, options)
            new(application, options)
          end
        end

        def with_accessible_site
          return unless mountpoint = @disk.mountpoint
          path = Pathname(mountpoint) + @rel_path
          return unless path.directory?

          yield Site::Local.new(path)

          true
        end
      end
    end
  end
end
