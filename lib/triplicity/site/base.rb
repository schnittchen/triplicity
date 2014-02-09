require 'triplicity/util/sorting'
require 'triplicity/site/asset'
require 'triplicity/site/chain'

module Triplicity
  module Site
    class Base
      def chains
        @chains ||= calculate_chains
      end

      def latest_timestamp
        chains.map(&:latest_timestamp).max
      end

      def operations
        raise NotImplementedError
      end

      private

      include Util::Sorting

      def calculate_chains
        oldest_first(asset_candidates).slice_before(&:full?).map do |assets|
          next nil unless assets.first.full?

          assets.each_cons(2) do |pred, succ|
            next unless succ.timestamp_from == pred.timestamp
            succ.base = pred
            pred.basing = succ
          end

          assets = [
            assets.first,
            *assets.drop(1).take_while(&:base)
          ]

          Chain.new(assets)
        end.compact
      end

      def asset_candidates
        operations.glob('*.manifest*').map do |name|
          Asset.new(self, name)
        end
      end
    end
  end
end
