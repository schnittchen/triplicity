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

      class Operations
        def initialize(dir_path)
          @dir_path = dir_path
        end

        def glob(pattern)
          Pathname.glob(@dir_path + pattern)
        end

        def file_size(name)
          local_pathname(name).size
        end

        def remove(name)
          local_pathname(name).unlink
        end

        def upload(local_pathname)
          target = @dir_path + local_pathname.basename
          FileUtils.cp(local_pathname, target) unless target.exist? && target.size == local_pathname.size
        end

        def local_pathname(name)
          @dir_path + name
        end
      end

      def operations
        @operations ||= Operations.new(@path)
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
          Asset.new(self, manifest_path.basename.to_s)
        end
      end
    end
  end
end
