#import "Basic";
#import "String";

Maybe :: struct (T: Type) {
    value: T = ---;
    exists: bool;
}

Doc :: struct { head: *Head; }
Head :: struct { title: Maybe(string); }
Summary :: struct {
    title: Maybe(string);
    ok: bool;
}

Err :: struct { message: string; }
Error :: Maybe(Err);

read_doc :: (url: string) -> result: Doc = .{}, err: Error = .{} {
    if contains(url, "fail") {
        err := Error.{exists = true};
        err.value.message = tprint("Bad read of %", url);
        return err = err;
    }
    result: Doc;
    if contains(url, "head-missing") {
        // Nothing more to add.
    } else {
        result.head = New(Head, allocator=__temporary_allocator);
        if !contains(url, "title-missing") {
            result.head.title.exists = true;
            result.head.title.value = 
                ifx contains(url, "title-empty") tprint("")
                else tprint("Title of %", url);
        }
    }
    return result;
}

build_summary :: (doc: Doc) -> Summary {
    result := Summary.{ok = true};
    if (doc.head != null) {
        result.title = doc.head.title;
    }
    return result;
}

// Sync diff with this comment.

read_and_build_summary :: (url: string) -> Summary {
    doc, err := read_doc(url);
    return ifx err.exists then .{} else build_summary(doc);
}

is_title_non_empty :: (doc: Doc) -> Maybe(bool) {
    if doc.head == null || !doc.head.title.exists {
        return .{exists = false};
    }
    result := Maybe(bool).{exists = true};
    result.value = doc.head.title.value.count > 0;
    return result;
}

read_whether_title_non_empty ::
(url: string) -> result: Maybe(bool), err: Error = .{} {
    result: Maybe(bool) = .{exists = false};
    doc, err := read_doc(url);
    if (!err.exists) {
        non_empty := is_title_non_empty(doc);
        if (non_empty.exists) {
            result = is_title_non_empty(doc);
        }
    }
    return result = result, err = err;
}

main :: () {
    // Loop.
    urls := string.["good", "title-empty", "title-missing", "head-missing", "fail"];
    for url: urls {
        // Reset storage on each pass.
        defer reset_temporary_storage();
        // Summary.
        print("Checking \"https://%/\":\n", url);
        summary := read_and_build_summary(url);
        print("  Summary: %\n", summary);
        title_sure := ifx summary.title.exists summary.title.value else ""
        print("  Title: %\n", title_sure);
        // Has title.
        has_title, err := read_whether_title_non_empty(url);
        has_title_text :=
            ifx err.exists tprint("%", err) else tprint("%", has_title);
        has_title_bool :=
            ifx err.exists false
            else ifx has_title.exists has_title.value
            else false;
        print("  Has title: % vs %\n", has_title_text, has_title_bool);
    }
}
