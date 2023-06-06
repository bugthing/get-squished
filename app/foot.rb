class Foot
  extend Delegate

  ROOF_Y=620

  def initialize(entity)
    self.entity = entity
    self.path = "sprites/foot.png"
  end

  attr_accessor :entity, :path

  delegate :x, :y, :h, :w, :facing, :direction, :speed, to: :entity

  def defaults!(right_of: nil)
    self.x = right_of ? (right_of.x + random_x) : random_x
    self.y = ROOF_Y
    self.h = 100
    self.w = 100
    self.facing = rand < 0.5 ? :right : :left
    self.direction = :down
    self.speed = rand(20)+1
  end

  def advance
    if self.direction == :up
      self.y = self.y + self.speed
    elsif self.direction == :down
      self.y = self.y - self.speed
    end
    self.direction = :up if self.y < Game::FLOOR_Y
    self.direction = :down if self.y > ROOF_Y
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
