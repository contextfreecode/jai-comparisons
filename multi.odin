package main

import "core:fmt"

main :: proc() {
	/*
		Here's a comment.
		/*
			And a nested comment.
		*/
	*/
	// Text
	text :: `
		function hello() {
		  console.log("name\tage");   
		}

		hello();
	`
	fmt.println(text)
	// data ::
	// 	"GIF89a\x01\x00\x01\x00\x80\x01\x00\xff\xff\xff\x00" +
	// 	"\x00\x00!\xf9\x04\x01\n\x00\x01\x00,\x00\x00\x00" +
	// 	"\x00\x01\x00\x01\x00\x00\x02\x02L\x01\x00;"
	data :: #load("pixel.png")
	fmt.println(len(data))
}
