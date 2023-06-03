
class Game
  attr_gtk

  def tick
    apply_defaults
    process_inputs
    render_player
  end

  def apply_defaults
  end

  def render_player
    outputs.sprites << player.to_sprite
  end

  def process_inputs
    process_move
  end

  def process_move
    if inputs.keyboard.left
      player.move_left
    elsif inputs.keyboard.right
      player.move_right
    end
  end

  def player
    Player.new(state.player || args.state.new_entity(:player))
  end

  class Player
    def initialize(state)
    end

    def to_sprite
      {
        x: 600,
        y: 300,
        w: 60,
        h: 60,
        path: 'sprites/green-girl/walking.png',
        tile_x: 0,
        tile_y: 0,
        tile_w: 60,
        tile_h: 60,
        flip_horizontally: 0
      }
    end
  end
end

def tick args
  $game ||= Game.new
  $game.args = args
  $game.tick
end

$gtk.reset
