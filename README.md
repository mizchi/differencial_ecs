# differencial_ecs

Game-agnostic parameter optimizer using CMA-ES for balance tuning. **(experimental)**

A pure MoonBit implementation of CMA-ES (Covariance Matrix Adaptation Evolution Strategy) designed for game balance optimization, but applicable to any black-box parameter tuning problem.

## Install

```
moon add mizchi/differencial_ecs
```

## Quick Start

```moonbit
fn simulate(params : Array[Double], seed : Int) -> @dec.Metrics {
  let speed = params[0]
  let hp = params[1]
  // ... run your simulation ...
  let m = @dec.Metrics::new()
  m.set("survival_time", 120.0)
  m.set("kill_rate", 3.5)
  m
}

fn main {
  let specs : Array[@dec.ParamSpec] = [
    { name: "speed", initial: 2.0, min: 0.5, max: 5.0 },
    { name: "hp",    initial: 100.0, min: 10.0, max: 500.0 },
  ]
  let targets : Array[@dec.BalanceTarget] = [
    { metric: "survival_time", target: 180.0, weight: 1.0 },
    { metric: "kill_rate",     target: 5.0,   weight: 1.5 },
  ]
  let config = { ..@dec.TuneConfig::default(specs, targets), max_generations: 50 }
  let result = @dec.tune(config, simulate)
  println("Loss: " + result.loss.to_string())
}
```

## How It Works

1. **Define parameters** (`ParamSpec`): name, initial value, min/max bounds
2. **Write a simulation function**: `(Array[Double], Int) -> Metrics` — takes parameter values and a seed, returns named metrics
3. **Set targets** (`BalanceTarget`): which metrics to optimize, target values, and weights
4. **Call `tune()`**: CMA-ES finds parameters that minimize weighted squared error between actual and target metrics

The optimizer runs your simulation multiple times per generation (across multiple seeds) to find robust parameter settings.

## API

### Types

| Type | Description |
|---|---|
| `Metrics` | `Map[String, Double]` wrapper for simulation results |
| `ParamSpec` | `{ name, initial, min, max }` — parameter definition |
| `BalanceTarget` | `{ metric, target, weight }` — optimization target |
| `TuneConfig` | Full configuration (specs, targets, seeds, generations, sigma) |
| `TuneResult` | `{ params, loss, generation, metrics }` — optimization result |

### Functions

| Function | Signature | Description |
|---|---|---|
| `tune` | `(TuneConfig, sim_fn) -> TuneResult` | Run CMA-ES optimization |
| `TuneConfig::default` | `(specs, targets) -> TuneConfig` | Create config with sensible defaults |
| `sq_err` | `(actual, target) -> Double` | Squared relative error |
| `compute_loss` | `(Metrics, targets) -> Double` | Compute loss from metrics |
| `compute_loss_averaged` | `(sim, params, targets, seeds) -> (Double, Metrics)` | Multi-seed averaged loss |

### TuneConfig Defaults

```
seeds:           [42, 137, 256, 512]  (4 seeds for robustness)
max_generations: 40
sigma:           0.3                  (initial step size)
rng_seed:        42
log_interval:    10                   (0 to disable)
```

## When to Use CMA-ES

CMA-ES adapts a full covariance matrix, learning variable dependencies and landscape curvature — equivalent to approximating the inverse Hessian without gradients.

### Effective (use this library)

- **Non-separable problems**: parameters interact with each other (game balance, physics tuning)
- **Ill-conditioned landscapes**: different parameters have vastly different sensitivities
- **Moderate dimensions**: 5–100 parameters
- **Black-box functions**: no gradient available (simulations, game loops)
- **Noisy evaluations**: multi-seed averaging handles stochastic simulations

### Less effective (consider alternatives)

- **Highly multimodal**: many local minima (Rastrigin-like) — needs restart strategies (IPOP-CMA-ES)
- **Deceptive landscapes**: global optimum far from initial guess (Schwefel-like)
- **Very high dimensions**: >200 parameters — use diagonal CMA-ES or other methods
- **Budget < 10n evaluations**: too few to learn the covariance structure

## Benchmark Results

Validated against standard test functions from [Hansen (2016) "The CMA Evolution Strategy: A Tutorial"](https://arxiv.org/abs/1604.00772):

| Function | n | Result | Loss | Expected |
|---|---|---|---|---|
| Sphere | 10 | **PASS** | <1e-10 | Trivial for CMA-ES |
| Rosenbrock | 5 | **PASS** | <1e-10 | CMA-ES learns valley curvature |
| Rosenbrock | 10 | **PASS** | <1e-10 | Needs ~1000 gens to learn 10D valley |
| Rastrigin | 5 | FAIL | 99.0 | Multimodal — needs restarts |
| Ackley | 10 | **PASS** | 4.4e-8 | Narrow basin detection (500 gens) |
| Schwefel | 5 | FAIL | 1.2M | Deceptive landscape |
| Griewank | 10 | **GOOD** | 0.0004 | Non-separable interactions |

All results match expected CMA-ES behavior from the literature.

## Examples

- `examples/benchmark/` — Standard optimization benchmarks (Sphere, Rosenbrock, Rastrigin, Ackley, Schwefel, Griewank)
- `examples/hacknslash/` — Hack-and-slash game balance (player speed, enemy HP, spawn rate)
- `examples/tower_defense/` — Tower defense wave balancing (enemy scaling, tower stats)
- `examples/deckbuilder/` — Card game archetype balance (3 archetypes, ~50% win rates)
- `examples/sim_game/` — Economy simulation (tax, production, growth)

## Performance

Per-generation wall-clock time (Sphere objective, 1 seed, Apple Silicon):

| n | JS/V8 (ms/gen) | Native release (ms/gen) |
|---|---|---|
| 5 | 0.12 | 0.03 |
| 10 | 0.19 | 0.15 |
| 20 | 0.60 | 1.35 |
| 50 | 13.90 | 32.85 |
| 100 | 193 | 402 |

The bottleneck is Jacobi eigendecomposition (O(n^4) worst case per generation). For n > 30, V8's JIT outperforms native due to hot-loop optimization.

**For game balance tuning (n=5..30), performance is not a concern** — runs complete in under a second. For n > 50, consider Cholesky-based CMA-ES or GPU acceleration (Metal/WGSL compute shaders).

## References

- Hansen, N. (2016). [The CMA Evolution Strategy: A Tutorial](https://arxiv.org/abs/1604.00772). arXiv:1604.00772.
- Hansen, N. & Ostermeier, A. (2001). Completely Derandomized Self-Adaptation in Evolution Strategies. *Evolutionary Computation*, 9(2), 159-195.

## License

MIT
