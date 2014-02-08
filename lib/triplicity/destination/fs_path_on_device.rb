require 'triplicity/destination/base'
require 'triplicity/site/local'
require 'triplicity/sync_action'
require 'triplicity/sync_thread'
require 'triplicity/util/on_when'

require 'thread'

module Triplicity
  module Destination
    class FsPathOnDevice < Base
      def initialize(options, primary, application)
        super(primary, application)
        @mutex = @on_when.mutex

        @device_uuid = options['device_uuid']
        @rel_path = options['rel_path']
        @max_space = options['max_space']

        @disk = @application.udisk2.disk_by_uuid(@device_uuid)
        @disk.when_available do
          thread.poke!
        end

        yield Subscription.new(self)

        up_to_dateness.on_lost do
          thread.poke!
        end
      end

      def human_name
        "target 1"
      end

      private

      def cache_ident_data
        [@device_uuid, @rel_path]
      end

      def thread
        @thread || @mutex.synchronize do
          @thread ||= Triplicity::SyncThread
            .performing { attemt_to_copy }
            .whenever { ready_for_operation? }
        end
      end

      def ready_for_operation?
        # XXX if there was an error, this means we will try again and again without waiting
        !up_to_dateness.given? and @disk.available?
      end

      def with_accessible_site
        return unless mountpoint = @disk.mountpoint

        path = Pathname(mountpoint) + @rel_path
        Dir.chdir(path) do
          yield Site::Local.new(path)
        end

        true
      end
    end
  end
end
