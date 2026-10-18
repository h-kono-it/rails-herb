module TrafficHelper
  # Matches the lane circle in the ring's 320x320 SVG.
  RING_SIZE = 320
  RING_RADIUS = 130

  # Point on the ring for a cell, as percentages of the ring box, starting at
  # 12 o'clock and going clockwise.
  def ring_percent(position, length)
    angle = 2 * Math::PI * position / length - Math::PI / 2
    center = RING_SIZE / 2.0
    [ center + RING_RADIUS * Math.cos(angle), center + RING_RADIUS * Math.sin(angle) ].map { |v| (v * 100 / RING_SIZE).round(2) }
  end

  # Red when stopped, green at full speed.
  def velocity_color(velocity, vmax)
    "hsl(#{(velocity.fdiv(vmax) * 130).round} 75% 45%)"
  end
end
