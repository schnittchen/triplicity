require 'dbus'

require 'triplicity/destination/base'

module Triplicity
  module Destination
    class FsPathOnDevice < Base
      attr_reader :device_uuid, :rel_path

      def with_accessible_site
        # yields site if possible
      end

      def udisk2_service
        DBus.system_bus["org.freedesktop.UDisks2"]
      end

      def udisk2_objects
        udisk = udisk2_service.object '/org/freedesktop/UDisks2'
        udisk.introspect
        object_manager_interface = udisk['org.freedesktop.DBus.ObjectManager']
        
        object_manager_interface.GetManagedObjects
      end

      def mounted_filesystems
        udisk2_objects.first.select do |path, interfaces|
          if fs = interfaces['org.freedesktop.UDisks2.Filesystem']
            !fs['MountPoints'].empty?
          end
        end.map do |path, interfaces|
          fs = interfaces['org.freedesktop.UDisks2.Filesystem']
          block = interfaces['org.freedesktop.UDisks2.Block']

          {
            uuid: block['IdUUID'],
            mountpoint: array_of_bytes_to_utf8(fs['MountPoints'].first)
          }
        end
      end

      def array_of_bytes_to_utf8(a)
        # a is a zero-delimited array of bytes forming an utf-8 string
        a.pack('C' * (a.length - 1)).force_encoding('utf-8')
      end
    end
  end
end
