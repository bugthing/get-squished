class Foot
  extend Delegate

  ROOF_Y = 620

  def initialize(entity)
    self.entity = entity
    self.path = "sprites/foot.png"
  end

  attr_accessor :entity, :path

  delegate :x, :y, :h, :w, :facing, :direction, :speed,
           :slow_timer, :slow_amount, to: :entity

  def defaults!(right_of: nil)
    self.x          = right_of ? (right_of.x + random_x) : random_x
    self.y          = ROOF_Y
    self.h          = 100
    self.w          = 100
    self.facing     = rand < 0.5 ? :right : :left
    self.direction  = :down
    self.speed      = rand(4) + 1
    self.slow_timer  = 0
    self.slow_amount = 1.0
  end

  def advance(score_seconds = 0)
    tick_slow
    effective = current_speed(score_seconds)
    if direction == :up
      self.y = y + effective
    elsif direction == :down
      self.y = y - effective
    end
    self.direction = :up if y < Game::FLOOR_Y
    if y > ROOF_Y
      self.direction = :down
      self.x         = 50 + rand(1130)
      self.facing    = rand < 0.5 ? :right : :left
    end
  end

  def score_value(score_seconds)
    (speed * (1.0 + score_seconds / 45.0)).ceil
  end

  def slow!(multiplier)
    self.slow_amount = multiplier
    self.slow_timer  = 180  # 3 seconds at 60fps
  end

  def hitbox
    { x: x + 20, y: y, w: 60, h: 35 }
  end

  def to_sprite(sx = 0, sy = 0)
    {
      x: x + sx,
      y: y + sy,
      w: w,
      h: h,
      path: path,
      flip_horizontally: facing == :right
    }
  end

  def random_x
    100 + (rand * (1080 / Feet::FOOT_COUNT))
  end

  private

  def tick_slow
    return if slow_timer <= 0
    self.slow_timer -= 1
    self.slow_amount = 1.0 if slow_timer <= 0
  end

  def current_speed(score_seconds)
    scaling = 1.0 + (score_seconds / 45.0)
    effective_slow = slow_timer > 0 ? slow_amount : 1.0
    (speed * scaling * effective_slow).ceil
  end
end
