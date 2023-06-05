class Foot
  extend Delegate

  def initialize(entity)
    self.entity = entity
    self.path = "sprites/foot.png"
  end

  attr_accessor :entity, :path

  delegate :x, :y, :h, :w, :facing, to: :entity

  def defaults!(right_of: nil)
    self.x = right_of ? (right_of.x + random_x) : random_x
    self.y = 620
    self.h = 100
    self.w = 100
    self.facing = rand < 0.5 ? :right : :left
  end

  def random_x
    100 + (rand * (1080 / Feet::FOOT_COUNT))
  end

  def to_sprite
    {
      x: x,
      y: y,
      w: w,
      h: h,
      path: path,
      flip_horizontally: facing == :right
    }
  end
end
