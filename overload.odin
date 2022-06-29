package main

import "core:fmt"

A :: struct {}
B :: struct {}

say_aa :: proc(a1, a2: A) {
	fmt.printf("aa\n")
}

say_ab :: proc(a: A, b: B) {
	fmt.printf("ab\n")
}

say_ba :: proc(b: B, a: A) {
	fmt.printf("ba\n")
}

say_bb :: proc(b1, b2: B) {
	fmt.printf("bb\n")
}

say :: proc{say_aa, say_ab, say_ba, say_bb};

say_swaps :: proc(x: $X, y: $Y) {
	say(x, y)
	say(y, x)
}

main :: proc() {
	a: A
	b: B
	say(a, b)
	say_swaps(a, b)
}
