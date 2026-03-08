// LCG random number generator utilities

pub fn lcg_next(x : Int) -> Int {
  (x * 1103515245 + 12345).land(0x7FFFFFFF)
}

pub fn lcg_uniform(x : Int) -> (Int, Double) {
  let next = lcg_next(x)
  (next, next.to_double() / 2147483647.0)
}

pub fn lcg_randn(x : Int) -> (Int, Double) {
  let (x1, u1_raw) = lcg_uniform(x)
  let (x2, u2) = lcg_uniform(x1)
  let u1 = if u1_raw < 0.001 { 0.001 } else { u1_raw }
  (x2, (-2.0 * @math.ln(u1)).sqrt() * @math.cos(2.0 * @math.PI * u2))
}

fn pow_d(base : Double, exp : Int) -> Double {
  let mut r = 1.0
  for _i = 0; _i < exp; _i = _i + 1 {
    r = r * base
  }
  r
}
