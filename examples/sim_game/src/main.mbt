// Economy simulation: balance tax_rate, production, consumption, growth
// Goal: stable population ~1000, GDP growth ~5%, happiness > 0.7

fn simulate_economy(params : Array[Double], seed : Int) -> @dec.Metrics {
  let tax_rate = params[0]
  let prod_mult = params[1]
  let consume_rate = params[2]
  let growth_rate = params[3]
  let mut pop = 500.0
  let mut gdp = 1000.0
  let mut happiness = 0.8
  let mut treasury = 0.0
  let rng_base = seed * 7 + 13
  let turns = 100
  let mut total_pop = 0.0
  let mut total_happiness = 0.0
  let gdp_start = gdp
  for t = 0; t < turns; t = t + 1 {
    // Production
    let production = pop * prod_mult * (1.0 + happiness * 0.5)
    gdp = gdp + production
    // Tax & treasury
    let tax_income = production * tax_rate
    treasury = treasury + tax_income
    // Consumption
    let consumption = pop * consume_rate
    gdp = gdp - consumption
    if gdp < 0.0 {
      gdp = 0.0
    }
    // Happiness: hurt by high taxes, helped by services (treasury spending)
    let services = treasury * 0.3
    treasury = treasury - services
    happiness = happiness + services / (pop + 1.0) * 0.1 - tax_rate * 0.3
    // Noise
    let noise = ((rng_base + t * 31) % 100).to_double() / 1000.0 - 0.05
    happiness = happiness + noise
    if happiness > 1.0 { happiness = 1.0 }
    if happiness < 0.0 { happiness = 0.0 }
    // Population growth (affected by happiness)
    let pop_change = pop * growth_rate * (happiness - 0.3)
    pop = pop + pop_change
    if pop < 10.0 { pop = 10.0 }
    total_pop = total_pop + pop
    total_happiness = total_happiness + happiness
  }
  let m = @dec.Metrics::new()
  m.set("final_population", pop)
  m.set("avg_population", total_pop / turns.to_double())
  m.set("avg_happiness", total_happiness / turns.to_double())
  m.set("final_gdp", gdp)
  m.set("gdp_growth_rate", if gdp_start > 0.0 { (gdp - gdp_start) / gdp_start } else { 0.0 })
  m.set("treasury", treasury)
  m
}

fn main {
  println("=== Economy Simulation Balance Tuner ===")
  println("")
  let specs : Array[@dec.ParamSpec] = [
    { name: "tax_rate", initial: 0.2, min: 0.01, max: 0.8 },
    { name: "production_mult", initial: 2.0, min: 0.5, max: 10.0 },
    { name: "consumption_rate", initial: 1.5, min: 0.1, max: 5.0 },
    { name: "growth_rate", initial: 0.02, min: 0.001, max: 0.1 },
  ]
  let targets : Array[@dec.BalanceTarget] = [
    { metric: "avg_population", target: 1000.0, weight: 1.0 },
    { metric: "avg_happiness", target: 0.7, weight: 2.0 },
    { metric: "gdp_growth_rate", target: 0.05, weight: 1.5 },
    { metric: "treasury", target: 500.0, weight: 0.5 },
  ]
  let config = { ..@dec.TuneConfig::default(specs, targets), max_generations: 30 }
  let result = @dec.tune(config, simulate_economy)
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
