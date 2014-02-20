#
# duplicity_arguments.rb - DSL class capturing arguments for invocations of duplicity
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/duplicity_time'

module Triplicity
  module SetupDsl
    class DuplicityArguments
      def initialize(primary, source_pathname)
        @primary = primary
        @source_pathname = source_pathname
        @extra_arguments = []
      end

      def self.dsl_methods
        [
          :extra_arguments, :no_encryption, :exclude_globbing_filelist,
          :exclude_source_relative, :full_if_older_than
        ]
      end

      def extra_arguments(*args)
        @extra_arguments += args
      end

      def no_encryption
        extra_arguments '--no-encryption'
      end

      def exclude_globbing_filelist(file)
        extra_arguments '--exclude-globbing-filelist', file
      end

      def exclude_source_relative(*args)
        args.each do |arg|
          extra_arguments '--exclude', (@source_pathname + arg).to_s
        end
      end

      def full_if_older_than(seconds)
        time = DuplicityTime.from_fixnum(seconds)
        extra_arguments '--full-if-older-than', time
      end

      def source_arg
        @source_pathname.to_s
      end

      def target_arg
        "file://#{@primary.path}"
      end

      def other_args
        @extra_arguments.to_enum
      end
    end
  end
end
