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
