class Fixnum
  def second
    self
  end
  alias_method :seconds, :second

  def minute
    self * 60
  end
  alias_method :minutes, :minute

  def hour
    self * 60 * 60
  end
  alias_method :hours, :hour

  def day
    self * 60 * 60 * 24
  end
  alias_method :days, :day

  def week
    self * 60 * 60 * 24 * 7
  end
  alias_method :weeks, :week

  def month
    self * 60 * 60 * 24 * 7 * 30
  end
  alias_method :months, :month
end
