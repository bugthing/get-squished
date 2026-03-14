class Game
  attr_gtk

  FLOOR_Y = 20

  def tick
    defaults
    case state.game_state
    when :title
      tick_title
      render_title
    when :playing
      tick_playing
      render_playing
    when :game_over
      tick_game_over
      render_game_over
    end
  end

  # ── State defaults ────────────────────────────────────────────

  def defaults
    if state.game_state.nil?
      state.game_state = :title
      saved = $gtk.read_file("high_score.txt")
      state.high_score = saved ? saved.to_i : 0
    end
  end

  # ── Title state ───────────────────────────────────────────────

  def tick_title
    any_key = inputs.keyboard.key_down.space ||
              inputs.keyboard.key_down.enter ||
              inputs.keyboard.key_down.up    ||
              inputs.keyboard.key_down.down  ||
              inputs.keyboard.key_down.left  ||
              inputs.keyboard.key_down.right
    start_game if any_key || inputs.mouse.click
  end

  def render_title
    outputs.solids << { x: 0, y: 0, w: 1280, h: 720, r: 100, g: 180, b: 220 }
    bob_y = 300 + (Math.sin(tick_count * 0.05) * 20).to_i
    outputs.sprites << { x: 580, y: bob_y, w: 80, h: 80, path: "sprites/bunny.png" }
    outputs.labels << { x: 640, y: 620, text: "GET SQUISHED!", size_enum: 10,
                        alignment_enum: 1, r: 255, g: 80, b: 80 }
    outputs.labels << { x: 640, y: 530, text: "Best: #{state.high_score}s",
                        size_enum: 4, alignment_enum: 1, r: 40, g: 40, b: 80 }
    alpha = ((Math.sin(tick_count * 0.08) + 1) * 127).to_i
    outputs.labels << { x: 640, y: 460, text: "Press any key to start",
                        size_enum: 2, alignment_enum: 1, r: 40, g: 40, b: 80, a: alpha }
  end

  # ── Playing state ─────────────────────────────────────────────

  def start_game
    state.new_high_score = false
    state.game_state       = :playing
    state.score_start_tick = tick_count
    state.player           = nil
    state.feet             = nil
    state.balloons         = []
    state.particles        = []
    state.shake_frames     = 0
    state.balloon_count    = 3
    state.balloon_refill_timer = 0
    audio[:music] = { input: "sounds/music.ogg", looping: true } if file_exists?("sounds/music.ogg")
  end

  def tick_playing
    process_inputs
    advance_feet
    advance_balloons
    advance_particles
    check_balloon_refill
    state.shake_frames -= 1 if state.shake_frames > 0
    end_game if player.dead
  end

  def render_playing
    sx = state.shake_frames > 0 ? rand(11) - 5 : 0
    sy = state.shake_frames > 0 ? rand(11) - 5 : 0

    render_background
    feet.each_foot { |foot| outputs.sprites << foot.to_sprite(sx, sy) }
    render_balloons(sx, sy)
    render_particles(sx, sy)
    outputs.sprites << player.to_sprite(sx, sy)
    render_hud
  end

  def render_background
    t = [score_seconds / 120.0, 1.0].min
    r = (100 + (155 * t)).to_i
    g = (180 - (160 * t)).to_i
    b = (220 - (200 * t)).to_i
    outputs.solids << { x: 0, y: 0, w: 1280, h: 720, r: r, g: g, b: b }
  end

  def render_balloons(sx, sy)
    (state.balloons || []).each do |b|
      outputs.solids << { x: b[:x] + sx, y: b[:y] + sy, w: b[:w], h: b[:h],
                          r: 0, g: 200, b: 220, a: 220 }
    end
  end

  def render_particles(sx, sy)
    (state.particles || []).each do |p|
      alpha = (255 * p[:life] / p[:max_life]).to_i
      outputs.solids << { x: p[:x].to_i + sx, y: p[:y].to_i + sy,
                          w: 6, h: 6, r: p[:r], g: p[:g], b: p[:b], a: alpha }
    end
  end

  def render_hud
    outputs.labels << { x: 20, y: 710, text: "#{score_seconds}s",
                        size_enum: 4, r: 255, g: 255, b: 255 }
    3.times do |i|
      x = 1220 - (i * 35)
      if i < (state.balloon_count || 0)
        outputs.solids << { x: x, y: 690, w: 20, h: 28, r: 0, g: 200, b: 220, a: 220 }
      else
        outputs.borders << { x: x, y: 690, w: 20, h: 28, r: 120, g: 120, b: 140, a: 180 }
      end
    end
  end

  # ── Game over state ───────────────────────────────────────────

  def end_game
    state.game_state  = :game_over
    state.final_score = score_seconds
    audio.delete(:music)
    outputs.sounds << "sounds/game_over.wav" if file_exists?("sounds/game_over.wav")
    if state.final_score > (state.high_score || 0)
      state.high_score = state.final_score
      state.new_high_score = true
      $gtk.write_file("high_score.txt", state.final_score.to_s)
      outputs.sounds << "sounds/high_score.wav" if file_exists?("sounds/high_score.wav")
    end
  end

  def tick_game_over
    start_game if inputs.keyboard.key_down.r
  end

  def render_game_over
    outputs.solids << { x: 0, y: 0, w: 1280, h: 720, r: 20, g: 10, b: 10 }
    outputs.labels << { x: 640, y: 580, text: "SQUISHED!", size_enum: 12,
                        alignment_enum: 1, r: 255, g: 60, b: 60 }
    outputs.labels << { x: 640, y: 480, text: "You survived #{state.final_score}s",
                        size_enum: 4, alignment_enum: 1, r: 220, g: 180, b: 180 }
    outputs.labels << { x: 640, y: 430, text: "Best: #{state.high_score}s",
                        size_enum: 4, alignment_enum: 1, r: 220, g: 180, b: 180 }
    if state.new_high_score
      pulse = ((Math.sin(tick_count * 0.15) + 1) * 127).to_i + 128
      outputs.labels << { x: 640, y: 380, text: "NEW HIGH SCORE!",
                          size_enum: 5, alignment_enum: 1, r: 255, g: 220, b: 0, a: pulse }
    end
    outputs.labels << { x: 640, y: 300, text: "Press R to play again",
                        size_enum: 2, alignment_enum: 1, r: 180, g: 180, b: 180 }
  end

  # ── Input handling ────────────────────────────────────────────

  def process_inputs
    if inputs.keyboard.left
      player.move_left
    elsif inputs.keyboard.right
      player.move_right
    else
      player.stop
    end
    fire_balloon if inputs.keyboard.key_down.space
  end

  def fire_balloon
    return if (state.balloon_count || 0) <= 0
    state.balloon_count -= 1
    cx = player.x + player.w.idiv(2) - 10
    state.balloons << { x: cx, y: player.y + player.h, w: 20, h: 28 }
    outputs.sounds << "sounds/poof.wav" if file_exists?("sounds/poof.wav")
  end

  # ── Balloon logic ─────────────────────────────────────────────

  def advance_balloons
    state.balloons ||= []
    state.balloons.each { |b| b[:y] += 8 }
    state.balloons.reject! do |balloon|
      hit = false
      feet.each_foot do |foot|
        next if hit
        if foot.entity.intersect_rect?(balloon)
          foot.slow!(slow_multiplier)
          spawn_splash_particles(balloon[:x] + 10, balloon[:y] + 14)
          outputs.sounds << "sounds/splat.wav" if file_exists?("sounds/splat.wav")
          hit = true
        end
      end
      hit || balloon[:y] > 740
    end
  end

  def slow_multiplier
    [0.15, 0.8 - (score_seconds / 60.0)].max
  end

  def check_balloon_refill
    state.balloon_count ||= 3
    state.balloon_refill_timer ||= 0
    return if state.balloon_count >= 3
    state.balloon_refill_timer += 1
    if state.balloon_refill_timer >= 300
      state.balloon_count += 1
      state.balloon_refill_timer = 0
    end
  end

  # ── Particle logic ────────────────────────────────────────────

  def spawn_splash_particles(x, y)
    state.particles ||= []
    6.times do
      state.particles << {
        x: x.to_f, y: y.to_f,
        dx: (rand * 5) - 2.5, dy: (rand * 5) - 2.5,
        life: 20, max_life: 20,
        r: rand(80), g: 170 + rand(85), b: 180 + rand(75)
      }
    end
  end

  def spawn_stomp_particles(x, y)
    state.particles ||= []
    5.times do
      state.particles << {
        x: x.to_f + rand(100), y: y.to_f,
        dx: (rand * 6) - 3, dy: rand(4).to_f,
        life: 15, max_life: 15,
        r: 160, g: 140, b: 100
      }
    end
  end

  def advance_particles
    state.particles ||= []
    state.particles.each { |p| p[:x] += p[:dx]; p[:y] += p[:dy]; p[:life] -= 1 }
    state.particles.reject! { |p| p[:life] <= 0 }
  end

  # ── Feet logic ────────────────────────────────────────────────

  def advance_feet
    feet.each_foot do |foot|
      was_above_floor = foot.y > FLOOR_Y
      foot.advance(score_seconds)
      if was_above_floor && foot.y <= FLOOR_Y
        spawn_stomp_particles(foot.x, FLOOR_Y)
        outputs.sounds << "sounds/thud.wav" if file_exists?("sounds/thud.wav")
      end
      if player.intersect_rect?(foot)
        player.squished
        state.shake_frames = 20
        outputs.sounds << "sounds/squish.wav" if file_exists?("sounds/squish.wav")
      end
    end
    feet.update_count(score_seconds)
  end

  # ── Helpers ───────────────────────────────────────────────────

  def score_seconds
    return 0 unless state.score_start_tick
    (tick_count - state.score_start_tick).idiv(60)
  end

  def file_exists?(path)
    !$gtk.read_file(path).nil?
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
