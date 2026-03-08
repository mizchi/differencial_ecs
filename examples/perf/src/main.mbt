// Performance benchmark: CMA-ES scaling by dimension
// Measures per-dimension wall-clock time using platform-specific clock

fn sphere(params : Array[Double], _seed : Int) -> @dec.Metrics {
  let mut sum = 0.0
  for x in params {
    sum = sum + x * x
  }
  let m = @dec.Metrics::new()
  m.set("value", sum)
  m
}

fn make_specs(n : Int) -> Array[@dec.ParamSpec] {
  let specs : Array[@dec.ParamSpec] = []
  for i = 0; i < n; i = i + 1 {
    specs.push({ name: "x" + i.to_string(), initial: 3.0, min: -5.12, max: 5.12 })
  }
  specs
}

fn run_timed(n : Int, gens : Int) -> Unit {
  let specs = make_specs(n)
  let targets : Array[@dec.BalanceTarget] = [
    { metric: "value", target: 0.0, weight: 1.0 },
  ]
  let config = {
    ..@dec.TuneConfig::default(specs, targets),
    max_generations: gens,
    seeds: [0],
    log_interval: 0,
  }
  let pop_size = 4 + (3.0 * @math.ln(n.to_double())).to_int()
  let total_evals = pop_size * gens
  let t0 = now_ms()
  let result = @dec.tune(config, sphere)
  let t1 = now_ms()
  let elapsed = t1 - t0
  let loss_str = if result.loss < 1.0e-10 { "<1e-10" } else {
    let v = result.loss
    v.to_int().to_string()
  }
  let ms_per_gen = if gens > 0 {
    elapsed.to_double() / gens.to_double()
  } else {
    0.0
  }
  let n_str = pad_l(n.to_string(), 5)
  let gens_str = pad_l(gens.to_string(), 5)
  let pop_str = pad_l(pop_size.to_string(), 4)
  let eval_str = pad_l(total_evals.to_string(), 7)
  let time_str = pad_l(elapsed.to_string(), 8)
  let mpg = fmt2(ms_per_gen)
  println(
    n_str + " | " + gens_str + " | " + pop_str + " | " +
    eval_str + " | " + time_str + "ms | " + pad_l(mpg, 8) + "ms/gen | loss=" + loss_str,
  )
}

fn pad_l(s : String, w : Int) -> String {
  let mut r = s
  while r.length() < w {
    r = " " + r
  }
  r
}

fn fmt2(v : Double) -> String {
  let sign = if v < 0.0 { "-" } else { "" }
  let abs_v = if v < 0.0 { -v } else { v }
  let int_part = abs_v.to_int()
  let frac = ((abs_v - int_part.to_double()) * 100.0).to_int()
  let p = if frac < 10 { "0" + frac.to_string() } else { frac.to_string() }
  sign + int_part.to_string() + "." + p
}

fn main {
  println("╔══════════════════════════════════════════════════════════════════════╗")
  println("║  CMA-ES Performance Scaling (Sphere, 1 seed)                        ║")
  println("╚══════════════════════════════════════════════════════════════════════╝")
  println("")
  println("    n |  gens |  pop |   evals |     time |   ms/gen | result")
  println("  ─── | ──── | ─── | ────── | ─────── | ─────── | ──────")
  run_timed(5, 100)
  run_timed(10, 100)
  run_timed(20, 100)
  run_timed(30, 100)
  run_timed(50, 100)
  run_timed(70, 100)
  run_timed(100, 100)
  println("")
  println("Complexity per generation:")
  println("  Eigendecomp (Jacobi): O(n^2) rotations × O(n) updates = O(n^3) per rotation sweep")
  println("                        max_iter = 100*n^2 → worst case O(n^5)")
  println("  Population sampling:  O(pop × n^2)")
  println("  Covariance update:    O(mu × n^2)")
  println("  The eigendecomp dominates for n > ~30")
  println("")
  println("Acceleration opportunities:")
  println("  n<30:  Already fast. No acceleration needed.")
  println("  n>50:  Metal compute shaders for eigendecomp + population eval")
  println("  n>100: BLAS/Accelerate framework for matrix ops (Apple silicon)")
  println("         Or: switch to Cholesky-based CMA-ES (avoids full eigendecomp)")
}
