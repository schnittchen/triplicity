require 'digest'
require 'json'

require 'triplicity/util/on_when'

module Triplicity
  module Destination
    class Base
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

      def initialize(application)
        @application = application
      end

      def cache_ident
        @cache_ident ||= Digest::SHA256.digest(cache_ident_data.to_json)
      end

      def up_to_dateness
        @up_to_dateness ||= UpToDateness.new(@application.cache, cache_ident)
      end

      private

      def cache_ident_data
        raise "unimplemented template method"
      end
    end
  end
end
