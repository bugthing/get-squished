class Player
  extend Delegate
  def initialize(entity)
    self.entity = entity
  end

  attr_accessor :entity

  delegate :x, :y, :h, :w, :path, :facing, :dead, :intersect_rect?, to: :entity

  def defaults!
    self.x = 400
    self.y = Game::FLOOR_Y
    self.h = 60
    self.w = 60
    self.facing = :left
    self.dead = false
    self.path = "sprites/bunny.png"
  end

  def to_sprite
    {
      x: x,
      y: y,
      h: h,
      w: w,
      path: path,
      tile_x: 0,
      tile_y: 0,
      tile_w: 60,
      tile_h: 60,
      flip_horizontally: facing == :right
    }
  end

  def move_left
    self.x = x + -3
    self.facing = :left
  end

  def move_right
    self.x = x + 3
    self.facing = :right
  end

  def squished
    self.dead = true
    self.path = "sprites/blood.png"
  end
end
