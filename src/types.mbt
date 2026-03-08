// Core types for game-agnostic balance optimization

/// Simulation result: flexible key-value metrics
pub struct Metrics(Map[String, Double])

/// Get a metric value, defaulting to 0.0 if not found
pub fn Metrics::get(self : Metrics, key : String) -> Double {
  match self.inner().get(key) {
    Some(v) => v
    None => 0.0
  }
}

/// Set a metric value
pub fn Metrics::set(self : Metrics, key : String, value : Double) -> Unit {
  self.inner().set(key, value)
}

/// Create empty metrics
pub fn Metrics::new() -> Metrics {
  Metrics(Map::new())
}

/// Iterate over all metric entries
pub fn Metrics::each(self : Metrics, f : (String, Double) -> Unit) -> Unit {
  self.inner().each(f)
}

/// Average multiple metrics maps (per-key averaging)
pub fn average_metrics(all : Array[Metrics]) -> Metrics {
  if all.length() == 0 {
    return Metrics::new()
  }
  let result : Map[String, Double] = Map::new()
  let n = all.length().to_double()
  for m in all {
    m.each(fn(k, v) {
      match result.get(k) {
        Some(prev) => result.set(k, prev + v)
        None => result.set(k, v)
      }
    })
  }
  let keys : Array[String] = []
  result.each(fn(k, _) { keys.push(k) })
  for k in keys {
    match result.get(k) {
      Some(v) => result.set(k, v / n)
      None => ()
    }
  }
  Metrics(result)
}

/// A single optimization target: metric name, target value, weight
pub(all) struct BalanceTarget {
  metric : String
  target : Double
  weight : Double
}

/// Parameter specification: name, initial value, min, max
pub(all) struct ParamSpec {
  name : String
  initial : Double
  min : Double
  max : Double
}

/// Clamp params array according to specs
pub fn clamp_params(
  params : Array[Double],
  specs : Array[ParamSpec],
) -> Array[Double] {
  let result = params.copy()
  for i = 0; i < specs.length() && i < result.length(); i = i + 1 {
    let s = specs[i]
    if result[i] < s.min {
      result[i] = s.min
    } else if result[i] > s.max {
      result[i] = s.max
    }
  }
  result
}

/// Extract initial values from param specs
pub fn initial_params(specs : Array[ParamSpec]) -> Array[Double] {
  specs.map(fn(s) { s.initial })
}

/// Extract param names from specs
pub fn param_names(specs : Array[ParamSpec]) -> Array[String] {
  specs.map(fn(s) { s.name })
}

/// Result of a tuning run
pub(all) struct TuneResult {
  params : Array[Double]
  loss : Double
  generation : Int
  metrics : Metrics
}
