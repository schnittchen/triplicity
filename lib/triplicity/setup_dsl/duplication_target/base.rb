#
# basse.rb - base class for DSL targets for duplication of backups
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
      class Base
        include Util::ParseSpace

        def max_space(space)
          @max_space = parse_space(space)
        end

        def destination_name(name)
          # @FIXME TBD
        end

        def _base_config
          {
            'max_space' => @max_space,
          }
        end
      end
    end
  end
end
