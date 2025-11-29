const x = 4

const y = 8

const z = 20

test compare_xy() {
  trace @"comparing 4,8"
  let xy = x > y
  xy
}

test compare_yx() {
  trace @"comparing 8,4"
  let yx = x < y
  yx
}

test compare_xz() {
  trace @"comparing 4,20"
  let xz = x > x
  xz
}

test compare_yz() {
  trace @"comparing 8,20"
  let yz = y > z
  yz
}

test compare_zx() {
  trace @"comparing 20,4"
  let zx = x < z
  zx
}

test compare_zy() {
  trace @"comparing 20,8"
  let zy = y < z
  zy
}
