// Native: use C clock via stub
fn now_ms() -> Int {
  clock_ms_native()
}

extern "C" fn clock_ms_native() -> Int = "clock_ms_native"
