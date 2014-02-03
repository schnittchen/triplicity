module Triplicity
  class Udisk2
    # a disk may initially falsely reported as not connected, until shortly after the status is updated.

    def initialize(application)
      @application = application

      @mutex = Mutex.new
      @disk_handles = Hash.new do |hash, uuid|
        hash[uuid] = create_disk_handle(uuid)
      end

      udisk2_service = @application.system_bus["org.freedesktop.UDisks2"]
      udisk = udisk2_service.object('/org/freedesktop/UDisks2').tap(&:introspect)
      @object_manager_interface = udisk['org.freedesktop.DBus.ObjectManager']
    end

    def kick_off
      @kicked_off = true.tap { schedule_polling }
    end

    DiskHandle = Struct.new(:uuid, :available_handlers, :unavailable_handlers, :mountpoint, :disk)

    class Disk
      attr_reader :uuid

      def initialize(uuid, available_handlers, unavailable_handlers, mountpoint_getter, mutex)
        @uuid = uuid
        @available_handlers = available_handlers
        @unavailable_handlers = unavailable_handlers
        @mountpoint_getter = mountpoint_getter
        @mutex = mutex
      end

      def on_available(&block)
        call_now = false

        mtx do
          call_now = true if mountpoint
          @available_handlers << block
        end

        block.call(self) if call_now
        self
      end

      def on_unavailable(&block)
        call_now = false

        mtx do
          call_now = true if !mountpoint
          @unavailable_handlers << block
        end

        block.call(self) if call_now
        self
      end

      def mountpoint
        @mountpoint_getter.call
      end

      private

      def mtx
        @mutex.synchronize(&Proc.new)
      end
    end

    def disk_by_uuid(uuid)
      @mutex.synchronize { kick_off; @disk_handles[uuid].disk }
    end

    private

    def create_disk_handle(uuid)
      available_handlers = []
      unavailable_handlers = []

      result = DiskHandle.new
      result.available_handlers = available_handlers
      result.unavailable_handlers = unavailable_handlers
      result.disk = Disk.new(uuid, available_handlers, unavailable_handlers,
        result.method(:mountpoint), @mutex)
      result
    end

    def analyze_mounted_filesystems(mounted_filesystems = mounted_filesystems)
      # @disk_handles may grow here. If we miss a disk because of this, it will be
      # handled next time through the polling cycle.
      @disk_handles.each_pair do |uuid, disk_handle|
        disk = disk_handle.disk
        if disk_handle.mountpoint
          # we previously assumed this disk to be mounted

          system = mounted_filesystems.find { |sys| sys[:uuid] == uuid }
          if system
            disk_handle.mountpoint = system[:mountpoint]
          else
            mtx do
              disk_handle.mountpoint = nil
              disk_handle.unavailable_handlers.dup
            end.each { |handler| handler.call(disk) }
          end
        else
          # we previously assumed this disk not to be mounted

          system = mounted_filesystems.find { |sys| sys[:uuid] == uuid }
          if system
            mtx do
              disk_handle.mountpoint = system[:mountpoint]
              disk_handle.available_handlers.dup
            end.each { |handler| handler.call(disk) }
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
