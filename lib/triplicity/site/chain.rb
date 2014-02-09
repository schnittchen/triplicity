require 'triplicity/util/sorting'

module Triplicity
  module Site
    class Chain
      include Util::Sorting

      def initialize(assets)
        @assets = oldest_first(assets)
      end

      def assets
        @assets.to_enum
      end

      def self.empty
        new([])
      end

      # this can serve as an identifier
      def base_timestamp
        @assets.first.timestamp
      end

      def latest_timestamp
        @assets.last.timestamp
      end

      def inspect
        "##{self.class.name}: #{@assets.first.manifest_name}>"
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

      def upload_to(site)
        @assets.each do |asset|
          asset.upload_to(site)
        end
      end
    end
  end
end
