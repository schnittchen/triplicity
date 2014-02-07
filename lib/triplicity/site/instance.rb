require 'triplicity/site/base'

require 'pathname'

module Triplicity
  module Site
    class Instance < Base
      attr_accessor :path

      def initialize(path)
        @path = Pathname(path)
      end

      class Operations
        def initialize(dir_path)
          @dir_path = dir_path
        end

        def glob(pattern)
          Pathname.glob(@dir_path + pattern).map do |p|
            p.basename.to_s
          end
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
    end
  end
end
