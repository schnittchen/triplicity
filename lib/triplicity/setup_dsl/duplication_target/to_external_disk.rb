#
# duplication_target.rb - DSL target for the duplication to external disk
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/util/parse_space'

module Triplicity
  module SetupDsl
    module DuplicationTarget
      class ToExternalDisk
        include Util::ParseSpace

        def max_space(space)
          @max_space = parse_space(space)
        end

        def uuid(uuid)
          @uuid = uuid
        end

        def relative_path(path)
          @relative_path = path
        end

        def _config
          {
            'max_space' => @max_space,
            'device_uuid' => @uuid,
            'rel_path' => @relative_path
          }
        end
      end
    end
  end
end
