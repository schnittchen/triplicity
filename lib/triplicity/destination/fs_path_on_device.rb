module Triplicity
  module Destination
    class FsPathOnDevice < Base
      attr_reader :device_uuid, :rel_path

      def with_accessible_site
        # yields site if possible
      end

    end
  end
end
