// Tower Defense: balance enemy waves, tower damage, spawn rate
// Goal: survive 10 waves, close final wave, avg clear time ~500 frames

fn simulate_td(params : Array[Double], seed : Int) -> @dec.Metrics {
  let enemy_base_hp = params[0]
  let hp_scaling = params[1] // per-wave HP multiplier
  let spawn_interval = params[2] // frames between spawns
  let enemies_per_wave = params[3]
  let tower_damage = params[4]
  let tower_range = params[5]
  let tower_fire_rate = params[6] // frames between shots
  let max_waves = 10
  let mut waves_cleared = 0
  let mut total_clear_time = 0
  let mut closest_call = 1.0 // min base HP ratio during play
  let mut total_kills = 0
  let base_hp = 100.0
  let mut current_base_hp = base_hp
  let rng_base = seed * 11 + 7
  for wave = 0; wave < max_waves; wave = wave + 1 {
    let wave_hp = enemy_base_hp * (1.0 + hp_scaling * wave.to_double())
    let n_enemies = enemies_per_wave.to_int()
    let alive_enemies : Array[(Double, Double)] = [] // (hp, distance_to_base)
    let mut spawned = 0
    let mut frame = 0
    let mut fire_cooldown = 0
    let mut wave_kills = 0
    while spawned < n_enemies || alive_enemies.length() > 0 {
      frame = frame + 1
      if frame > 3000 { break } // timeout
      // Spawn
      if spawned < n_enemies && frame % @cmp.maximum(spawn_interval.to_int(), 1) == 0 {
        let dist = 200.0 + ((rng_base + wave * 17 + spawned * 7) % 50).to_double()
        alive_enemies.push((wave_hp, dist))
        spawned = spawned + 1
      }
      // Move enemies toward base
      for i = 0; i < alive_enemies.length(); i = i + 1 {
        let (hp, dist) = alive_enemies[i]
        alive_enemies[i] = (hp, dist - 1.0) // speed = 1 unit/frame
      }
      // Tower fires
      if fire_cooldown > 0 {
        fire_cooldown = fire_cooldown - 1
      } else if alive_enemies.length() > 0 {
        // Find closest enemy in range
        let mut best_idx = -1
        let mut best_dist = tower_range + 1.0
        for i = 0; i < alive_enemies.length(); i = i + 1 {
          let (_, dist) = alive_enemies[i]
          if dist < tower_range && dist < best_dist {
            best_dist = dist
            best_idx = i
          }
        }
        if best_idx >= 0 {
          let (hp, dist) = alive_enemies[best_idx]
          let new_hp = hp - tower_damage
          if new_hp <= 0.0 {
            // Remove by swap-last
            alive_enemies[best_idx] = alive_enemies[alive_enemies.length() - 1]
            let _ = alive_enemies.pop()
            wave_kills = wave_kills + 1
          } else {
            alive_enemies[best_idx] = (new_hp, dist)
          }
          fire_cooldown = @cmp.maximum(tower_fire_rate.to_int(), 1)
        }
      }
      // Check enemies reaching base
      let mut write = 0
      for read = 0; read < alive_enemies.length(); read = read + 1 {
        let (_, dist) = alive_enemies[read]
        if dist <= 0.0 {
          current_base_hp = current_base_hp - 10.0
        } else {
          if write != read {
            alive_enemies[write] = alive_enemies[read]
          }
          write = write + 1
        }
      }
      while alive_enemies.length() > write {
        let _ = alive_enemies.pop()
      }
      let ratio = current_base_hp / base_hp
      if ratio < closest_call {
        closest_call = ratio
      }
      if current_base_hp <= 0.0 {
        break
      }
    }
    total_kills = total_kills + wave_kills
    if current_base_hp <= 0.0 {
      break
    }
    waves_cleared = waves_cleared + 1
    total_clear_time = total_clear_time + frame
  }
  let m = @dec.Metrics::new()
  m.set("waves_cleared", waves_cleared.to_double())
  m.set("avg_clear_time", if waves_cleared > 0 {
    total_clear_time.to_double() / waves_cleared.to_double()
  } else {
    3000.0
  })
  m.set("base_hp_ratio", current_base_hp / base_hp)
  m.set("closest_call", closest_call)
  m.set("total_kills", total_kills.to_double())
  m
}

fn main {
  println("=== Tower Defense Balance Tuner ===")
  println("")
  let specs : Array[@dec.ParamSpec] = [
    { name: "enemy_base_hp", initial: 30.0, min: 5.0, max: 200.0 },
    { name: "hp_scaling", initial: 0.3, min: 0.05, max: 2.0 },
    { name: "spawn_interval", initial: 20.0, min: 5.0, max: 60.0 },
    { name: "enemies_per_wave", initial: 8.0, min: 3.0, max: 30.0 },
    { name: "tower_damage", initial: 10.0, min: 1.0, max: 50.0 },
    { name: "tower_range", initial: 150.0, min: 50.0, max: 300.0 },
    { name: "tower_fire_rate", initial: 10.0, min: 2.0, max: 30.0 },
  ]
  let targets : Array[@dec.BalanceTarget] = [
    { metric: "waves_cleared", target: 10.0, weight: 2.0 }, // survive all waves
    { metric: "closest_call", target: 0.2, weight: 1.5 }, // exciting close calls
    { metric: "avg_clear_time", target: 500.0, weight: 1.0 },
    { metric: "base_hp_ratio", target: 0.3, weight: 1.0 }, // barely survive
  ]
  let config = { ..@dec.TuneConfig::default(specs, targets), max_generations: 30 }
  let result = @dec.tune(config, simulate_td)
  println("")
  println("=== RESULT ===")
  println("Loss: " + result.loss.to_string())
  let names = @dec.param_names(specs)
  for i = 0; i < names.length(); i = i + 1 {
    println("  " + names[i] + ": " + result.params[i].to_string())
  }
  println("")
  println("Metrics:")
  result.metrics.each(fn(k, v) {
    println("  " + k + ": " + v.to_string())
  })
}
