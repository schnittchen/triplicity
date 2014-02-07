require 'triplicity/destination/base'
require 'triplicity/site/local'
require 'triplicity/sync_action'
require 'triplicity/sync_thread'
require 'triplicity/util/on_when'

require 'thread'

module Triplicity
  module Destination
    class FsPathOnDevice < Base
      include OnWhen

      class Subscription
        attr_reader :destination

        def initialize(destination)
          @destination = destination
          @on_when = destination.on_when
        end

        def cache_ident
          @destination.cache_ident
        end
      end

      on_when.delegates_subscriptions(Subscription)
      on_when.event :beginning_connection
      on_when.event :successful_connection
      on_when.event :unsuccessful_connection
      on_when.event :successful_operation
      on_when.event :unsuccessful_operation
      on_when.event :ended_connection

      def initialize(options, primary, application)
        super(application)
        @on_when = on_when_new
        @mutex = @on_when.mutex

        @primary = primary

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

      def attemt_to_copy
        on_when.trigger_beginning_connection(self)
        performed = false

        with_accessible_site do |site|
          performed = true

          on_when.trigger_successful_connection(self)

          action = SyncAction.new(@primary.site, site, @max_space)
          action.perform

          timestamp = action.latest_target_timestamp
          up_to_dateness.update_destination_timestamp(timestamp)
        end

        if performed
          on_when.trigger_successful_operation(self)
        else
          on_when.trigger_unsuccessful_connection(self)
        end

        on_when.trigger_ended_connection(self)
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
