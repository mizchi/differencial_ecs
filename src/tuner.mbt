// High-level tuner: runs CMA-ES optimization loop

/// Configuration for a tuning run
pub(all) struct TuneConfig {
  param_specs : Array[ParamSpec]
  targets : Array[BalanceTarget]
  seeds : Array[Int]
  max_generations : Int
  sigma : Double
  rng_seed : Int
  /// Log interval: print progress every N generations (0 = no logging)
  log_interval : Int
}

pub fn TuneConfig::default(
  param_specs : Array[ParamSpec],
  targets : Array[BalanceTarget],
) -> TuneConfig {
  {
    param_specs,
    targets,
    seeds: [42, 137, 256, 512],
    max_generations: 40,
    sigma: 0.3,
    rng_seed: 42,
    log_interval: 10,
  }
}

/// Run CMA-ES optimization
pub fn tune(
  config : TuneConfig,
  sim : (Array[Double], Int) -> Metrics,
) -> TuneResult {
  let initial = initial_params(config.param_specs)
  let cma = @optimizer.CmaEs::new(initial, config.sigma, seed=config.rng_seed)
  // Evaluate baseline
  let (base_loss, _) = compute_loss_averaged(sim, initial, config.targets, config.seeds)
  cma.best_loss = base_loss
  for i = 0; i < cma.n; i = i + 1 {
    cma.best_params[i] = initial[i]
  }
  for gen = 0; gen < config.max_generations; gen = gen + 1 {
    let population = cma.sample_population()
    let fitnesses : Array[(Double, Int)] = []
    for i, candidate in population {
      let clamped = clamp_params(candidate, config.param_specs)
      let (loss, _) = compute_loss_averaged(sim, clamped, config.targets, config.seeds)
      fitnesses.push((loss, i))
    }
    fitnesses.sort_by(fn(a, b) { a.0.compare(b.0) })
    let sorted_pop : Array[Array[Double]] = []
    for entry in fitnesses {
      sorted_pop.push(population[entry.1])
    }
    cma.update(sorted_pop)
    let gen_best = fitnesses[0].0
    if gen_best < cma.best_loss {
      cma.best_loss = gen_best
      let best_arr = sorted_pop[0]
      for i = 0; i < cma.n; i = i + 1 {
        cma.best_params[i] = best_arr[i]
      }
    }
    if config.log_interval > 0 &&
       ((gen + 1) % config.log_interval == 0 || gen == 0 || gen == config.max_generations - 1) {
      println(
        "[Gen " + (gen + 1).to_string() + "/" + config.max_generations.to_string() +
        "] best=" + fmt_f(cma.best_loss) + " sigma=" + fmt_f(cma.sigma),
      )
    }
  }
  let best = clamp_params(cma.best_result(), config.param_specs)
  let (final_loss, final_metrics) = compute_loss_averaged(
    sim, best, config.targets, config.seeds,
  )
  { params: best, loss: final_loss, generation: cma.generation, metrics: final_metrics }
}

fn fmt_f(v : Double) -> String {
  let sign = if v < 0.0 { "-" } else { "" }
  let abs_v = if v < 0.0 { -v } else { v }
  let int_part = abs_v.to_int()
  let frac = ((abs_v - int_part.to_double()) * 10000.0).to_int()
  let s = frac.to_string()
  let p = if frac < 10 {
    "000" + s
  } else if frac < 100 {
    "00" + s
  } else if frac < 1000 {
    "0" + s
  } else {
    s
  }
  sign + int_part.to_string() + "." + p
}
