# Get Squished! — Complete Game Design
**Date:** 2026-03-14
**Goal:** Polish and complete the game to a shippable state.

---

## Overview

"Get Squished!" is a 2D avoidance game where a bunny dodges falling feet. The player's only defence is agility and water balloons. The game ends when the bunny is squished. Score is survival time in seconds. Built with DragonRuby by a developer and their 8-year-old daughter.

---

## 1. Architecture — Game States

Three explicit states managed by the `Game` class as a state machine:

```
:title → (any key) → :playing → (squished) → :game_over → (R) → :playing
```

- **`:title`** — animated bunny, game title, persistent high score, "Press any key to start"
- **`:playing`** — full game loop: movement, feet, balloons, score, HUD
- **`:game_over`** — survival time, high score (updated if beaten), "Press R to restart", saves to disk

`Game` routes to `tick_<state>` and `render_<state>` methods per state.

**New classes:** `WaterBalloon`, `BalloonInventory`, `HUD`, `TitleScreen`, `GameOverScreen`, `HighScore`
**Kept and enhanced:** `Player`, `Foot`, `Feet`, `Delegate`

---

## 2. Water Balloon Mechanic

**Firing:** Spacebar spawns a balloon at the bunny's centre. Travels straight up at 8px/frame. Multiple balloons can be in flight simultaneously.

**Inventory:** Max 3 balloons. Each fired balloon reduces count by 1. One balloon refills every 5 seconds. HUD shows remaining balloons as icons.

**Hit detection:** Balloon intersects a foot → foot enters "slowed" state for 3 seconds, then returns to normal speed.

**Degrading slow multiplier:**
```ruby
slow_multiplier = [0.15, 0.8 - (score_seconds / 60.0)].max
```
- At  0s: foot slowed to 15% speed (very effective)
- At 30s: foot slowed to 50% speed (still useful)
- At 60s: foot slowed to 15% speed (minimum cap — never useless)

**Visual:** Balloon rendered as a small cyan solid (no new sprite needed). On hit: 5–6 white/blue particle dots that spread and fade over 20 frames.

---

## 3. Difficulty Progression

**Foot speed scaling:**
```ruby
effective_speed = base_speed * (1 + score_seconds / 45.0)
```
- At  0s: 1× speed
- At 45s: 2× speed
- At 90s: 3× speed

**More feet over time:**
- Start: 3 feet
- Every 20 seconds: +1 foot
- Maximum: 7 feet

**Background colour shift:** Pale blue → deep red as score increases, rendered as two layered solids with changing alpha. Gives visual sense of mounting danger.

---

## 4. Polish & Visual Effects

**Player animation:**
- Walking cycle: two frames alternating via `tile_x` toggle every 8 frames while moving
- Idle when standing still

**Screen shake on death:** Camera offsets ±5px randomly for 20 frames.

**Foot stomp effect:** When a foot reaches the floor, 4–5 grey dust particles spread outward and fade over 15 frames.

**Title screen:**
- Bunny bobs on sine wave (y position)
- High score displayed below title
- "Press any key to start" pulses in opacity

**HUD during play:**
- Top-left: survival time in seconds
- Top-right: balloon icons (filled = available, outline = empty/recharging)

**Game over screen:**
- Large "SQUISHED!" text
- Survival time + high score
- "New high score!" flash if beaten
- "Press R to restart"

---

## 5. Audio

**Background music:** Single looping track during `:playing`. Stops on game over, restarts on new game.

**Sound effects:**
| Event | Sound |
|---|---|
| Balloon fired | Short soft "poof" |
| Balloon hits foot | Wet "splat" |
| Foot stomps floor | Low "thud" |
| Player squished | Crunchy "squish" |
| Game over | Short sad jingle |
| New high score | Short celebratory chime |

**Format:** `.ogg` or `.wav` via DragonRuby's `outputs.sounds` (SFX) and `outputs.music` (loop).
**Fallback:** Audio calls stubbed if asset files not yet sourced — no logic changes needed.

---

## 6. Persistent High Score

Saved to disk on game over using DragonRuby's `$gtk.serialize_state` / file write API.
Loaded on game start. Displayed on title screen and game over screen.

---

## 7. Bounds Checking

Player cannot move off screen. Hard clamp:
```ruby
self.x = x.clamp(0, 1280 - w)
```

---

## Asset Requirements

| Asset | Status |
|---|---|
| `sprites/bunny.png` | Exists — needs walking frames or tile sheet |
| `sprites/foot.png` | Exists |
| `sprites/blood.png` | Exists |
| `sprites/balloon.png` | Optional — can use cyan solid primitive |
| `sounds/music.ogg` | Needed |
| `sounds/poof.wav` | Needed |
| `sounds/splat.wav` | Needed |
| `sounds/thud.wav` | Needed |
| `sounds/squish.wav` | Needed |
| `sounds/game_over.wav` | Needed |
| `sounds/high_score.wav` | Needed |
