#
# to_external_disk.rb - DSL target for the duplication to external disk
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/setup_dsl/duplication_target/base'

module Triplicity
  module SetupDsl
    module DuplicationTarget
      class ToExternalDisk < Base
        def uuid(uuid)
          @uuid = uuid
        end

        def relative_path(path)
          @relative_path = path
        end

        def _config
          {
            'device_uuid' => @uuid,
            'rel_path' => @relative_path
          }
        end

        def _base_config
          {
            'location_name' => 'external disk'
          }.merge(super)
        end
      end
    end
  end
end
