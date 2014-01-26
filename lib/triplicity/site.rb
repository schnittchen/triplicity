require 'pathname'

require 'triplicity/site/asset'

module Triplicity
  class Site
    attr_accessor :path

    def initialize(path)
      @path = Pathname(path)
    end

    def chains
      @chains ||= calculate_chains
    end

    private

    def calculate_chains
      sorted = asset_candidates.sort_by(&:timestamp)

      sorted.slice_before(&:full?).map do |chain|
        next nil unless chain.first.full?

        chain.each_cons(2) do |pred, succ|
          next unless succ.timestamp_from == pred.timestamp
          succ.base = pred
          pred.basing = succ
        end

        [
          chain.first,
          *chain.drop(1).take_while(&:base)
        ]
      end.compact
    end

    def asset_candidates
      Pathname.glob(path + '*.manifest').map do |manifest_path|
        Asset.new(manifest_path)
      end.sort_by(&:timestamp_from)
    end
  end
end
