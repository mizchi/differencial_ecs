// JS: Date.now() returns milliseconds
fn now_ms() -> Int {
  js_date_now()
}

extern "js" fn js_date_now() -> Int =
  #| () => Date.now()
