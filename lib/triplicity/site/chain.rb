module Triplicity
  module Site
    class Chain
      attr_reader :assets

      def initialize(assets)
        @assets = assets
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
