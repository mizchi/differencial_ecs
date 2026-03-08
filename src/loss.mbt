// Generic loss computation using Metrics (Map[String, Double])

/// Squared relative error
pub fn sq_err(actual : Double, target : Double) -> Double {
  if target.abs() < 0.001 {
    return actual * actual
  }
  let err = (actual - target) / target
  err * err
}

/// Compute loss from metrics against targets
pub fn compute_loss(metrics : Metrics, targets : Array[BalanceTarget]) -> Double {
  let mut loss = 0.0
  for t in targets {
    let actual = metrics.get(t.metric)
    loss = loss + t.weight * sq_err(actual, t.target)
  }
  loss
}

/// Run multiple seeds, compute averaged loss and metrics
pub fn compute_loss_averaged(
  sim : (Array[Double], Int) -> Metrics,
  params : Array[Double],
  targets : Array[BalanceTarget],
  seeds : Array[Int],
) -> (Double, Metrics) {
  let all_metrics : Array[Metrics] = []
  let mut total_loss = 0.0
  for seed in seeds {
    let m = sim(params, seed)
    total_loss = total_loss + compute_loss(m, targets)
    all_metrics.push(m)
  }
  let avg = average_metrics(all_metrics)
  (total_loss / seeds.length().to_double(), avg)
}
