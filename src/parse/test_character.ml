open Fmlib_std

module CP = Character.Make (Unit) (Char)   (Unit)
module IP = Character.Make (Unit) (Int)    (Unit)
module SP = Character.Make (Unit) (String) (Unit)



(*
One Token
------------------------------------------------------------
*)


let%test _ =
    let open CP in
    let p = Parser.run_on_string "a" (make () letter) in
    Parser.has_succeeded p
    &&
    Parser.column p = 1
    &&
    Parser.final p = 'a'
    &&
    Parser.lookaheads p = ([||], true)


let%test _ =
    let open CP in
    let p = Parser.run_on_string "," (make () letter) in
    Parser.has_failed_syntax p
    &&
    Parser.column p = 0
    &&
    Parser.lookaheads p = ([|","|], false)


let%test _ =
    let open CP in
    let p = Parser.run_on_string "ab" (make () letter) in
    Parser.has_failed_syntax p
    &&
    Parser.column p = 1
    &&
    Parser.lookaheads p = ([|"b"|], false)


let%test _ =
    let open CP in
    let p =
        Parser.run_on_string
            "a" (make () (char 'a' </> char 'b')) in
    Parser.has_succeeded p
    &&
    Parser.final p = 'a'


let%test _ =
    let open CP in
    let p =
        Parser.run_on_string
            "b" (make () (char 'a' </> char 'b')) in
    Parser.has_succeeded p
    &&
    Parser.final p = 'b'


let%test _ =
    let open IP in
    let p =
        Parser.run_on_string
            "F" (make () hex_digit) in
    Parser.(
        has_succeeded p
        &&
        final p = 15)




(*
Backtracking
------------------------------------------------------------
*)

let%test _ =
    let open SP in
    let p =
    Parser.run_on_string
        "(a)" (make () (string "(a)" </> string "(b)"))
    in
    Parser.has_succeeded p
    &&
    Parser.final p = "(a)"


let%test _ =
    let open SP in
    let p =
    Parser.run_on_string
        "(b)" (make () (string "(a)" </> string "(b)"))
    in
    Parser.has_failed_syntax p
    &&
    Parser.column p = 1
    &&
    Parser.failed_expectations p = ["'a'", None]


let%test _ =
    let open SP in
    let p =
    Parser.run_on_string
        "(b)"
        (make
             ()
             (backtrack (string "(a)") "(a)" </> string "(b)"))
    in
    Parser.has_succeeded p
    &&
    Parser.final p = "(b)"




let%test _ =
    let open Character.Make (Unit) (String) (Unit) in
    let p =
        Parser.run_on_string
            "ab"
            (make
                ()
                (string "abc"))
    in
    Parser.(
        let la, la_end = lookaheads p in
        column p = 2
        &&
        has_failed_syntax p
        &&
        Array.is_empty la
        &&
        la_end
        &&
        has_lookahead p
    )



let%test _ =
    let open Character.Make (Unit) (String) (Unit) in
    let p =
        Parser.run_on_string
            "ab"
            (make
                ()
                (backtrack (string "abc") "abc" </> string "ab"))
    in
    Parser.(
        let la, la_end = lookaheads p in
        column p = 2
        &&
        has_succeeded p
        &&
        final p = "ab"
        &&
        Array.is_empty la
        &&
        la_end
        &&
        not (has_lookahead p)
    )




(*
Nested Backtracking
------------------------------------------------------------
*)

let abcdef = SP.(
     backtrack
         (let* s1 = string "abc" in
          let* s2 =
              backtrack (string "def") "def"
              </>
              string "dez"
          in
          return (s1 ^ s2))
         "abcdef"
 )

let%test _ =
    let open SP in
    let p =
    Parser.run_on_string
        "abcdeg"
        (make () abcdef)
    in
    Parser.has_failed_syntax p
    &&
    Parser.column p = 0
    &&
    Parser.failed_expectations p = ["abcdef", None]


let%test _ =
    let open SP in
    let p =
        Parser.run_on_string
            "abcdef"
            (make () abcdef)
    in
    Parser.has_succeeded p
    &&
    Parser.final p = "abcdef"


let%test _ =
    let open SP in
    let p =
        Parser.run_on_string
            "abcdez"
            (make () abcdef)
    in
    Parser.has_succeeded p
    &&
    Parser.final p = "abcdez"




(*
Followed by and not followed by
------------------------------------------------------------
*)

let%test _ =
    (* "abc" followed by "def". Success case. *)
    let open SP in
    let p =
        let* str = string "abc" in
        let* _   = followed_by (string "def") "def" in
        return str
    in
    let p =
        Parser.run_on_string
            "abcdef"
            (make_partial () p)
    in
    Parser.has_succeeded p
    &&
    Parser.final p = "abc"
    &&
    Parser.column p = 3


let%test _ =
    (* "abc" followed by "def". Failure case. *)
    let open SP in
    let p =
        let* str = string "abc" in
        let* _   = followed_by (string "def") "def" in
        return str
    in
    let p =
        Parser.run_on_string
            "abcdez"
            (make_partial () p)
    in
    Parser.has_failed_syntax p
    &&
    Parser.column p = 3
    &&
    Parser.failed_expectations p = ["def", None]



let%test _ =
    (* "abc" not followed by "def". Success case. *)
    let open SP in
    let p =
        let* str = string "abc" in
        let* _   = not_followed_by (string "def") "" in
        return str
    in
    let p =
        Parser.run_on_string
            "abcdez"
            (make_partial () p)
    in
    Parser.has_succeeded p
    &&
    Parser.final p = "abc"
    &&
    Parser.column p = 3



let%test _ =
    (* "abc" not followed by "def". Failure case. *)
    let open SP in
    let p =
        let* str = string "abc" in
        let* _   = not_followed_by (string "def") "def" in
        return str
    in
    let p =
        Parser.run_on_string
            "abcdef"
            (make_partial () p)
    in
    Parser.has_failed_syntax p
    &&
    Parser.column p = 3
    &&
    Parser.failed_expectations p = ["def", None]




(*
Indentation Sensitivity
------------------------------------------------------------
*)

module Indent_sensitive (Final: Fmlib_std.Interfaces.ANY) =
struct
    module Basic = Character.Make (Unit) (Final) (Unit)

    include Basic

    let whitespace: int t =
        char ' ' </> char '\n' <?> "whitespace"
        |> (fun p ->
            skip_zero_or_more p >>= clear_last_expectation)
        |> detach


    let skip_trailing_ws (p: 'a t): 'a t =
        let* a = p in
        let* _ = whitespace in
        return a

    let char_ws (c: char): char t =
        skip_trailing_ws (char c)


    let string_of_expectations (p: Parser.t): string =
        assert (Parser.has_failed_syntax p);
        "["
        ^
        String.concat
            ","
            (List.map
                 (fun (msg,vio) ->
                      let open Indent in
                      "(" ^ msg ^ ", " ^
                      (match vio with
                       | None ->
                          "None"
                       | Some (Indent i) ->
                           "Indent " ^ string_of_int i
                       | Some (Align i) ->
                           "Align " ^ string_of_int i
                       | Some (Align_between (i, j)) ->
                           "Align_between "
                           ^ string_of_int i ^ "," ^ string_of_int j)
                      ^
                      ")")
            (Parser.failed_expectations p))
        ^
        "]"
end


let%test _ =
    (* an indented character *)
    let open Indent_sensitive (Char) in
    let str = {|
        a
            b
        |}
    in
    let p =
        (
            let* _ = whitespace in
            let* _ = char_ws 'a'in
            char_ws 'b' |> indent 4
        )
        |>
        make ()
        |>
        Parser.run_on_string str
    in
    Parser.has_succeeded p
    &&
    Parser.final p = 'b'
    &&
    Parser.column p = 8



let%test _ =
    (* a wrongly indented character *)
    let open Indent_sensitive (Char) in
    let str = {|
   a
   b |}
(* ^ column 3 *)
    in
    let p =
        (
            let* _ = whitespace in
            let* _ = char_ws 'a'in
            char_ws 'b' |> indent 4
        )
        |>
        make ()
        |>
        Parser.run_on_string str
    in
    Parser.has_failed_syntax p
    &&
    Parser.column p = 3



let%test _ =
    (* A character left aligned. *)
    let open Indent_sensitive (Char) in
    let p =
        (let* _ = whitespace in
         char 'a' |> left_align)
        |>
        make ()
        |>
        Parser.run_on_string "   \na"
    in
    Parser.has_succeeded p
    &&
    Parser.final p = 'a'
    &&
    Parser.line p = 1
    &&
    Parser.column p = 1



let%test _ =
    (* A character left aligned, but not found. *)
    let open Indent_sensitive (Char) in
    let p =
        (let* _ = whitespace in
         char 'a' |> left_align)
        |>
        make ()
        |>
        Parser.run_on_string "   \n\n\n\n a"
    in
    Parser.has_failed_syntax p
    &&
    Parser.line p = 4
    &&
    Parser.column p = 1
    &&
    Parser.failed_expectations p =
        ["'a'", Some (Indent.Align 0)]


let%test _ =
    (* Two characters aligned *)
    let open Indent_sensitive (Char) in
    let p =
        (
            let* _ = whitespace in
            let* _ = char_ws 'a' in
            (
                let* _ = char_ws 'b' |> align in
                char_ws 'c' |> align
            )
            |> indent 0
        )
        |> make ()
      |> Parser.run_on_string {|
            a   b
                c
          |}
    in
    Parser.has_succeeded p


let%test _ =
    (* Two characters indented and aligned *)
    let open Indent_sensitive (Char) in
    let p =
        (let* _  = whitespace in
         let* c0 = char_ws 'a' |> align in
         let* _  =
             (
                 let* _ = char_ws 'b' |> align in
                 char_ws 'c' |> align
             )
             |> indent 1
         in
         return c0)
        |> make ()
        |> Parser.run_on_string
               "\n\
                \ a\n\
                \    b\n\
                \    c"
    in
    Parser.has_succeeded p
    &&
    Parser.line p = 3
    &&
    Parser.column p = 5



let%test _ =
    (* Two characters indented and wrongly aligned *)
    let open Indent_sensitive (Char) in
    let p =
        (let* _  = whitespace in
         let* c0 = char_ws 'a' |> align in
         let* _  =
             (
                 let* _ = char_ws 'b' |> align in
                 char_ws 'c' |> align
             )
             |> indent 1
         in
         return c0)
        |> make ()
        |> Parser.run_on_string
               "\n\
                \ a\n\
                \    b\n\
                \     c"
    in
    Parser.has_failed_syntax p
    &&
    Parser.line p = 3
    &&
    Parser.column p = 5
    &&
    Parser.failed_expectations p = ["'c'", Some (Align 4)]




let%test _ =
    (* Alignment without indentation *)
    let str = {|
            a a
            a
        b
        c
            a
        |}
    in
    let open Indent_sensitive (Int) in
    let p =
        (
            let* _  = whitespace  in
            let* n  = char_ws 'a' |> skip_one_or_more in
            let* _  = char_ws 'b' |> align in
            let* _  = char_ws 'c' |> align in
            let* m  = char_ws 'a' |> skip_zero_or_more in
            return (n + m)
        )
        |> make ()
        |> Parser.run_on_string str
    in
    Parser.(
        has_succeeded p
        &&
        final p = 4
    )



let%test _ =
    (* Alignment without indentation, failed *)
    let str = {|
            a a a
                a
             b
             c
    |}
    in
    let open Indent_sensitive (Int) in
    let p =
        (
            let* _  = whitespace  in
            let* n  = char_ws 'a' |> skip_one_or_more in
            let* _  = char_ws 'b' |> align in
            let* _  = char_ws 'c' |> align in
            return n
        )
        |> make ()
        |> Parser.run_on_string str
    in
    Parser.(
        has_failed_syntax p
    )



(*
Base64 decoding
------------------------------------------------------------
*)

let%test _ =
    let open SP in
    let p =
        base64 Fun.id (fun grp s -> s ^ grp)
        |> make ()
        |> Parser.run_on_string "TQ======"
    in
    Parser.has_succeeded p
    &&
    Parser.final p = "M"

let%test _ =
    let open SP in
    let p =
        string_of_base64
        |> make ()
        |> Parser.run_on_string "TWE====="
    in
    Parser.has_succeeded p
    &&
    Parser.final p = "Ma"

let%test _ =
    let open SP in
    let p =
        string_of_base64
        |> make ()
        |> Parser.run_on_string "TWFu"
    in
    Parser.has_succeeded p
    &&
    Parser.final p = "Man"

let%test _ =
    let open SP in
    let p =
        string_of_base64
        |> make ()
        |> Parser.run_on_string "c\n\rGxlY  XN1cmUu"
    in
    Parser.has_succeeded p
    &&
    Parser.final p = "pleasure."

let%test _ =
    let open SP in
    let p =
        string_of_base64
        |> make ()
        |> Parser.run_on_string "c3VyZS4="
    in
    Parser.has_succeeded p
    &&
    Parser.final p = "sure."
