package main

import "core:fmt"
import "core:strings"

Doc	 :: struct {head: ^Head}
Head	:: struct {title: string}
Summary :: struct {title: string}
Err	 :: struct {message: string}
Error   :: Maybe(Err)

read_doc :: proc(url: string) -> (result: Doc, err: Error) {
	if strings.contains(url, "fail") {
		err = Err {message = fmt.tprint("Bad read of", url)}
		return
	}
	switch {
	case strings.contains(url, "head-missing"): 
		result.head = nil
	case strings.contains(url, "title-missing"), strings.contains(url, "title-empty"): 
		result.head = new_clone(Head{})
	case:
		result.head = new_clone(Head{title = fmt.tprint("Title of", url)})
	}
	return
}

build_summary :: proc(doc: Doc) -> (summary: Summary, err: Error) {
	summary.title = doc.head.title if doc.head != nil else ""
	return
}

// Sync diff with this comment.

read_and_build_summary :: proc(url: string) -> (summary: Summary, err: Error) {
	return build_summary(read_doc(url) or_return)
}

is_title_non_empty :: proc(doc: Doc) -> Maybe(bool) {
	if doc.head == nil {
		return nil
	}
	return doc.head.title != ""
}

read_whether_title_non_empty :: proc(url: string) -> (result: Maybe(bool), err: Error) {
	result = is_title_non_empty(read_doc(url) or_return)
	return
}

main :: proc() {
	// Loop.
	urls := []string{"good", "title-empty", "title-missing", "head-missing", "fail"}
	for url in urls {
		defer free_all(context.temp_allocator) // to keep the same as JAI's behaviour
		// Summary.
		fmt.printf("Checking \"https://%v/\":\n", url)
		summary, _ := read_and_build_summary(url)
		fmt.println("  Summary:", summary)
		fmt.println("  Title:", summary.title)
		// Has title.
		has_title, err := read_whether_title_non_empty(url)
		has_title_text := fmt.tprint(err) if err != nil else fmt.tprint(has_title)
		has_title_bool := err == nil && has_title == true
		fmt.println("  Has title:", has_title_text, "vs", has_title_bool)
	}
}
