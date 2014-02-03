require 'dbus'

require 'triplicity/destination/legacy_base'
require 'triplicity/site'

module Triplicity
  module Destination
    class FsPathOnDevice < LegacyBase
      attr_accessor :device_uuid, :rel_path

      attr_accessor :application

      def initialize(config = {})
        super
        self.device_uuid = config['device_uuid']
        self.rel_path = config['rel_path']
      end

      def with_accessible_site
        return unless path = current_path

        Dir.chdir(path) do
          yield Site.from_path(path)
        end

        true
      end

      private

      def disk
        @disk ||= @application.udisk2.disk_by_uuid(device_uuid)
      end

      def ident_data
        [device_uuid, rel_path]
      end

      def current_path
        mountpoint = disk.mountpoint
        Pathname(mountpoint) + rel_path if mountpoint
      end
    end
  end
end
