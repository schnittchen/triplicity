require 'digest'
require 'json'

require 'triplicity/util/on_when'
require 'triplicity/sync_action'
require 'triplicity/sync_thread'

module Triplicity
  module Destination
    class Base
      # An error during copy operation that has already been notified to the user
      NotifiedOperationError = Class.new(RuntimeError)
      # An error during copy operation that has not already been notified to the user.
      # The user may be notified with the help of the exception message
      UnnotifiedOperationError = Class.new(RuntimeError)

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

      include OnWhen

      on_when.delegates_subscriptions(Subscription)
      on_when.event :beginning_connection
      on_when.event :successful_connection
      on_when.event :unsuccessful_connection
      on_when.event :successful_operation
      on_when.event :unsuccessful_operation
      on_when.event :ended_connection

      class UpToDateness
        include OnWhen

        on_when.event :lost
        on_when.delegates_subscriptions(self)

        alias_method :when_lost, :on_lost # @TODO

        def initialize(cache, cache_ident)
          @cache, @cache_ident = cache, cache_ident
          @destination_timestamp = @cache.destination_latest_timestamp(@cache_ident)
          @on_when = on_when_new
        end

        def given?
          # always assume there is nothing to do until at least we know about the state of the primary
          !@primary_timestamp || (
            # unknown destination timestamp implies not up to date
            @primary_timestamp == @destination_timestamp
          )
        end

        ## this might be interesting for notification messages
        # def destination_timestamp_known?
        #   !!@destination_timestamp
        # end

        def primary_timestamp_changed(timestamp)
          @primary_timestamp = timestamp
          on_when.trigger_lost unless given?
        end

        def update_destination_timestamp(timestamp)
          # it is assumed that this is not called in a re-entrant fashion
          # (because it is called at the end of a sync operation which
          # ensures it is only happening once at a time)
          @cache.destination_latest_timestamp(@cache_ident, timestamp)
          @destination_timestamp = timestamp
          on_when.trigger_lost unless given?
        end
      end

      def initialize(options, primary, application)
        @primary = primary
        @application = application
        @retry_trigger = nil
        @on_when = on_when_new
        @mutex = @on_when.mutex

        yield Subscription.new(self)

        up_to_dateness.on_lost do
          maybe_ready_for_operation!
        end

        initialize_destination(options)
      end

      def cache_ident
        @cache_ident ||= Digest::SHA256.digest(cache_ident_data.to_json)
      end

      def up_to_dateness
        @up_to_dateness ||= UpToDateness.new(@application.cache, cache_ident)
      end

      private

      def maybe_ready_for_operation!
        thread.poke! if ready_for_operation?
      end

      def thread
        @thread || @mutex.synchronize do
          @thread ||= Triplicity::SyncThread
            .performing { attemt_to_copy }
            .whenever { ready_for_operation? }
        end
      end

      def attemt_to_copy
        on_when.trigger_beginning_connection(self)

        performed = false
        error = false

        with_accessible_site do |site|
          on_when.trigger_successful_connection(self)

          action = SyncAction.new(@primary.site, site, @max_space)
          begin
            perform_action_with_timestamp_housekeeping(action)
          rescue NotifiedOperationError, UnnotifiedOperationError => e
            error = e
          else
            performed = true
          end
        end

        if performed
          on_when.trigger_successful_operation(self)
        elsif error
          on_when.trigger_unsuccessful_operation(self, error)
          schedule_retry
        else
          on_when.trigger_unsuccessful_connection(self)
        end

        on_when.trigger_ended_connection(self)
      end

      def perform_action_with_timestamp_housekeeping(action)
        normalize_action_exceptions do
          action.perform
        end
      ensure
        timestamp = action.latest_target_timestamp
        up_to_dateness.update_destination_timestamp(timestamp)
      end

      def normalize_action_exceptions
        yield
      rescue NotifiedOperationError, UnnotifiedOperationError
        raise
      rescue => e
        raise UnnotifiedOperationError, e.message
      end

      def ready_for_operation?
        !up_to_dateness.given? && !retry_pending?
      end

      def schedule_retry
        @retry_trigger = @application.reactor.schedule_in(12) do
          @retry_trigger = nil
          maybe_ready_for_operation!
        end
      end

      def retry_pending?
        @retry_trigger
      end

      def cache_ident_data
        raise NotImplementedError
      end

      def with_accessible_site
        raise NotImplementedError
      end

      def initialize_destination(options)
        raise NotImplementedError
      end
    end
  end
end
