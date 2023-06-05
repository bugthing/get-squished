class Game
  attr_gtk

  def tick
    process_inputs
    render
  end

  def process_inputs
    process_move
  end

  def render
    outputs.sprites << player.to_sprite
    feet.each_foot do |foot|
      outputs.sprites << foot.to_sprite
    end
  end

  def process_move
    if inputs.keyboard.left
      player.move_left
    elsif inputs.keyboard.right
      player.move_right
    end
  end

  def feet
    Feet.new(state)
  end

  def player
    if state.player
      Player.new(state.player)
    else
      state.player = state.new_entity(:player)
      Player.new(state.player).tap { _1.defaults! }
    end
  end
end