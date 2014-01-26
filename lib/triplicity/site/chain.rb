module Triplicity
  module Site
    class Chain
      def initialize(assets)
        @assets = assets
      end

      def inspect
        "##{self.class.name}: #{@assets.first.manifest_path}>"
      end
    end
  end
end
