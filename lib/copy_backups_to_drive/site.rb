require 'pathname'

module CopyBackupsToDrive
  class Site
    attr_accessor :path

    class Asset
      attr_accessor :base, :basing

      def initialize(manifest_path)
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
        paths.map(&:size).reduce(:+)
      end

      def pessimistic_size
        size + paths.length * 4096
      end

      private

      TIMESTAMP_RE = '[\dTZ]{16}'
      CAPTURE_TS = "(#{TIMESTAMP_RE})"

      def match_segments
        @match_segments ||= %r{-(inc|full)\.#{CAPTURE_TS}(?:\.to\.#{CAPTURE_TS})?}.match(@full_basename)
      end

      def calculate_paths
        [
          @manifest_path,
          *Pathname.glob(@full_basename + '*.difftar.gz'),
        ]
      end
    end

    def initialize(path)
      @path = Pathname(path)
    end

    def assets
      @assets ||= calculate_assets
    end

    private

    def calculate_assets
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
