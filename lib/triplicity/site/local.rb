#
# local.rb - a site inside a local directory tree
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/site/base'

require 'pathname'

module Triplicity
  module Site
    class Local < Base
      attr_accessor :path

      def initialize(path)
        @path = Pathname(path)
      end

      def inspect
        "<##{self.class.name} at #{path}>"
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
