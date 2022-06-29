package main

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

Doc :: struct {head: ^Head}
Head :: struct {title: Maybe(string)}
Summary :: struct {
    title: Maybe(string),
    ok: bool,
}

Err :: struct {message: string}
Error :: Maybe(Err)

read_doc :: proc(url: string) -> (result: Doc, err: Error) {
    if strings.contains(url, "fail") {
        err = Err{message = fmt.aprint("Bad read of", url)}
        return
    }
    result =
        {} if strings.contains(url, "head-missing") else
        {head = new_clone(Head{})} if
            strings.contains(url, "title-missing") else
        {head = new_clone(Head{title = fmt.aprint("")})} if
            strings.contains(url, "title-empty") else
        {head = new_clone(Head{title = fmt.aprint("Title of", url)})}
    return
}

build_summary :: proc(doc: Doc) -> Summary {
    return {
        title = doc.head.title if doc.head != nil else nil,
        ok = true,
    }
}

// Sync diff with this comment.

read_and_build_summary :: proc(url: string) -> Summary {
    if doc, err := read_doc(url); err != nil {
        return {}
    } else {
        return build_summary(doc)
    }
}

is_title_non_empty :: proc(doc: Doc) -> Maybe(bool) {
    if doc.head == nil || doc.head.title == nil {
        return nil
    }
    // return len(doc.head.title.(string)) > 0
    return len(doc.head.title.?) > 0
}

read_whether_title_non_empty ::
proc(url: string) -> (result: Maybe(bool), err: Error) {
    result = is_title_non_empty(read_doc(url) or_return)
    return
}

main :: proc() {
    // Prep arena.
    arena: virtual.Growing_Arena
    defer virtual.growing_arena_destroy(&arena)
    context.allocator = virtual.growing_arena_allocator(&arena)
    // Loop.
    urls := []string{"good", "title-empty", "title-missing", "head-missing", "fail"}
    for url in urls {
        // Reset storage on each pass.
        temp := virtual.growing_arena_temp_begin(&arena)
        defer virtual.growing_arena_temp_end(temp)
        // Summary.
        fmt.printf("Checking \"https://%v/\":\n", url)
        summary := read_and_build_summary(url)
        fmt.println("  Summary:", summary)
        fmt.println("  Title:", summary.title.? or_else "")
        // Has title.
        has_title, err := read_whether_title_non_empty(url)
        has_title_text :=
            fmt.aprint(err) if err != nil else fmt.aprint(has_title)
        has_title_bool := false if err != nil else has_title.? or_else false
        fmt.println("  Has title:", has_title_text, "vs", has_title_bool)
    }
}
