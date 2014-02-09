#
# factory.rb - produce destination objects
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/destination/fs_path_on_device'

module Triplicity
  module Destination
    class Factory
      def initialize(primary, application)
        @primary, @application = primary, application
      end

      def produce_for_options(options)
        Destination::FsPathOnDevice.new(options, @primary, @application) do |subscription|
          yield subscription
        end
      end
    end
  end
end
