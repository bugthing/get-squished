module Forwardable
  def delegate(*attrs, to:)
    attrs.each do |attr|
      define_method(attr) do
        send(to).send(attr)
      end
      define_method("#{attr}=") do |*args|
        send(to).send("#{attr}=", *args)
      end
    end
  end
end

class Game
  attr_gtk

  def tick
    apply_defaults
    process_inputs
    render_player
  end

  def apply_defaults
  end

  def process_inputs
    process_move
  end

  def render_player
    outputs.sprites << player.to_sprite
  end

  def process_move
    if inputs.keyboard.left
      player.move_left
    elsif inputs.keyboard.right
      player.move_right
    end
  end

  def player
    state.player ? Player.new(state.player) : Player.new(state.player = args.state.new_entity(:player)).tap { _1.defaults! }
  end

  class Player
    extend Forwardable
    def initialize(state)
      self.state = state
      self.path = "sprites/bunny.png"
    end

    attr_accessor :state, :path

    delegate :x, :y, :h, :w, to: :state

    def defaults!
      self.x = 400
      self.y = 20
      self.h = 60
      self.w = 60
    end

    def to_sprite
      {
        x: x,
        y: y,
        w: 60,
        h: 60,
        path: path,
        tile_x: 0,
        tile_y: 0,
        tile_w: 60,
        tile_h: 60,
        flip_horizontally: 0
      }
    end

    def move_left
      self.x = x + -1
    end

    def move_right
      self.x = x + 1
    end
  end
end

def tick args
  $game ||= Game.new
  $game.args = args
  $game.tick
end

$gtk.reset
