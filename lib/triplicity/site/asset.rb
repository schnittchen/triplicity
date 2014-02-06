require 'pathname'
require 'fileutils'

module Triplicity
  module Site
    class Asset
      attr_accessor :base, :basing, :manifest_path

      def initialize(site, manifest_path)
        @site = site
        @manifest_path = manifest_path
        @full_basename = (manifest_path.parent + manifest_path.basename('.manifest')).to_s
      end

      def timestamp
        full? ? match_segments[2] : timestamp_to
      end

      def timestamp_from
        match_segments[2]
      end

      def timestamp_to
        match_segments[3]
      end

      def incremental?
        match_segments[1] == 'inc'
      end

      def full?
        !incremental?
      end

      def paths
        @paths ||= calculate_paths
      end

      def size
        paths.map do |path|
          @site.operations.file_size(path.basename.to_s)
        end.reduce(:+)
      end

      def pessimistic_size
        size + paths.length * 4096
      end

      def inspect
        "##{self.class.name}: #{@manifest_path}>"
      end

      def remove
        paths.reverse.each do |path|
          @site.operations.remove path.basename.to_s
        end
      end

      # must only be used for local assets
      def upload_to(target_site)
        from_paths = [*paths.drop(1), paths.first]
        local_pathnames = from_paths.map do |full_path|
          name = full_path.basename.to_s
          @site.operations.local_pathname(name)
        end

        local_pathnames.each do |local_pathname|
          target_site.operations.upload local_pathname
        end
      end

      private

      TIMESTAMP_RE = '[\dTZ]{16}'
      CAPTURE_TS = "(#{TIMESTAMP_RE})"

      def match_segments
        @match_segments ||= %r{-(inc|full)\.#{CAPTURE_TS}(?:\.to\.#{CAPTURE_TS})?}.match(@full_basename)
      end

      def calculate_paths
        name = Pathname(@full_basename).basename.to_s

        [
          @manifest_path,
          *@site.operations.glob(name + '*.difftar.gz')
        ]
      end
    end
  end
end
