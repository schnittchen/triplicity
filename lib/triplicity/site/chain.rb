require 'triplicity/sorting'

module Triplicity
  module Site
    class Chain
      include Sorting

      def initialize(assets)
        @assets = oldest_first(assets)
      end

      def assets
        @assets.to_enum
      end

      def self.empty
        new([])
      end

      def has_asset_timestamp?(timestamp)
        !!@assets.find { |asset| asset.timestamp == timestamp }
      end

      def latest_timestamp
        @assets.last.timestamp
      end

      def inspect
        "##{self.class.name}: #{@assets.first.manifest_path}>"
      end

      def size
        @assets.map(&:size).reduce(:+)
      end

      def pessimistic_size
        @assets.map(&:pessimistic_size).reduce(:+)
      end

      def remove
        @assets.reverse.each(&:remove)
      end

      def copy_to(target, existing_chain = nil)
        existing_chain ||= Chain.empty
        @assets.each do |asset|
          asset.copy_to target unless existing_chain.has_asset_timestamp?(asset.timestamp)
        end
      end
    end
  end
end
