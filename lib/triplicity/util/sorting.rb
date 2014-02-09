#
# sotring.rb - comprehensble sorting of timestamps
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

module Triplicity
  module Util
    module Sorting
      def youngest_first(array, method = :timestamp)
        oldest_first(array, method).reverse
      end

      def oldest_first(array, method = :timestamp)
        array.sort_by(&method)
      end
    end
  end
end
