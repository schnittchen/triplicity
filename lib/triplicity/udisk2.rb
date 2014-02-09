#
# udisk2.rb - Udisk2 via DBus abstraction
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/util/on_when'

module Triplicity
  class Udisk2
    # a disk may initially falsely reported as not connected, until shortly after the status is updated.

    def initialize(application)
      @application = application

      @mutex = Mutex.new
      @disk_handles = Hash.new do |hash, uuid|
        hash[uuid] = create_disk_handle(uuid)
      end

      @object_manager_interface = @application.reactor.on_dbus_thread do
        udisk2_service = @application.system_bus["org.freedesktop.UDisks2"]
        udisk = udisk2_service.object('/org/freedesktop/UDisks2').tap(&:introspect)
        udisk['org.freedesktop.DBus.ObjectManager']
      end
    end

    def kick_off
      @kicked_off = true.tap { schedule_polling }
    end

    class Disk
      def initialize(handle)
        @handle = handle
        @on_when = handle.on_when
      end

      def uuid
        @handle.uuid
      end

      def mountpoint
        @handle.mountpoint
      end
    end

    DiskHandle = Struct.new(:uuid, :available_handlers, :unavailable_handlers, :mountpoint, :disk) do
      include OnWhen

      on_when.condition :available
      on_when.delegates_subscriptions Disk

      def initialize(*)
        super
        @on_when = on_when_new
      end
    end

    def disk_by_uuid(uuid)
      @mutex.synchronize { kick_off; @disk_handles[uuid].disk }
    end

    private

    def create_disk_handle(uuid)
      result = DiskHandle.new
      result.disk = Disk.new(result)
      result
    end

    def analyze_mounted_filesystems(mounted_filesystems = mounted_filesystems)
      # @disk_handles may grow here. If we miss a disk because of this, it will be
      # handled next time through the polling cycle.
      @disk_handles.each_pair do |uuid, disk_handle|
        if disk_handle.mountpoint
          # we previously assumed this disk to be mounted

          system = mounted_filesystems.find { |sys| sys[:uuid] == uuid }
          disk_handle.mountpoint = system[:mountpoint] if system
        else
          # we previously assumed this disk not to be mounted

          system = mounted_filesystems.find { |sys| sys[:uuid] == uuid }
          if system
            disk_handle.on_when.signal_available do
              disk_handle.mountpoint = system[:mountpoint]
            end
          end
        end
      end
    end

    def schedule_polling
      # org.freedesktop.UDisks2 does not offer a signal for change detection.
      # thus we need to to polling

      @application.reactor.schedule_in(5) do
        analyze_mounted_filesystems
        schedule_polling
      end
    end

    def mounted_filesystems
      udisk2_objects = @object_manager_interface.GetManagedObjects.first
      udisk2_objects.select do |path, interfaces|
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

    def mtx
      @mutex.synchronize(&Proc.new)
    end
  end
end
