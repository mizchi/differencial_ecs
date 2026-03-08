// Roguelike Deckbuilder: balance card stats for fair matchups
// Simulate auto-play games between decks, target ~50% win rate, ~15 turns

// Card: attack, defense, cost
struct Card {
  atk : Double
  def : Double
  cost : Int
}

fn simulate_deckbuilder(params : Array[Double], seed : Int) -> @dec.Metrics {
  // params encode 3 card archetypes x 3 stats (atk, def, cost)
  let cards : Array[Card] = [
    // Aggro: high atk, low def
    { atk: params[0], def: params[1], cost: @cmp.maximum(params[2].to_int(), 1) },
    // Control: low atk, high def
    { atk: params[3], def: params[4], cost: @cmp.maximum(params[5].to_int(), 1) },
    // Balanced
    { atk: params[6], def: params[7], cost: @cmp.maximum(params[8].to_int(), 1) },
  ]
  let n_games = 6 // 3 matchups x 2 sides
  let mut total_turns = 0
  let wins : Array[Int] = [0, 0, 0] // per archetype
  let games_played : Array[Int] = [0, 0, 0]
  let mut rng = (seed * 31 + 17).land(0x7FFFFFFF)
  for i = 0; i < 3; i = i + 1 {
    for j = i + 1; j < 3; j = j + 1 {
      // Play i vs j
      for side = 0; side < 2; side = side + 1 {
        let (p1_card, p2_card) = if side == 0 { (i, j) } else { (j, i) }
        let mut hp1 = 30.0
        let mut hp2 = 30.0
        let mut mana1 = 0
        let mut mana2 = 0
        let mut turns = 0
        while hp1 > 0.0 && hp2 > 0.0 && turns < 30 {
          turns = turns + 1
          mana1 = mana1 + @cmp.minimum(turns, 10)
          mana2 = mana2 + @cmp.minimum(turns, 10)
          // Player 1 plays cards
          let c1 = cards[p1_card]
          let plays1 = mana1 / @cmp.maximum(c1.cost, 1)
          mana1 = mana1 - plays1 * c1.cost
          rng = (rng * 1103515245 + 12345).land(0x7FFFFFFF)
          let roll1 = rng.to_double() / 2147483647.0
          let dmg1 = @cmp.maximum(plays1.to_double() * c1.atk * (0.8 + roll1 * 0.4) - c1.def * 0.3, 0.0)
          hp2 = hp2 - dmg1
          // Player 2 plays cards
          let c2 = cards[p2_card]
          let plays2 = mana2 / @cmp.maximum(c2.cost, 1)
          mana2 = mana2 - plays2 * c2.cost
          rng = (rng * 1103515245 + 12345).land(0x7FFFFFFF)
          let roll2 = rng.to_double() / 2147483647.0
          let dmg2 = @cmp.maximum(plays2.to_double() * c2.atk * (0.8 + roll2 * 0.4) - c2.def * 0.3, 0.0)
          hp1 = hp1 - dmg2
        }
        total_turns = total_turns + turns
        let p1_idx = if side == 0 { i } else { j }
        let p2_idx = if side == 0 { j } else { i }
        games_played[p1_idx] = games_played[p1_idx] + 1
        games_played[p2_idx] = games_played[p2_idx] + 1
        if hp1 > hp2 {
          wins[p1_idx] = wins[p1_idx] + 1
        } else {
          wins[p2_idx] = wins[p2_idx] + 1
        }
      }
    }
  }
  let m = @dec.Metrics::new()
  m.set("avg_turns", total_turns.to_double() / n_games.to_double())
  // Win rates per archetype
  for i = 0; i < 3; i = i + 1 {
    let wr = if games_played[i] > 0 {
      wins[i].to_double() / games_played[i].to_double()
    } else {
      0.0
    }
    m.set("winrate_" + i.to_string(), wr)
  }
  // Win rate variance (lower = more balanced)
  let mut wr_sum = 0.0
  for i = 0; i < 3; i = i + 1 {
    wr_sum = wr_sum + m.get("winrate_" + i.to_string())
  }
  let wr_mean = wr_sum / 3.0
  let mut wr_var = 0.0
  for i = 0; i < 3; i = i + 1 {
    let d = m.get("winrate_" + i.to_string()) - wr_mean
    wr_var = wr_var + d * d
  }
  m.set("winrate_variance", wr_var / 3.0)
  m
}

fn main {
  println("=== Deckbuilder Balance Tuner ===")
  println("3 archetypes: Aggro, Control, Balanced")
  println("")
  let specs : Array[@dec.ParamSpec] = [
    // Aggro
    { name: "aggro_atk", initial: 5.0, min: 1.0, max: 15.0 },
    { name: "aggro_def", initial: 1.0, min: 0.0, max: 10.0 },
    { name: "aggro_cost", initial: 2.0, min: 1.0, max: 5.0 },
    // Control
    { name: "control_atk", initial: 2.0, min: 1.0, max: 10.0 },
    { name: "control_def", initial: 4.0, min: 0.0, max: 15.0 },
    { name: "control_cost", initial: 3.0, min: 1.0, max: 5.0 },
    // Balanced
    { name: "balanced_atk", initial: 3.0, min: 1.0, max: 12.0 },
    { name: "balanced_def", initial: 3.0, min: 0.0, max: 12.0 },
    { name: "balanced_cost", initial: 2.0, min: 1.0, max: 5.0 },
  ]
  let targets : Array[@dec.BalanceTarget] = [
    { metric: "avg_turns", target: 15.0, weight: 1.0 },
    { metric: "winrate_0", target: 0.5, weight: 2.0 }, // aggro ~50%
    { metric: "winrate_1", target: 0.5, weight: 2.0 }, // control ~50%
    { metric: "winrate_2", target: 0.5, weight: 2.0 }, // balanced ~50%
    { metric: "winrate_variance", target: 0.0, weight: 3.0 }, // minimize variance
  ]
  let config = { ..@dec.TuneConfig::default(specs, targets), max_generations: 30 }
  let result = @dec.tune(config, simulate_deckbuilder)
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
