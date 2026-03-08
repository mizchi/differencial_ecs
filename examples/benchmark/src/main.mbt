// CMA-ES Benchmark: Standard optimization test functions
// Validates the implementation against known problems from Hansen's tutorial
// Reference: Hansen, N. (2016) "The CMA Evolution Strategy: A Tutorial" arXiv:1604.00772

// ============================================================
// Benchmark functions
// All have known global minimum = 0 at specified points
// ============================================================

// Sphere: f(x) = sum(x_i^2), optimum at origin
// Tests: basic convergence, step-size adaptation
fn sphere(params : Array[Double], _seed : Int) -> @dec.Metrics {
  let mut sum = 0.0
  for x in params {
    sum = sum + x * x
  }
  let m = @dec.Metrics::new()
  m.set("value", sum)
  m
}

// Rosenbrock: f(x) = sum(100*(x_{i+1} - x_i^2)^2 + (1-x_i)^2)
// Optimum at (1,1,...,1)
// Tests: narrow curved valley, non-separable, ill-conditioned
fn rosenbrock(params : Array[Double], _seed : Int) -> @dec.Metrics {
  let mut sum = 0.0
  for i = 0; i < params.length() - 1; i = i + 1 {
    let xi = params[i]
    let xi1 = params[i + 1]
    sum = sum + 100.0 * (xi1 - xi * xi) * (xi1 - xi * xi) + (1.0 - xi) * (1.0 - xi)
  }
  let m = @dec.Metrics::new()
  m.set("value", sum)
  m
}

// Rastrigin: f(x) = 10n + sum(x_i^2 - 10*cos(2*pi*x_i))
// Optimum at origin, ~10^n local minima
// Tests: multimodality (hardest for CMA-ES without restarts)
fn rastrigin(params : Array[Double], _seed : Int) -> @dec.Metrics {
  let n = params.length()
  let pi = 3.14159265358979323846
  let mut sum = 10.0 * n.to_double()
  for x in params {
    sum = sum + x * x - 10.0 * @math.cos(2.0 * pi * x)
  }
  let m = @dec.Metrics::new()
  m.set("value", sum)
  m
}

// Ackley: 20 + e - 20*exp(-0.2*sqrt(1/n * sum(x_i^2))) - exp(1/n * sum(cos(2*pi*x_i)))
// Optimum at origin
// Tests: nearly flat outer region with narrow deep basin
fn ackley(params : Array[Double], _seed : Int) -> @dec.Metrics {
  let n = params.length().to_double()
  let pi = 3.14159265358979323846
  let mut sum_sq = 0.0
  let mut sum_cos = 0.0
  for x in params {
    sum_sq = sum_sq + x * x
    sum_cos = sum_cos + @math.cos(2.0 * pi * x)
  }
  let val = 20.0 + @math.exp(1.0) - 20.0 * @math.exp(
      -0.2 * (sum_sq / n).sqrt(),
    ) - @math.exp(sum_cos / n)
  let m = @dec.Metrics::new()
  m.set("value", val)
  m
}

// Schwefel: f(x) = 418.9829*n - sum(x_i * sin(sqrt(|x_i|)))
// Optimum at (420.9687,...,420.9687) ≈ 0
// Tests: deceptive, global optimum far from center
fn schwefel(params : Array[Double], _seed : Int) -> @dec.Metrics {
  let n = params.length().to_double()
  let mut sum = 0.0
  for x in params {
    sum = sum + x * @math.sin(x.abs().sqrt())
  }
  let val = 418.9829 * n - sum
  let m = @dec.Metrics::new()
  m.set("value", val)
  m
}

// Griewank: f(x) = 1 + (1/4000)*sum(x_i^2) - prod(cos(x_i/sqrt(i+1)))
// Optimum at origin
// Tests: non-separable interactions, many local minima
fn griewank(params : Array[Double], _seed : Int) -> @dec.Metrics {
  let mut sum = 0.0
  let mut prod = 1.0
  for i, x in params {
    sum = sum + x * x
    prod = prod * @math.cos(x / (i + 1).to_double().sqrt())
  }
  let val = 1.0 + sum / 4000.0 - prod
  let m = @dec.Metrics::new()
  m.set("value", val)
  m
}

// ============================================================
// Run all benchmarks
// ============================================================

fn run_benchmark(
  name : String,
  sim : (Array[Double], Int) -> @dec.Metrics,
  specs : Array[@dec.ParamSpec],
  max_generations : Int,
  known_optimum : Array[Double],
) -> Unit {
  let targets : Array[@dec.BalanceTarget] = [
    { metric: "value", target: 0.0, weight: 1.0 },
  ]
  let config = {
    ..@dec.TuneConfig::default(specs, targets),
    max_generations,
    seeds: [0], // deterministic benchmarks ignore seed
    log_interval: 0, // suppress per-generation logs
  }
  let result = @dec.tune(config, sim)
  // Compute distance to known optimum
  let mut dist_sq = 0.0
  for i = 0; i < known_optimum.length(); i = i + 1 {
    let d = result.params[i] - known_optimum[i]
    dist_sq = dist_sq + d * d
  }
  let dist = dist_sq.sqrt()
  let status = if result.loss < 1.0e-6 {
    "PASS"
  } else if result.loss < 0.01 {
    "GOOD"
  } else if result.loss < 1.0 {
    "FAIR"
  } else {
    "FAIL"
  }
  println(
    "[" + status + "] " + pad(name, 14) +
    "loss=" + fmt_sci(result.loss) +
    "  dist=" + fmt_sci(dist) +
    "  gens=" + result.generation.to_string(),
  )
  // Print found params vs optimal (first 5 dims max)
  let show_n = @cmp.minimum(5, result.params.length())
  let mut found_str = "  found: ["
  let mut opt_str = "  optimal: ["
  for i = 0; i < show_n; i = i + 1 {
    if i > 0 {
      found_str = found_str + ", "
      opt_str = opt_str + ", "
    }
    found_str = found_str + fmt4(result.params[i])
    opt_str = opt_str + fmt4(known_optimum[i])
  }
  if result.params.length() > show_n {
    found_str = found_str + ", ..."
    opt_str = opt_str + ", ..."
  }
  println(found_str + "]")
  println(opt_str + "]")
  println("")
}

fn make_specs(
  n : Int,
  initial : Double,
  min : Double,
  max : Double,
) -> Array[@dec.ParamSpec] {
  let specs : Array[@dec.ParamSpec] = []
  for i = 0; i < n; i = i + 1 {
    specs.push({ name: "x" + i.to_string(), initial, min, max })
  }
  specs
}

fn main {
  println("╔══════════════════════════════════════════════════════════╗")
  println("║  CMA-ES Benchmark Suite                                 ║")
  println("║  Reference: Hansen (2016) arXiv:1604.00772              ║")
  println("╚══════════════════════════════════════════════════════════╝")
  println("")
  println("Criteria: PASS (<1e-6) | GOOD (<0.01) | FAIR (<1.0) | FAIL")
  println("")

  // --- Sphere (n=10) ---
  // Easy: convex, separable. CMA-ES should PASS easily.
  let n = 10
  println("--- Sphere (n=" + n.to_string() + ") ---")
  println("  f(x) = sum(x_i^2), optimum at origin")
  let opt_sphere = Array::make(n, 0.0)
  run_benchmark(
    "Sphere", sphere, make_specs(n, 3.0, -5.12, 5.12), 100, opt_sphere,
  )

  // --- Rosenbrock (n=5) ---
  // Medium: narrow curved valley, non-separable.
  let n_r = 5
  println("--- Rosenbrock (n=" + n_r.to_string() + ") ---")
  println("  f(x) = sum(100*(x_{i+1}-x_i^2)^2 + (1-x_i)^2), optimum at (1,...,1)")
  let opt_rosen = Array::make(n_r, 1.0)
  run_benchmark(
    "Rosenbrock", rosenbrock, make_specs(n_r, 0.0, -5.0, 10.0), 200, opt_rosen,
  )

  // --- Rosenbrock (n=10) ---
  // Needs ~1000 gens to learn the curved valley in 10D
  let n_r2 = 10
  println("--- Rosenbrock (n=" + n_r2.to_string() + ") ---")
  let opt_rosen2 = Array::make(n_r2, 1.0)
  run_benchmark(
    "Rosenbrock", rosenbrock, make_specs(n_r2, 0.0, -5.0, 10.0), 1000, opt_rosen2,
  )

  // --- Rastrigin (n=5) ---
  // Hard: ~10^5 local minima. CMA-ES gets trapped even at 3000 gens.
  // Needs IPOP-CMA-ES (restart strategy) to escape local optima.
  let n_ra = 5
  println("--- Rastrigin (n=" + n_ra.to_string() + ") ---")
  println("  f(x) = 10n + sum(x_i^2 - 10*cos(2*pi*x_i)), optimum at origin")
  let opt_rast = Array::make(n_ra, 0.0)
  run_benchmark(
    "Rastrigin", rastrigin, make_specs(n_ra, 2.0, -5.12, 5.12), 300, opt_rast,
  )

  // --- Ackley (n=10) ---
  // 500 gens achieves PASS
  let n_a = 10
  println("--- Ackley (n=" + n_a.to_string() + ") ---")
  println("  Nearly flat outer region, narrow optimal basin at origin")
  let opt_ackley = Array::make(n_a, 0.0)
  run_benchmark(
    "Ackley", ackley, make_specs(n_a, 5.0, -32.768, 32.768), 500, opt_ackley,
  )

  // --- Schwefel (n=5) ---
  // Hard: deceptive. Stuck at local optimum ~203.8 even at 3000 gens.
  // Global optimum at ~420.97 is too far from initial guess.
  let n_s = 5
  println("--- Schwefel (n=" + n_s.to_string() + ") ---")
  println("  f(x) = 418.98n - sum(x_i*sin(sqrt(|x_i|))), optimum at ~420.97")
  let opt_schw = Array::make(n_s, 420.9687)
  run_benchmark(
    "Schwefel", schwefel, make_specs(n_s, 200.0, -500.0, 500.0), 300, opt_schw,
  )

  // --- Griewank (n=10) ---
  // GOOD but x2 stuck at local optimum ~-4.44. Does not improve with more gens.
  let n_g = 10
  println("--- Griewank (n=" + n_g.to_string() + ") ---")
  println("  f(x) = 1 + sum(x_i^2)/4000 - prod(cos(x_i/sqrt(i+1)))")
  let opt_gri = Array::make(n_g, 0.0)
  run_benchmark(
    "Griewank", griewank, make_specs(n_g, 50.0, -600.0, 600.0), 200, opt_gri,
  )

  // Summary
  println("══════════════════════════════════════════════════════════")
  println("Expected results:")
  println("  Sphere:     PASS (convex, separable - trivial for CMA-ES)")
  println("  Rosenbrock: GOOD-PASS (CMA-ES learns valley curvature)")
  println("  Rastrigin:  FAIR-FAIL (multimodal, needs restarts)")
  println("  Ackley:     GOOD-PASS (CMA-ES handles narrow basins)")
  println("  Schwefel:   FAIR-FAIL (deceptive, optimum far from init)")
  println("  Griewank:   GOOD-PASS (easier in higher dimensions)")

  // Performance scaling
  run_perf_benchmarks()
}

fn pad(s : String, width : Int) -> String {
  let mut r = s
  while r.length() < width {
    r = r + " "
  }
  r
}

fn fmt4(v : Double) -> String {
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

fn fmt_sci(v : Double) -> String {
  if v < 1.0e-10 {
    return "<1e-10  "
  }
  if v < 0.0001 {
    // Show as scientific-ish
    let mut val = v
    let mut exp = 0
    while val < 1.0 {
      val = val * 10.0
      exp = exp + 1
    }
    return fmt4(val) + "e-" + exp.to_string() + " "
  }
  let s = fmt4(v)
  let mut r = s
  while r.length() < 10 {
    r = r + " "
  }
  r
}
