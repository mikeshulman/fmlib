open Fmlib_std
open Interfaces


module Make
         (User:        ANY)
         (Final:       ANY)
         (Semantic:    ANY)
=
struct
    module Token =
      struct
        type t = string
      end


    module State = Character_state.Make (User)



    module Expect =
    struct
        type t = string * Indent.violation option
    end


    module Basic =
        Generic.Make
            (Token)
            (State)
            (Expect)
            (Semantic)
            (Final)
    include  Basic

    module Parser =
    struct
        module P = Basic.Parser

        type token    = Token.t
        type item     = token
        type final    = Final.t
        type state    = User.t
        type expect   = string * Indent.violation option
        type semantic = Semantic.t

        type t = P.t

        let needs_more          = P.needs_more
        let has_result          = P.has_result
        let has_ended           = P.has_ended
        let has_received_end    = P.has_received_end
        let has_consumed_end    = P.has_consumed_end
        let has_succeeded       = P.has_succeeded
        let has_failed_syntax   = P.has_failed_syntax
        let has_failed_semantic = P.has_failed_semantic
        let final               = P.final
        let failed_expectations = P.failed_expectations
        let failed_semantic     = P.failed_semantic
        let has_lookahead       = P.has_lookahead
        let first_lookahead_token = P.first_lookahead_token
        let fold_lookahead      = P.fold_lookahead
        let lookaheads          = P.lookaheads

        let put                 = P.put
        let put_end             = P.put_end


        let position (p: t): Position.t =
            P.state p |> State.position


        let line (p: t): int =
            P.state p |> State.line


        let column (p: t): int =
            P.state p |> State.column


        let state (p: t): User.t =
            P.state p |> State.user



        let run_on_string  = Run_on.string  needs_more put put_end

        let run_on_channel = Run_on.channel needs_more put put_end
    end







    let expect_error (e: string) (_: State.t): Expect.t =
        e, None
        (*e, State.indent st*)


    let unexpected (e: string): 'a t =
        Basic.( unexpected (e, None) )


    let (<?>) (p: 'a t) (e: string): 'a t =
        Basic.(
            update_expectations
                (fun state -> function
                     | None ->
                         (* end of input reached *)
                         (e, None)
                     | Some _ ->
                         (e, State.check_position state)
                )
                p
        )


    let map_and_update (f: User.t -> 'a -> 'b * User.t) (p: 'a t): 'b t =
        Basic.(
            map_and_update
                (fun state a ->
                     let b, user = f (State.user state) a
                     in
                     b,
                     State.put user state)
                p
        )


    let get: User.t t =
        Basic.(map State.user get)


    let update (f: User.t -> User.t): unit t =
        Basic.update (State.update f)


    let set (user: User.t): unit t =
        update (fun _ -> user)


    let get_and_update (f: User.t -> User.t): User.t t =
        Basic.(
            map
                State.user
                (get_and_update (State.update f))
        )

    let state_around
            (before: User.t -> User.t)
            (p: 'a t)
            (after: User.t -> 'a -> User.t -> User.t)
        : 'a t
        =
        Basic.state_around
            (State.update before)
            p
            (fun s0 a s1 -> State.(update (after (user s0) a) s1))



    let backtrack (p: 'a t) (e: string): 'a t =
        Basic.( backtrack p (e, None) )


    let followed_by (p: 'a t) (e: string): 'a t =
        Basic.( followed_by p (e, None) )


    let not_followed_by (p: 'a t) (e: string): unit t =
        Basic.( not_followed_by p (e, None) )


    let step
        (f: State.t -> string -> ('a, string) result)
        (e: string)
        :
        'a t
        =
        (* Auxiliary function to get a combinator receiving one character.

           The function [f] decides what to do with a character received in a
           certain state.

           [e] is needed to generate an expect message in case that
           we are offside or at the end of input.
        *)
        Basic.step
            (fun state -> function
                | None ->
                    (* end of input reached. *)
                    Error (e, None)

                | Some c ->
                    (match State.check_position state with
                     | None ->
                         (match f state c with
                          | Ok a ->
                              Ok (a, State.next c state)

                          | Error e ->
                              Error (e, None)
                         )
                     | Some vio ->
                         Error (e, Some vio)
                    )
            )



    let position: Position.t t =
        Basic.(map State.position get)



    let located (p: 'a t): 'a Located.t t =
        let* state1 = Basic.get in
        let* a      = p in
        let* state2 = Basic.get in
        return
            (Located.make
                 (State.position state1,
                  State.position state2)
                 a)



    (* Character Combinators *)

    let expect_end (error: string) (a: 'a): 'a t =
        Basic.expect_end (fun _ -> error, None) a


    let uchar (expected: string): string t =
        let error () = String.(one '\'' ^ expected ^ one '\'')
        in
        step
            (fun _ actual ->
                if expected = actual then
                    Ok expected

                else
                    Error (error ())
            )
            (error ())


    let char (expected: char): char t =
        let* str = uchar (String.one expected) in
        return str.[0]


    let ucharp (f: string -> bool) (e: string): string t =
        step
            (fun _ c ->
                 if f c then
                     Ok c
                 else
                     Error e)
            e

    let charp (f: char -> bool) (e: string): char t =
        let* str = ucharp (fun str -> String.length str = 1 && f str.[0]) e in
        return str.[0]



    let range (c1: char) (c2: char): char t =
        charp
            (fun c -> c1 <= c && c <= c2)
            String.("character between '" ^ one c1 ^ "' and '" ^ one c2 ^ "'")


    let uppercase_letter: char t =
        charp
            (fun c -> 'A' <= c && c <= 'Z')
            "uppercase letter"


    let lowercase_letter: char t =
        charp
            (fun c -> 'a' <= c && c <= 'z')
            "lower case letter"


    let letter: char t =
        charp
            (fun c ->
                 ('A' <= c && c <= 'Z')
                 ||
                 ('a' <= c && c <= 'z'))
            "letter"


    let digit_char: char t =
        charp (fun c -> '0' <= c && c <= '9') "digit"


    let digit: int t =
        let* d = digit_char
        in
        return Char.(code d - code '0')


    let uword
            (first: string -> bool)
            (inner: string -> bool)
            (expect: string)
        : string t
        =
        let* c0 = ucharp first expect in
        zero_or_more_fold_left
            c0
            (fun str c -> str ^ c |> return)
            (ucharp inner expect)
        |> no_expectations

    let word
            (first: char -> bool)
            (inner: char -> bool)
            (expect: string)
        : string t
        =
        uword
            (fun c -> String.length c = 1 && first c.[0])
            (fun c -> String.length c = 1 && inner c.[0])
            expect

    let hex_lowercase: int t =
        let* c = range 'a' 'f' in
        return Char.(code c - code 'a' + 10)


    let hex_uppercase: int t =
        let* c = range 'A' 'F' in
        return Char.(code c - code 'A' + 10)

    let hex_digit: int t =
        digit </> hex_lowercase </> hex_uppercase <?> "hex digit"


    let counted
            (min: int)
            (max: int)
            (start: 'r)
            (next: int -> 'item -> 'r -> 'r)
            (p: 'item t)
        : 'r t
        =
        assert (0 <= min);
        assert (min <= max);
        let rec many i r =
            if i = max then
                return r
            else
                let pp =
                    let* a = p in
                    many (i + 1) (next (i + 1) a r)
                in
                if min <= i then
                    pp </> return r
                else
                    pp
        in
        many 0 start



    let base64_char: int t =
        let* i =
            map (fun c -> Char.code c - Char.code 'A') uppercase_letter
            </>
            map (fun c -> Char.code c - Char.code 'a' + 26) lowercase_letter
            </>
            map (fun i -> i + 52) digit
            </>
            map (fun _ -> 62) (char '+')
            </>
            map (fun _ -> 63) (char '/')
            <?>
            "base64 character [A-Za-z0-9+/]"
        in
        let* _ = skip_zero_or_more (char ' ' </> char '\n' </> char '\r')
        in
        return i



    let base64_group: int array t =
        counted 2 4 [||] (fun _ -> Array.push) base64_char


    let base64 (start: string -> 'r) (next: string -> 'r -> 'r): 'r t =
        let _,_ = start, next in
        let start0 arr =
            Base64.decode arr |> start |> return
        and next0  r arr =
            next (Base64.decode arr) r |> return
        in
        let* r = one_or_more_fold_left start0 next0 base64_group in
        let* _ = skip_zero_or_more (char '=') in
        return r



    let string_of_base64: string t =
        base64 Fun.id (fun group str -> str ^ group)



    let string (str: string): string t =
        let len = String.length str in
        let rec parse i =
            if i = len then
                return str
            else
                let* _ = char str.[i] in
                parse (i + 1)
        in
        parse 0


    let one_of_chars (str:string) (e: string): char t =
        let p c = String.has (fun d -> c = d)  0 str
        in
        charp p e




    (* Indentation combinators *)


    let indent (i: int) (p: 'a t): 'a t =
        assert (0 <= i);
        let* state = Basic.get_and_update (State.start_indent i) in
        let* a     = p in
        let* _     = Basic.update (State.end_indent i state) in
        return a


    let align0 (left: bool) (p: 'a t): 'a t =
        let f_align =
            if left then
                State.left_align
            else
                State.align
        in
        Basic.state_around
            f_align
            p
            (fun s0 _ s1 -> State.end_align s0 s1)


    let align (p:'a t): 'a t =
        align0 false p


    let left_align (p:'a t): 'a t =
        align0 true p


    let detach (p: 'a t): 'a t =
        let* state = Basic.get_and_update State.start_detach in
        let* a     = p in
        let* _     = Basic.update (State.end_detach state) in
        return a







    (* Lexer support *)

    let lexer
            (ws:        'a t)
            (end_token: 'tok)
            (tok:      'tok t)
        : (Position.range * 'tok) t
        =
        let* _ = ws in
        located (
            tok
            </>
            expect_end "end of input" end_token
        )







    (* Make the final parser *)

    let make (user: User.t) (p: Final.t t): Parser.t =
        Basic.make
            (State.make Position.start user)
            p
            (expect_error "end of input")


    let make_partial
            (user: User.t)
            (p: Final.t t)
        : Parser.t
        =
        Basic.make_partial
            (State.make Position.start user)
            p
end
