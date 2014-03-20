#
# up_to_dateness.rb - manages whether a destination is up to date
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
  module Destination
    class UpToDateness
      include Util::OnWhen

      on_when.condition :lost
      on_when.delegates_subscriptions(self)

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
        on_when.signal_lost unless given?
      end

      def update_destination_timestamp(timestamp)
        # it is assumed that this is not called in a re-entrant fashion
        # (because it is called at the end of a sync operation which
        # ensures it is only happening once at a time)
        @cache.destination_latest_timestamp(@cache_ident, timestamp)
        @destination_timestamp = timestamp
        on_when.signal_lost { !given? }
      end
    end
  end
end
