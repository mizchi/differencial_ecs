// Hack-and-slash balance tuner example
// This demonstrates how to integrate differencial_ecs with a real game.
//
// In a real project, you would:
// 1. Import your game package
// 2. Define ParamSpecs matching your BalanceParams
// 3. Write a SimFn that creates a game world, runs N frames, and returns Metrics
//
// See: github.com/mizchi/kagura/examples/hacknslash_3d/src/balance/

fn simulate_hacknslash(params : Array[Double], seed : Int) -> @dec.Metrics {
  // Simplified hack-and-slash simulation
  let player_speed = params[0]
  let enemy_speed = params[1]
  let enemy_hp = params[2]
  let attack_damage = params[3]
  let spawn_rate = params[4]
  let max_frames = 3000
  let mut player_hp = 100.0
  let mut kills = 0
  let mut frame = 0
  let mut rng = (seed * 31 + 17).land(0x7FFFFFFF)
  let enemies : Array[(Double, Double)] = [] // (hp, distance)
  let mut total_hp_samples = 0.0
  let mut hp_sample_count = 0
  while frame < max_frames && player_hp > 0.0 {
    frame = frame + 1
    // Spawn enemies
    if frame % @cmp.maximum(spawn_rate.to_int(), 1) == 0 {
      rng = (rng * 1103515245 + 12345).land(0x7FFFFFFF)
      let dist = 100.0 + (rng % 100).to_double()
      enemies.push((enemy_hp, dist))
    }
    // Move enemies
    for i = 0; i < enemies.length(); i = i + 1 {
      let (hp, dist) = enemies[i]
      enemies[i] = (hp, dist - enemy_speed)
    }
    // Player attacks nearest
    if enemies.length() > 0 {
      let mut nearest = 0
      for i = 1; i < enemies.length(); i = i + 1 {
        if enemies[i].1 < enemies[nearest].1 {
          nearest = i
        }
      }
      let (hp, dist) = enemies[nearest]
      let new_hp = hp - attack_damage
      if new_hp <= 0.0 {
        enemies[nearest] = enemies[enemies.length() - 1]
        let _ = enemies.pop()
        kills = kills + 1
      } else {
        enemies[nearest] = (new_hp, dist)
      }
    }
    // Enemies deal damage at close range
    let mut write = 0
    for read = 0; read < enemies.length(); read = read + 1 {
      let (_, dist) = enemies[read]
      if dist <= player_speed {
        player_hp = player_hp - 5.0
      } else {
        if write != read {
          enemies[write] = enemies[read]
        }
        write = write + 1
      }
    }
    while enemies.length() > write {
      let _ = enemies.pop()
    }
    // Sample HP
    if frame % 30 == 0 {
      total_hp_samples = total_hp_samples + player_hp / 100.0
      hp_sample_count = hp_sample_count + 1
    }
  }
  let m = @dec.Metrics::new()
  m.set("survival_frames", frame.to_double())
  m.set("total_kills", kills.to_double())
  m.set("avg_hp_ratio", if hp_sample_count > 0 {
    total_hp_samples / hp_sample_count.to_double()
  } else {
    0.0
  })
  m.set("kills_per_100f", if frame > 0 {
    kills.to_double() / frame.to_double() * 100.0
  } else {
    0.0
  })
  m
}

fn main {
  println("=== Hack-and-Slash Balance Tuner ===")
  println("")
  let specs : Array[@dec.ParamSpec] = [
    { name: "player_speed", initial: 2.0, min: 0.5, max: 5.0 },
    { name: "enemy_speed", initial: 1.0, min: 0.2, max: 3.0 },
    { name: "enemy_hp", initial: 20.0, min: 5.0, max: 100.0 },
    { name: "attack_damage", initial: 5.0, min: 1.0, max: 30.0 },
    { name: "spawn_rate", initial: 30.0, min: 5.0, max: 120.0 },
  ]
  let targets : Array[@dec.BalanceTarget] = [
    { metric: "survival_frames", target: 3000.0, weight: 1.0 },
    { metric: "avg_hp_ratio", target: 0.5, weight: 1.5 },
    { metric: "kills_per_100f", target: 3.0, weight: 1.0 },
  ]
  let config = { ..@dec.TuneConfig::default(specs, targets), max_generations: 30 }
  let result = @dec.tune(config, simulate_hacknslash)
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
