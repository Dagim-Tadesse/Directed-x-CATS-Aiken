test strxy() {
  trace @"comparing strings "
  let x = "coca"
  let y = "fanta"
  trace @"fanta,coca"
  let xy = x == y
  xy
}

test strxz() {
  let x = "coca"
  let z = "coca"
  trace @"coca,coca"
  let xz = x == z
  xz
}
