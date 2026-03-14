# Get Squished! — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use tussell-powers:executing-plans to implement this plan task-by-task.

**Goal:** Complete "Get Squished!" into a polished, shippable game with game states, water balloons, difficulty progression, visual polish, persistent high score, and full audio.

**Architecture:** State machine (`:title` → `:playing` → `:game_over`) lives in `Game`. Existing `Player`, `Foot`, `Feet` classes are enhanced in-place. New mechanics (balloons, particles, screen shake, stomp effects) are managed as plain arrays of hashes in `state`. High score persists via `$gtk.write_file` / `$gtk.read_file`.

**Tech Stack:** DragonRuby GTK, Ruby, sprite rendering via `outputs.sprites`, primitives via `outputs.solids`/`outputs.borders`, one-shot audio via `outputs.sounds`, looping music via `args.audio` hash.

---

## Task 1: Game State Machine

Transform `game.rb` into a state machine. This is the biggest change — it touches nearly everything but makes all subsequent tasks clean.

**Files:**
- Modify: `app/game.rb`

**Step 1: Replace game.rb entirely**

```ruby
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
    if state.final_score && state.final_score >= state.high_score
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
```

**Step 2: Run the game**

```bash
make
```

Expected: Game launches and shows the title screen with a bobbing bunny, title text, and pulsing "Press any key to start". Pressing any key should start the game (may error — that's fine, we fix Player and Foot next).

**Step 3: Commit**

```bash
git add app/game.rb
git commit -m "feat: add game state machine with title, playing, and game over states"
```

---

## Task 2: Update Player

Add bounds clamping, `stop` method, walk animation, and update `to_sprite` to accept a shake offset.

**Files:**
- Modify: `app/player.rb`

**Step 1: Replace player.rb entirely**

```ruby
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
```

**Step 2: Run the game and verify**

```bash
make
```

Expected: Player can't walk off screen edges. Bunny bobs slightly while moving.

**Step 3: Commit**

```bash
git add app/player.rb
git commit -m "feat: add player bounds clamping, stop method, and walk bob animation"
```

---

## Task 3: Update Foot

Add speed scaling via `advance(score_seconds)`, a `slow!` method with timer, and expose `entity` publicly. Update `to_sprite` to accept shake offset.

**Files:**
- Modify: `app/foot.rb`

**Step 1: Replace foot.rb entirely**

```ruby
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
    self.speed      = rand(20) + 1
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
    self.direction = :up   if y < Game::FLOOR_Y
    self.direction = :down if y > ROOF_Y
  end

  def slow!(multiplier)
    self.slow_amount = multiplier
    self.slow_timer  = 180  # 3 seconds at 60fps
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
```

**Step 2: Run the game and verify**

```bash
make
```

Expected: Game runs. Feet move normally at start. After 45s they should be visibly faster. Press spacebar to fire balloons (cyan rectangles) — feet they hit should slow down briefly.

**Step 3: Commit**

```bash
git add app/foot.rb
git commit -m "feat: add foot speed scaling, slow effect, and shake offset support"
```

---

## Task 4: Update Feet

Add `update_count` to spawn extra feet as the game progresses (one new foot every 20 seconds, up to 7 total). Also expose the `state` so `game.rb` can access foot entities directly.

**Files:**
- Modify: `app/feet.rb`

**Step 1: Replace feet.rb entirely**

```ruby
class Feet
  FOOT_COUNT   = 3
  MAX_FEET     = 7
  SPAWN_EVERY  = 20  # seconds

  def initialize(state)
    self.state       = state
    self.state.feet ||= default_collection
  end

  attr_accessor :state

  def each_foot
    state.feet.each { |entity| yield(Foot.new(entity)) }
  end

  def update_count(score_seconds)
    target = [FOOT_COUNT + (score_seconds / SPAWN_EVERY), MAX_FEET].min
    while state.feet.length < target
      entity = state.new_entity(:foot)
      foot   = Foot.new(entity)
      last   = Foot.new(state.feet.last)
      foot.defaults!(right_of: last)
      state.feet << entity
    end
  end

  private

  def default_collection
    all_new_feet.tap do |collection|
      prev_foot = nil
      collection.each do |entity|
        foot = Foot.new(entity)
        foot.defaults!(right_of: prev_foot)
        prev_foot = foot
      end
    end
  end

  def all_new_feet
    (0..(FOOT_COUNT - 1)).map { state.new_entity(:foot) }
  end
end
```

**Step 2: Run the game and verify**

```bash
make
```

Expected: Start with 3 feet. After 20s a 4th foot appears. After 40s a 5th. And so on up to 7.

**Step 3: Commit**

```bash
git add app/feet.rb
git commit -m "feat: dynamically add feet over time up to maximum of 7"
```

---

## Task 5: Source Audio Assets

The game references audio files in `sounds/`. Create the directory and add placeholder (or real) files so the game doesn't error on missing assets. The `file_exists?` guard in `game.rb` means missing files are safe — but having real sounds makes it much more fun.

**Files:**
- Create: `sounds/` directory

**Step 1: Create the sounds directory**

```bash
mkdir -p sounds
```

**Step 2: Source CC0 audio files**

Go to **https://freesound.org** or **https://opengameart.org** and download these files (CC0/CC-BY license):

| Filename | Search terms |
|---|---|
| `sounds/music.ogg` | "cute 8bit loop" or "chiptune loop" |
| `sounds/poof.wav` | "cartoon poof" or "soft pop" |
| `sounds/splat.wav` | "water splat" or "wet splat" |
| `sounds/thud.wav` | "stomp thud" or "foot stomp" |
| `sounds/squish.wav` | "squish crunch" or "cartoon squish" |
| `sounds/game_over.wav` | "sad jingle" or "game over short" |
| `sounds/high_score.wav` | "fanfare short" or "victory chime" |

Rename downloaded files to match the names above and place them in the `sounds/` directory.

**Fallback — create silent placeholder files (optional):**

If you want to run the game immediately with stubbed audio, create zero-byte files — DragonRuby will silently skip them but the `file_exists?` guards will pass:

```bash
# Only if you want stub files while you find real ones
touch sounds/poof.wav sounds/splat.wav sounds/thud.wav
touch sounds/squish.wav sounds/game_over.wav sounds/high_score.wav
```

Note: `music.ogg` is omitted from stubs intentionally — an invalid ogg might cause an error. Leave it missing and the game skips it cleanly.

**Step 3: Run the game and verify audio**

```bash
make
```

Expected: Sound effects play on balloon fire, foot stomp, squish, and game over. Music loops during gameplay.

**Step 4: Commit**

```bash
git add sounds/
git commit -m "feat: add audio assets directory and sound files"
```

---

## Task 6: Smoke Test the Full Game Loop

Verify the complete experience end-to-end before final polish.

**Step 1: Run the game**

```bash
make
```

**Step 2: Walk through the full game loop**

- [ ] Title screen shows with bobbing bunny, best score, and pulsing prompt
- [ ] Pressing any key starts the game
- [ ] Bunny moves left/right and bobs while moving
- [ ] Bunny cannot walk off screen edges
- [ ] 3 feet descend and bounce
- [ ] Background is pale blue at start
- [ ] Score counter increments every second (top-left)
- [ ] 3 balloon icons show top-right
- [ ] Spacebar fires a cyan balloon upward
- [ ] Balloon count decreases; icon changes to outline
- [ ] Balloon count refills (one per 5 seconds)
- [ ] Balloon hitting a foot slows it + spawns blue particles
- [ ] Foot stomping the floor spawns dust particles + thud sound
- [ ] After 20s a 4th foot appears
- [ ] Background gradually shifts toward red over time
- [ ] Getting squished shows blood sprite, screen shakes
- [ ] Game over screen shows SQUISHED!, survival time, best score
- [ ] If new best time, "NEW HIGH SCORE!" flashes
- [ ] Pressing R restarts the game
- [ ] High score persists after quitting and relaunching

**Step 3: Fix any issues found**

Address bugs before committing.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: complete Get Squished! game loop verified end-to-end"
```

---

## Task 7: Final Commit and Tag

**Step 1: Update README**

Add a Controls section to `README.md`:

```markdown
## Controls

- **Arrow keys** — move left / right
- **Spacebar** — throw water balloon (max 3, refills every 5 seconds)

## How to play

Survive as long as possible without getting squished by the descending feet.
Water balloons slow down feet on hit, but become less effective the longer you survive.
New feet appear every 20 seconds. Everything speeds up over time.
```

**Step 2: Commit and tag**

```bash
git add README.md
git commit -m "docs: update README with controls and how to play"
git tag v1.0.0
```

---

## Notes

- **DragonRuby audio API:** `audio[:key] = { input: "path", looping: true }` to start music; `audio.delete(:key)` to stop. One-shot SFX: `outputs.sounds << "path"`. Check https://docs.dragonruby.org if API differs.
- **Sprite sheet animation:** `bunny.png` appears to be a single frame. The walk bob (y sine wave) is used instead of tile animation. If you add a 2-frame sprite sheet (120×60), set `tile_w: 60` and alternate `tile_x` between `0` and `60` every 8 frames in `Player#to_sprite`.
- **`$gtk.read_file` on missing files:** Returns `nil` — handled by `file_exists?` guard throughout.
- **Screen resolution:** 1280×720 (DragonRuby default).
