(*
    The source extractor extracts from a bytestream the part which contains an
    error and marks it in a readable form.

    Examples:

    1. Error at an exact position displayed with two extra lines

        25 |      xxxx
        26 |
        27 |    line with error
                          ^

    2. Error within a range of a certain line (2 extra lines)

        25 |      xxxx
        26 |
        27 |    line with error
                          ^^^^^

    3. Error within a range of spanning more than one line (2 extra lines)

        25 |      xxxx
        26 |
                          v----------
        27 |    xxx yyy   error start
        28 |      err err err err err
        29 |          err err err
        30 |       err error end zzz
              -----------------^
*)


open Fmlib_pretty

module Pretty = Fmlib_pretty.Print



type t = {
    range: Position.range;      (* range which has to be extracted *)

    extra: int;                 (* number of lines above the range which should
                                   be extracted as well *)
    number_width: int;          (* width of the line numbers *)

    nline: int;                 (* the current line number *)

    line:  string;              (* the current line *)

    doc:   Print.doc;           (* the generated doc *)
}


let of_range
        (extra: int)
        (range: Position.range)
    : t
    =
    (* Make a source extractor which reports [extra] number of lines before the
     * error. *)
    assert (0 <= extra);
    assert (Position.is_valid_range range);
    let number_width =
        (Position.line (snd range) + 1)
        |> string_of_int
        |> String.length
    in
    {
        range;
        extra;
        number_width;
        nline = 0;
        line  = "";
        doc   = Pretty.empty;
    }


let of_position
        (extra: int)
        (pos: Position.t)
    : t
    =
    (* Make a source extractor which reports [extra] number of lines before the
     * error. *)
    of_range extra (pos, pos)




let needs_more (ext: t): bool =
    let _, p2 = ext.range in
    ext.nline <= Position.line p2




let is_in_range (p: t): bool =
    (* Is the current line within the range which should be extracted (i.e.
     * extra lines + error range)? *)
    let open Position in
    let pos1, pos2 = p.range in
    line pos1 <= p.nline + p.extra
    &&
    p.nline <= line pos2



let is_start_line (p: t): bool =
    (* Is the current line the start line of the part which should be extracted?
     *)
    let open Position in
    let pos1, pos2 = p.range in
    p.nline = line pos1
    &&
    line pos1 < line pos2


let is_end_line (p: t): bool =
    (* Is the current line the end line of the part which should be extracted?
     *)
    let open Position in
    let pos1, pos2 = p.range in
    line pos1 < p.nline
    &&
    p.nline = line pos2



let is_one_line (p: t): bool =
    (* Is the current line the only line of the error? *)
    let open Position in
    let pos1, pos2 = p.range in
    p.nline = line pos1
    &&
    line pos1 = line pos2



let source_separator: string =
    " | "





let source_indent (p: t): int =
    p.number_width
    +
    String.length source_separator





let source_line (p: t): Pretty.doc =
    (* The current line nicely formatted i.e. displayed as

        25 |  xxx yyy ... zzz

    *)
    let str =
        p.nline + 1 |> string_of_int
    in
    let n = p.number_width - String.length str
    in
    assert (0 <= n);
    Pretty.(
        fill n ' '
        <+>
        text str
        <+>
        text source_separator
        <+>
        text p.line
        <+>
        cut
    )





let start_line_marker (p: t): Pretty.doc =
    (* A line marker of the form

              v--------

       to mark the start of a multiline error
    *)
    let col = Position.column (fst p.range) in
    Pretty.(
        fill (source_indent p + col) ' '
        <+>
        char 'v'
        <+>
        fill 10 '-'
        <+>
        cut
    )





let end_line_marker (p: t): Pretty.doc =
    (* A line marker of the form

              --------^

       to mark the end of a multiline error
    *)
    let col = Position.column (snd p.range)
    and ind = source_indent p
    in
    Pretty.(
        fill ind ' '
        <+>
        fill (col - ind) '-'
        <+>
        char '^'
        <+>
        cut
    )


let one_line_marker (is_last: bool) (p: t): Pretty.doc =
    (* A line marker of the form

           ^^^^^

       to mark a one line error. If the marker marks a newline or the end of
       input, it is displayed as

          ^ end of line

       or

          ^ end of input

       If the marker marks a nonprintable ascii character it is displayed e.g. as

          ^ nonprintable ascii '\xFA'

       Furthermore end of input and end of line are annotated.
    *)

    let open Position in
    let pos1, pos2 = p.range in
    let c1 = Position.column pos1
    and c2 = Position.column pos2
    in
    assert (line pos1 = line pos2);
    assert (c1 <= c2);
    let len = c2 - c1 in
    let len = max len 1 in
    let open Pretty
    in
    let annotation =
        if len = 1 && c1 < String.length p.line
        then
            let ch = p.line.[c1] in
            if ch < ' ' || Char.chr 126 <= ch then
                text (" nonprintable ascii '" ^ Char.escaped ch ^ "'")
            else
                empty
        else if len = 1 && c1 = String.length p.line then
            if is_last then
                text " end of input"
            else
                text " end of line"
        else
            Pretty.empty
    in
    Pretty.(
        fill (source_indent p + c1) ' '
        <+>
        fill len '^'
        <+>
        annotation
        <+>
        cut
    )


let receive_char (is_last: bool) (c: string) (p: t): t =
    let in_range = is_in_range p
    in
    if c = "\n" then
        let open Pretty in
        let doc =
            if in_range then
                p.doc
                <+>
                if is_start_line p then
                    start_line_marker p <+> source_line p
                else if is_one_line p then
                    source_line p <+> one_line_marker is_last p
                else if is_end_line p then
                    source_line p <+> end_line_marker p
                else
                    source_line p
            else
                p.doc
        in
        {
            p with
            line  = "";
            nline = p.nline + 1;
            doc
        }
    else (* c <> '\n' *)
        {
            p with
            line =
                if in_range then
                    p.line ^ c
                else
                    p.line;
        }




let put: string -> t -> t =
    receive_char false


let put_end: t -> t =
    receive_char true "\n"


let document (p: t): Pretty.doc =
    p.doc


let run_on_string  = Run_on.string  needs_more put put_end

let run_on_channel = Run_on.channel needs_more put put_end
