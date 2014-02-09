#
# asset.rb - a single duplicity backup (comprised of multiple files)
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'pathname'
require 'fileutils'

module Triplicity
  module Site
    class Asset
      attr_accessor :base, :basing, :manifest_name

      def initialize(site, manifest_name)
        @site = site
        @manifest_name = manifest_name
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

      def size
        file_names.map do |name|
          @site.operations.file_size(name)
        end.reduce(:+)
      end

      def pessimistic_size
        size + file_names.length * 4096
      end

      def inspect
        "#<#{self.class.name}: #{@manifest_name} of #{@site.inspect} >"
      end

      def remove
        file_names.reverse.each do |name|
          @site.operations.remove name
        end
      end

      # must only be used for local assets
      def upload_to(target_site)
        local_pathnames = [*file_names.drop(1), file_names.first].map do |name|
          @site.operations.local_pathname(name)
        end

        local_pathnames.each do |local_pathname|
          target_site.operations.upload local_pathname
        end
      end

      private

      def file_names
        @file_names ||= calculate_file_names
      end

      TIMESTAMP_RE = '[\dTZ]{16}'
      CAPTURE_TS = "(#{TIMESTAMP_RE})"

      def match_segments
        @match_segments ||= %r{-(inc|full)\.#{CAPTURE_TS}(?:\.to\.#{CAPTURE_TS})?}.match(@manifest_name)
      end

      def calculate_file_names
        name = Pathname(@manifest_name).basename('.manifest').basename('.manifest.gpg').to_s

        [
          @manifest_name,
          *@site.operations.glob(name + '*.difftar.*')
        ]
      end
    end
  end
end
