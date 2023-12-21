(** A parser which works with two components: A lexer which splits up the input
    into a sequence of tokens and parser which parses the tokens.

    The parser needs two components, a lexer and a parser. The lexer works on
    streams of characters and produces tokens of type
    [Position.range * Token.t]. The parser consumes tokens of type
    [Position.range * Token.t] and produces the parsed constructs in case of
    success.
*)



module type ANY = Fmlib_std.Interfaces.ANY

(** Generate the parser with a lexer and a token parser.

    The generated parser parses a stream of characters. The lexer is used to
    convert the stream of characters into a stream of tokens of type
    [Position.range * Token.t] which are fed into the token parser.
*)
module Make
        (State: ANY)
        (Token: ANY)
        (Final: ANY)
        (Semantic: ANY)
        (Lex: Interfaces.LEXER with type final = Position.range * Token.t)
        (Parse: Interfaces.FULL_PARSER with
                type state = State.t
            and type token = Position.range * Token.t
            and type expect= string * Indent.expectation option
            and type final = Final.t
            and type semantic = Semantic.t):
sig
    (** The type of tokens is char.
        {[
            type token = string
        ]}

        Type of syntax expectations:
        {[
            type expect = string * Indent.expectation option
        ]}
    *)


    include Interfaces.NORMAL_PARSER
        with type token = string
        and  type final = Final.t
        and  type expect = string * Indent.expectation option
        and  type semantic = Semantic.t
        and  type state = State.t
    (* * @inline *)



    (** {1 Lexer and Parser} *)

    val make: Lex.t -> Parse.t -> t
    (** [make lex parse] Make the parser from a lexer and a parser. *)

    val lex: t -> Lex.t
    (** The lexer part of the parser. *)

    val parse: t -> Parse.t
    (** The parser part of the parser. *)




    (** {1 Position} *)

    val position: t -> Position.t
    (** The current position in the input. *)


    val range: t -> Position.range
    (** The current range in the input; usually the range of the first lookahead
        token. In case of a syntax error this is the unexpected token i.e. the
        token which caused the syntax error.
    *)




    (** {1 Run the Parser} *)

    val run_on_string: string -> t -> t
    (** [run_on_string str p] Run the parser [p] on the string [str]. *)

    val run_on_channel: Stdlib.in_channel -> t -> t
    (** [run_on_channel ch p] Run the parser [p] on the channel [ch]. *)
end
