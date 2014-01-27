module Triplicity
  module Sorting
    def youngest_first(array, method = :timestamp)
      oldest_first(array, method).reverse
    end

    def oldest_first(array, method = :timestamp)
      array.sort_by(&method)
    end
  end
end
