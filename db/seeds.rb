# Sample road networks. Safe to run again: each network is rebuilt from scratch.

def build_network(name)
  Network.find_by(name:)&.destroy
  network = Network.create!(name:)
  nodes = Hash.new { |hash, (x, y)| hash[[ x, y ]] = network.nodes.create!(x:, y:) }
  yield network, nodes
  network
end

build_network("十字路") do |network, nodes|
  center = nodes[[ 30, 30 ]]
  center.update!(signalized: true)
  [ [ 0, 30 ], [ 60, 30 ], [ 30, 0 ], [ 30, 60 ] ].each { |point| network.connect(nodes[point], center) }
end

build_network("信号なし十字路") do |network, nodes|
  center = nodes[[ 30, 30 ]]
  [ [ 0, 30 ], [ 60, 30 ], [ 30, 0 ], [ 30, 60 ] ].each { |point| network.connect(nodes[point], center) }
end

build_network("格子 2×2") do |network, nodes|
  lines = [ 20, 40 ]
  lines.product(lines).each { |point| nodes[point].update!(signalized: true) }

  lines.each do |y|
    [ 0, *lines, 60 ].each_cons(2) { |a, b| network.connect(nodes[[ a, y ]], nodes[[ b, y ]]) }
  end
  lines.each do |x|
    [ 0, *lines, 60 ].each_cons(2) { |a, b| network.connect(nodes[[ x, a ]], nodes[[ x, b ]]) }
  end
end
