// A simple function that returns true
test hello_world() {
  True
}

// A test with basic math
test basic_math() {
  let x = 5
  let y = 10
  x + y == 15
}

// A test with trace message
test with_trace() {
  trace @"Hello from Aiken!"
  True
}
