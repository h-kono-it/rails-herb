module IntersectionsHelper
  LANE_LABELS = { east: "東行き", west: "西行き", south: "南行き", north: "北行き" }.freeze
  LIGHT_LABELS = { green: "青", yellow: "黄", red: "赤" }.freeze

  # Left/top of a grid cell as a percentage of the map.
  def grid_percent(value, size)
    (value * 100.0 / size).round(3)
  end

  # Where each lane's signal head sits: just before the stop line, on the
  # kerb side (traffic keeps left).
  def signal_cell(intersection, lane)
    stop = intersection.box_entry - 1
    x, y = intersection.cell(lane, stop)
    case lane
    when :east then [ x, y - 1 ]
    when :west then [ x, y + 1 ]
    when :south then [ x + 1, y ]
    when :north then [ x - 1, y ]
    end
  end
end
