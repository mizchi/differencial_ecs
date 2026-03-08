// Simple (1+lambda)-ES fallback optimizer

pub(all) struct EvolutionState {
  n : Int
  mut generation : Int
  best : Array[Double]
  mut best_loss : Double
  scales : Array[Double]
  mut sigma : Double
  mut rng_x : Int
}

pub fn EvolutionState::new(
  initial : Array[Double],
  sigma : Double,
  seed~ : Int = 42,
) -> EvolutionState {
  let n = initial.length()
  let scales : Array[Double] = []
  for v in initial {
    scales.push(if v.abs() < 0.1 { 1.0 } else { v.abs() })
  }
  {
    n,
    generation: 0,
    best: initial.copy(),
    best_loss: 1.0e20,
    scales,
    sigma,
    rng_x: seed.land(0x7FFFFFFF),
  }
}

pub fn EvolutionState::sample(self : EvolutionState) -> Array[Double] {
  let candidate : Array[Double] = Array::make(self.n, 0.0)
  for i = 0; i < self.n; i = i + 1 {
    let (next, z) = lcg_randn(self.rng_x)
    self.rng_x = next
    candidate[i] = self.best[i] + self.sigma * self.scales[i] * z
  }
  candidate
}

pub fn EvolutionState::sample_population(
  self : EvolutionState,
  pop_size : Int,
) -> Array[Array[Double]] {
  let pop : Array[Array[Double]] = []
  for _k = 0; _k < pop_size; _k = _k + 1 {
    pop.push(self.sample())
  }
  pop
}

pub fn EvolutionState::update(
  self : EvolutionState,
  candidate : Array[Double],
  loss : Double,
) -> Bool {
  self.generation = self.generation + 1
  if loss < self.best_loss {
    for i = 0; i < self.n; i = i + 1 {
      self.best[i] = candidate[i]
    }
    self.best_loss = loss
    self.sigma = self.sigma * 1.1
    if self.sigma > 2.0 {
      self.sigma = 2.0
    }
    return true
  }
  self.sigma = self.sigma * 0.95
  if self.sigma < 0.001 {
    self.sigma = 0.001
  }
  false
}
