#
# factory.rb - produces a duplication destination and a notifier
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/duplication/destination/path_on_filesystem'
require 'triplicity/duplication/notifier'

require 'triplicity/util/has_cache'

module Triplicity
  module Duplication
    module Destination
      class Factory
        include Util::HasCache

        def initialize(primary, application, options)
          @primary, @application = primary, application
          @options = options
        end

        # there is only one kind of destination currently,
        # oversimplifying this factory

        def destination
          PathOnFilesystem.new(@application, @options)
        end

        def cache_ident_data
          device_uuid = @options['device_uuid']
          rel_path = @options['rel_path']

          [device_uuid, rel_path]
        end

        def notifier
          Duplication::Notifier.new(@application.notifications)
        end
      end
    end
  end
end
