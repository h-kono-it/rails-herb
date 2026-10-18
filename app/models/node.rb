class Node < ApplicationRecord
  belongs_to :network
  has_many :outgoing_links, class_name: "Link", foreign_key: :from_node_id, dependent: :destroy, inverse_of: :from_node
  has_many :incoming_links, class_name: "Link", foreign_key: :to_node_id, dependent: :destroy, inverse_of: :to_node

  validates :x, :y, numericality: { only_integer: true, in: 0..Network::SIZE }
  validates :y, uniqueness: { scope: [ :network_id, :x ] }
  validates :inflow, numericality: { only_integer: true, in: 0..100 }
  validates :cycle, numericality: { only_integer: true, in: 12..120 }
  validates :split, numericality: { only_integer: true, in: 10..90 }
  validates :offset, numericality: { only_integer: true, in: 0..119 }
end
