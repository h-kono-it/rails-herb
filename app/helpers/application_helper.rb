module ApplicationHelper
  # CSS class for a signal light (:green, :yellow, :red)
  def light_class(light)
    "is-#{light}"
  end
end
