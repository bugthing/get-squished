class Player
  extend Delegate

  SCREEN_W = 1280

  def initialize(entity)
    self.entity = entity
  end

  attr_accessor :entity

  delegate :x, :y, :h, :w, :path, :facing, :dead, :moving, :walk_frame,
           :intersect_rect?, to: :entity

  def defaults!
    self.x          = 400
    self.y          = Game::FLOOR_Y
    self.h          = 60
    self.w          = 60
    self.facing     = :left
    self.dead       = false
    self.moving     = false
    self.walk_frame = 0
    self.path       = "sprites/bunny.png"
  end

  def to_sprite(sx = 0, sy = 0)
    bob = moving ? (Math.sin(walk_frame * 0.4) * 3).to_i : 0
    {
      x: x + sx,
      y: y + sy + bob,
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
    self.x      = (x - 3).clamp(0, SCREEN_W - w)
    self.facing = :left
    self.moving = true
    self.walk_frame = walk_frame + 1
  end

  def move_right
    self.x      = (x + 3).clamp(0, SCREEN_W - w)
    self.facing = :right
    self.moving = true
    self.walk_frame = walk_frame + 1
  end

  def stop
    self.moving     = false
    self.walk_frame = 0
  end

  def squished
    self.dead = true
    self.path = "sprites/blood.png"
  end
end
