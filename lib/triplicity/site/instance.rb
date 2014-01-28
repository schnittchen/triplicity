require 'pathname'

require 'triplicity/sorting'
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

      def empty?
        chains.empty?
      end

      def rescaning_needed!
        @chains = nil
      end

      private

      include Sorting

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
        Pathname.glob(path + '*.manifest').map do |manifest_path|
          Asset.new(manifest_path)
        end
      end
    end
  end
end
