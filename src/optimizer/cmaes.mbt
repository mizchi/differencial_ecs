// CMA-ES optimizer with full covariance adaptation
// Game-agnostic: operates on Array[Double] parameters

pub(all) struct CmaEs {
  n : Int
  pop_size : Int
  mu : Int
  mut generation : Int
  mean : Array[Double]
  mut sigma : Double
  scales : Array[Double]
  cov : Array[Double] // n*n row-major covariance
  p_sigma : Array[Double]
  p_c : Array[Double]
  weights : Array[Double]
  mu_eff : Double
  c_sigma : Double
  d_sigma : Double
  c_c : Double
  c1 : Double
  c_mu : Double
  chi_n : Double
  mut best_loss : Double
  best_params : Array[Double]
  mut rng_x : Int
}

pub fn CmaEs::new(
  initial : Array[Double],
  sigma : Double,
  seed~ : Int = 42,
) -> CmaEs {
  let n = initial.length()
  let pop_size = 4 + (3.0 * @math.ln(n.to_double())).to_int()
  let mu = pop_size / 2
  let weights : Array[Double] = []
  let mut sum_w = 0.0
  for i = 0; i < mu; i = i + 1 {
    let w = @math.ln(mu.to_double() + 0.5) - @math.ln((i + 1).to_double())
    weights.push(w)
    sum_w = sum_w + w
  }
  for i = 0; i < mu; i = i + 1 {
    weights[i] = weights[i] / sum_w
  }
  let mut sum_w2 = 0.0
  for w in weights {
    sum_w2 = sum_w2 + w * w
  }
  let mu_eff = 1.0 / sum_w2
  let n_f = n.to_double()
  let c_sigma = (mu_eff + 2.0) / (n_f + mu_eff + 5.0)
  let d_sigma = 1.0 + 2.0 * @cmp.maximum(
      0.0, ((mu_eff - 1.0) / (n_f + 1.0)).sqrt() - 1.0,
    ) + c_sigma
  let c_c = (4.0 + mu_eff / n_f) / (n_f + 4.0 + 2.0 * mu_eff / n_f)
  let c1 = 2.0 / ((n_f + 1.3) * (n_f + 1.3) + mu_eff)
  let c_mu = @cmp.minimum(
    1.0 - c1,
    2.0 * (mu_eff - 2.0 + 1.0 / mu_eff) / ((n_f + 2.0) * (n_f + 2.0) + mu_eff),
  )
  let chi_n = n_f.sqrt() * (1.0 - 1.0 / (4.0 * n_f) + 1.0 / (21.0 * n_f * n_f))
  let scales : Array[Double] = []
  for v in initial {
    scales.push(if v.abs() < 0.1 { 1.0 } else { v.abs() })
  }
  let cov : Array[Double] = Array::make(n * n, 0.0)
  for i = 0; i < n; i = i + 1 {
    cov[i * n + i] = 1.0
  }
  {
    n,
    pop_size,
    mu,
    generation: 0,
    mean: initial.copy(),
    sigma,
    scales,
    cov,
    p_sigma: Array::make(n, 0.0),
    p_c: Array::make(n, 0.0),
    weights,
    mu_eff,
    c_sigma,
    d_sigma,
    c_c,
    c1,
    c_mu,
    chi_n,
    best_loss: 1.0e20,
    best_params: initial.copy(),
    rng_x: seed.land(0x7FFFFFFF),
  }
}

pub fn CmaEs::sample_population(self : CmaEs) -> Array[Array[Double]] {
  let n = self.n
  let (eigvals, eigvecs) = eigen_decompose(self.cov, n)
  let pop : Array[Array[Double]] = []
  for _k = 0; _k < self.pop_size; _k = _k + 1 {
    let z : Array[Double] = Array::make(n, 0.0)
    for i = 0; i < n; i = i + 1 {
      let (next, v) = lcg_randn(self.rng_x)
      self.rng_x = next
      z[i] = v
    }
    let x : Array[Double] = Array::make(n, 0.0)
    for i = 0; i < n; i = i + 1 {
      let mut sum = 0.0
      for j = 0; j < n; j = j + 1 {
        let sqrt_ev = if eigvals[j] > 0.0001 { eigvals[j].sqrt() } else { 0.01 }
        sum = sum + eigvecs[i * n + j] * sqrt_ev * z[j]
      }
      x[i] = self.mean[i] + self.sigma * self.scales[i] * sum
    }
    pop.push(x)
  }
  pop
}

pub fn CmaEs::update(
  self : CmaEs,
  sorted_pop : Array[Array[Double]],
) -> Unit {
  let n = self.n
  let old_mean = self.mean.copy()
  for i = 0; i < n; i = i + 1 {
    let mut sum = 0.0
    for j = 0; j < self.mu; j = j + 1 {
      sum = sum + self.weights[j] * sorted_pop[j][i]
    }
    self.mean[i] = sum
  }
  let md : Array[Double] = Array::make(n, 0.0)
  for i = 0; i < n; i = i + 1 {
    md[i] = (self.mean[i] - old_mean[i]) / (self.sigma * self.scales[i])
  }
  let cs_factor = (self.c_sigma * (2.0 - self.c_sigma) * self.mu_eff).sqrt()
  let mut ps_norm = 0.0
  for i = 0; i < n; i = i + 1 {
    self.p_sigma[i] = (1.0 - self.c_sigma) * self.p_sigma[i] + cs_factor * md[i]
    ps_norm = ps_norm + self.p_sigma[i] * self.p_sigma[i]
  }
  ps_norm = ps_norm.sqrt()
  self.sigma = self.sigma * @math.exp(
    (self.c_sigma / self.d_sigma) * (ps_norm / self.chi_n - 1.0),
  )
  self.sigma = @cmp.maximum(0.001, @cmp.minimum(5.0, self.sigma))
  let gen2 = 2 * (self.generation + 1)
  let decay = 1.0 - pow_d(1.0 - self.c_sigma, gen2)
  let h_sigma = if ps_norm / decay.sqrt() <
    (1.4 + 2.0 / (n.to_double() + 1.0)) * self.chi_n {
    1.0
  } else {
    0.0
  }
  let cc_factor = (self.c_c * (2.0 - self.c_c) * self.mu_eff).sqrt()
  for i = 0; i < n; i = i + 1 {
    self.p_c[i] = (1.0 - self.c_c) * self.p_c[i] + h_sigma * cc_factor * md[i]
  }
  let keep = 1.0 - self.c1 - self.c_mu
  for r = 0; r < n; r = r + 1 {
    for c = r; c < n; c = c + 1 {
      let r1 = self.c1 * self.p_c[r] * self.p_c[c]
      let mut rm = 0.0
      for j = 0; j < self.mu; j = j + 1 {
        let yr = (sorted_pop[j][r] - old_mean[r]) / (self.sigma * self.scales[r])
        let yc = (sorted_pop[j][c] - old_mean[c]) / (self.sigma * self.scales[c])
        rm = rm + self.weights[j] * yr * yc
      }
      let new_val = keep * self.cov[r * n + c] + r1 + self.c_mu * rm
      self.cov[r * n + c] = new_val
      self.cov[c * n + r] = new_val
    }
  }
  self.generation = self.generation + 1
}

pub fn CmaEs::best_result(self : CmaEs) -> Array[Double] {
  self.best_params.copy()
}
