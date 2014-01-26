require 'pathname'

require 'triplicity/site/asset'
require 'triplicity/site/chain'

module Triplicity
  module Site
    class Instance
      attr_accessor :path

      def initialize(path)
        @path = Pathname(path)
      end

      def chains
        @chains ||= calculate_chains
      end

      def latest_timestamp
        chains.map(&:latest_timestamp).max
      end

      private

      def calculate_chains
        sorted = asset_candidates.sort_by(&:timestamp)

        sorted.slice_before(&:full?).map do |assets|
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
        Pathname.glob(path + '*.manifest').map do |manifest_path|
          Asset.new(manifest_path)
        end.sort_by(&:timestamp_from)
      end
    end
  end
end
