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

      def latest_timestamp
        assets.map(&:timestamp).max
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

      def copy_to(target)
        @assets.each { |asset| asset.copy_to target }
      end
    end
  end
end
