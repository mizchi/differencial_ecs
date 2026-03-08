# differencial_ecs

CMA-ES によるゲームバランス自動調整ライブラリ **(experimental)**

ゲームバランス調整のために設計された、純粋な MoonBit による CMA-ES（共分散行列適応進化戦略）の実装。ゲームに限らず、あらゆるブラックボックス最適化に適用可能。

## インストール

```
moon add mizchi/differencial_ecs
```

## クイックスタート

```moonbit
fn simulate(params : Array[Double], seed : Int) -> @dec.Metrics {
  let speed = params[0]
  let hp = params[1]
  // ... シミュレーションを実行 ...
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

## 使い方

### 1. パラメータを定義する

ゲーム内で調整したい数値を `ParamSpec` として列挙する。名前、初期値、最小値、最大値を指定。

```moonbit
let specs : Array[@dec.ParamSpec] = [
  { name: "player_speed",  initial: 2.0,  min: 0.5, max: 5.0 },
  { name: "enemy_hp",      initial: 50.0, min: 10.0, max: 200.0 },
  { name: "spawn_rate",    initial: 30.0, min: 5.0, max: 120.0 },
]
```

### 2. シミュレーション関数を書く

`(Array[Double], Int) -> Metrics` のシグネチャに従い、パラメータ値とシード値を受け取って、計測したいメトリクスを返す。

```moonbit
fn simulate(params : Array[Double], seed : Int) -> @dec.Metrics {
  let player_speed = params[0]
  let enemy_hp = params[1]
  let spawn_rate = params[2]
  // ゲームループを max_frames 分回す
  // ...
  let m = @dec.Metrics::new()
  m.set("survival_frames", 3000.0)
  m.set("kill_rate", 2.5)
  m.set("avg_hp_ratio", 0.6)
  m
}
```

**ポイント:**
- シード値を使って乱数を初期化することで、決定的なシミュレーションを実現
- CMA-ES は複数のシード（デフォルト4つ）で評価を平均化し、ノイズに対してロバストな最適化を行う

### 3. 目標を設定する

どのメトリクスをどの値に近づけたいかを `BalanceTarget` で定義。`weight` が大きいほどそのメトリクスを重視する。

```moonbit
let targets : Array[@dec.BalanceTarget] = [
  { metric: "survival_frames", target: 3000.0, weight: 1.0 },  // 3000フレーム生存
  { metric: "kill_rate",       target: 3.0,    weight: 1.5 },  // 100フレームに3キル
  { metric: "avg_hp_ratio",    target: 0.5,    weight: 1.0 },  // HPは半分前後
]
```

損失関数は各メトリクスの**相対二乗誤差の加重和**：

```
loss = Σ weight_i × ((actual_i - target_i) / target_i)²
```

### 4. 最適化を実行する

```moonbit
let config = { ..@dec.TuneConfig::default(specs, targets), max_generations: 50 }
let result = @dec.tune(config, simulate)
// result.params: 最適化されたパラメータ値
// result.loss: 最終損失値
// result.metrics: 最終メトリクス
```

## CMA-ES が有効なケース

CMA-ES は共分散行列（パラメータ間の相関構造）を適応的に学習する。勾配なしで逆ヘッセ行列を近似するのと等価。

### 得意なケース（このライブラリを使うべき場面）

| ケース | 説明 | 例 |
|---|---|---|
| **非分離問題** | パラメータ同士が相互作用する | 攻撃力と敵HPのバランス |
| **悪条件** | パラメータごとに感度が大きく異なる | 速度(0.5-5) と HP(10-500) の同時調整 |
| **中次元** | 5〜100パラメータ | ゲームバランスの20パラメータ同時調整 |
| **ブラックボックス** | 勾配計算不可 | ゲームループのシミュレーション |
| **ノイズあり** | 評価にばらつきがある | 乱数依存のゲームシミュレーション |

### 苦手なケース

| ケース | 理由 | 対策 |
|---|---|---|
| **多峰性が強い** | 局所最適に陥る | IPOP-CMA-ES（リスタート戦略）が必要 |
| **欺瞞的な構造** | 初期値から最適解が遠い | 初期値の工夫、探索範囲の拡大 |
| **超高次元（200+）** | 共分散行列が O(n²) | 対角 CMA-ES 等を検討 |
| **評価回数が少ない** | 共分散を学習できない | 10n 回以上の評価が必要 |

## ベンチマーク結果

[Hansen (2016) "The CMA Evolution Strategy: A Tutorial"](https://arxiv.org/abs/1604.00772) の標準テスト関数で検証：

| 関数 | 次元 | 結果 | 損失 | 特性 |
|---|---|---|---|---|
| Sphere | 10 | **PASS** | <1e-10 | 凸・分離可能（基本テスト） |
| Rosenbrock | 5 | **PASS** | <1e-10 | 非分離・曲がった谷（CMA-ES の得意領域） |
| Rosenbrock | 10 | FAIR | 0.88 | 高次元で困難に |
| Rastrigin | 5 | FAIL | 99.0 | 多峰性 ~10⁵ 個の局所最適（リスタート必要） |
| Ackley | 10 | **GOOD** | 6.7e-6 | 狭い最適盆地の検出 |
| Schwefel | 5 | FAIL | 1.2M | 欺瞞的（最適解が探索空間の端） |
| Griewank | 10 | **GOOD** | 0.0004 | 非分離な相互作用 |

すべての結果が論文で予測される CMA-ES の挙動と一致。

## 実用例

### ゲームバランス調整（主要ユースケース）

ハクスラゲームで「プレイヤーが3000フレーム生存し、100フレームに3回敵を倒し、HPが半分前後で推移する」ようなバランスを自動的に見つける：

```
examples/hacknslash/   — ハクスラゲームのバランス調整
examples/tower_defense/ — タワーディフェンスのウェーブバランス
examples/deckbuilder/  — カードゲームのアーキタイプバランス（勝率50%を目指す）
examples/sim_game/     — 経済シミュレーション（税率、生産、成長率）
```

### 汎用最適化

ゲーム以外にも、勾配が使えない任意のパラメータ最適化に適用可能：

```
examples/benchmark/    — 標準最適化ベンチマーク（Sphere, Rosenbrock, Rastrigin 等）
```

## API リファレンス

### 型

| 型 | 説明 |
|---|---|
| `Metrics` | シミュレーション結果（`Map[String, Double]` のラッパー） |
| `ParamSpec` | `{ name, initial, min, max }` — パラメータ定義 |
| `BalanceTarget` | `{ metric, target, weight }` — 最適化目標 |
| `TuneConfig` | 設定（specs, targets, seeds, generations, sigma） |
| `TuneResult` | `{ params, loss, generation, metrics }` — 最適化結果 |

### 関数

| 関数 | 説明 |
|---|---|
| `tune(config, sim_fn)` | CMA-ES 最適化を実行、`TuneResult` を返す |
| `TuneConfig::default(specs, targets)` | デフォルト設定で `TuneConfig` を生成 |
| `sq_err(actual, target)` | 相対二乗誤差 |
| `compute_loss(metrics, targets)` | メトリクスから損失を計算 |
| `compute_loss_averaged(sim, params, targets, seeds)` | 複数シードの平均損失 |

### TuneConfig のデフォルト値

| パラメータ | デフォルト | 説明 |
|---|---|---|
| `seeds` | `[42, 137, 256, 512]` | ロバスト性のため4シード |
| `max_generations` | 40 | CMA-ES の世代数 |
| `sigma` | 0.3 | 初期ステップサイズ |
| `rng_seed` | 42 | CMA-ES 内部の乱数シード |
| `log_interval` | 10 | 進捗表示間隔（0で無効） |

## 参考文献

- Hansen, N. (2016). [The CMA Evolution Strategy: A Tutorial](https://arxiv.org/abs/1604.00772). arXiv:1604.00772.
- Hansen, N. & Ostermeier, A. (2001). Completely Derandomized Self-Adaptation in Evolution Strategies. *Evolutionary Computation*, 9(2), 159-195.

## ライセンス

MIT
