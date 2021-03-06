
(* This file is free software. See file "license" for more details. *)

(** {1 Very Simple Parser Combinators}

    {[
      open CCParse;;

      type tree = L of int | N of tree * tree;;

      let mk_leaf x = L x
      let mk_node x y = N(x,y)

      let ptree = fix @@ fun self ->
        skip_space *>
        ( (try_ (char '(') *> (pure mk_node <*> self <*> self) <* char ')')
          <|>
          (U.int >|= mk_leaf) )
      ;;

      parse_string_exn ptree "(1 (2 3))" ;;
      parse_string_exn ptree "((1 2) (3 (4 5)))" ;;

    ]}

    {6 Parse a list of words}

    {[
      open Containers.Parse;;
      let p = U.list ~sep:"," U.word;;
      parse_string_exn p "[abc , de, hello ,world  ]";;
    ]}

    {6 Stress Test}
    This makes a list of 100_000 integers, prints it and parses it back.

    {[
      let p = CCParse.(U.list ~sep:"," U.int);;

      let l = CCList.(1 -- 100_000);;
      let l_printed =
        CCFormat.(to_string (within "[" "]" (list ~sep:(return ",@,") int))) l;;

      let l' = CCParse.parse_string_exn p l_printed;;

      assert (l=l');;
    ]}

*)

(*$inject
  module T = struct
    type tree = L of int | N of tree * tree
  end
  open T
  open Result

  let mk_leaf x = L x
  let mk_node x y = N(x,y)

  let ptree = fix @@ fun self ->
    skip_space *>
    ( (try_ (char '(') *> (pure mk_node <*> self <*> self) <* char ')')
      <|>
      (U.int >|= mk_leaf) )

  let ptree' = fix_memo @@ fun self ->
    skip_space *>
    ( (try_ (char '(') *> (pure mk_node <*> self <*> self) <* char ')')
      <|>
      (U.int >|= mk_leaf) )

  let rec pptree = function
    | N (a,b) -> Printf.sprintf "N (%s, %s)" (pptree a) (pptree b)
    | L x -> Printf.sprintf "L %d" x

  let errpptree = function
    | Ok x -> "Ok " ^ pptree x
    | Error s -> "Error " ^ s
*)

(*$= & ~printer:errpptree
  (Ok (N (L 1, N (L 2, L 3)))) \
    (parse_string ptree "(1 (2 3))" )
  (Ok (N (N (L 1, L 2), N (L 3, N (L 4, L 5))))) \
    (parse_string ptree "((1 2) (3 (4 5)))" )
  (Ok (N (L 1, N (L 2, L 3)))) \
    (parse_string ptree' "(1 (2 3))" )
  (Ok (N (N (L 1, L 2), N (L 3, N (L 4, L 5))))) \
    (parse_string ptree' "((1 2) (3 (4 5)))" )
*)

(*$R
  let p = U.list ~sep:"," U.word in
  let printer = function
    | Ok l -> "Ok " ^ CCFormat.(to_string (list string)) l
    | Error s -> "Error " ^ s
  in
  assert_equal ~printer
    (Ok ["abc"; "de"; "hello"; "world"])
    (parse_string p "[abc , de, hello ,world  ]");
*)

(*$R
  let test n =
    let p = CCParse.(U.list ~sep:"," U.int) in

    let l = CCList.(1 -- n) in
    let l_printed =
      CCFormat.(to_string (within "[" "]" (list ~sep:(return ",") int))) l in

    let l' = CCParse.parse_string_exn p l_printed in

    assert_equal ~printer:Q.Print.(list int) l l'
  in
  test 100_000;
  test 400_000;

*)

(*$R
  let open CCParse.Infix in
  let module P = CCParse in

  let parens p = P.try_ (P.char '(') *> p <* P.char ')' in
  let add = P.char '+' *> P.return (+) in
  let sub = P.char '-' *> P.return (-) in
  let mul = P.char '*' *> P.return ( * ) in
  let div = P.char '/' *> P.return ( / ) in
  let integer =
  P.chars1_if (function '0'..'9'->true|_->false) >|= int_of_string in

  let chainl1 e op =
  P.fix (fun r ->
    e >>= fun x -> P.try_ (op <*> P.return x <*> r) <|> P.return x) in

  let expr : int P.t =
  P.fix (fun expr ->
    let factor = parens expr <|> integer in
    let term = chainl1 factor (mul <|> div) in
    chainl1 term (add <|> sub)) in

  assert_equal (Ok 6) (P.parse_string expr "4*1+2");
  assert_equal (Ok 12) (P.parse_string expr "4*(1+2)");
  ()
*)


type 'a or_error = ('a, string) Result.result

type line_num = int
type col_num = int

type parse_branch

val string_of_branch : parse_branch -> string

exception ParseError of parse_branch * (unit -> string)
(** parsing branch * message *)

(** {2 Input} *)

type position

type state

val state_of_string : string -> state

(** {2 Combinators} *)

type 'a t = state -> ok:('a -> unit) -> err:(exn -> unit) -> unit
(** Takes the input and two continuations:
    {ul
      {- [ok] to call with the result when it's done}
      {- [err] to call when the parser met an error}
    }
    @raise ParseError in case of failure *)

val return : 'a -> 'a t
(** Always succeeds, without consuming its input *)

val pure : 'a -> 'a t
(** Synonym to {!return} *)

val (>|=) : 'a t -> ('a -> 'b) -> 'b t
(** Map *)

val map : ('a -> 'b) -> 'a t -> 'b t

val map2 : ('a -> 'b -> 'c) -> 'a t -> 'b t -> 'c t

val map3 : ('a -> 'b -> 'c -> 'd) -> 'a t -> 'b t -> 'c t -> 'd t

val (>>=) : 'a t -> ('a -> 'b t) -> 'b t
(** Monadic bind *)

val (<*>) : ('a -> 'b) t -> 'a t -> 'b t
(** Applicative *)

val (<* ) : 'a t -> _ t -> 'a t
(** [a <* b] parses [a] into [x], parses [b] and ignores its result,
    and returns [x] *)

val ( *>) : _ t -> 'a t -> 'a t
(** [a *> b] parses [a], then parses [b] into [x], and returns [x]. The
    results of [a] is ignored. *)

val fail : string -> 'a t
(** [fail msg] fails with the given message. It can trigger a backtrack *)

val failf: ('a, unit, string, 'b t) format4 -> 'a
(** [Format.sprintf] version of {!fail} *)

val parsing : string -> 'a t -> 'a t
(** [parsing s p] behaves the same as [p], with the information that
    we are parsing [s], if [p] fails *)

val eoi : unit t
(** Expect the end of input, fails otherwise *)

val nop : unit t
(** Succeed with [()] *)

val char : char -> char t
(** [char c] parses the char [c] and nothing else *)

val char_if : (char -> bool) -> char t
(** [char_if f] parses a character [c] if [f c = true] *)

val chars_if : (char -> bool) -> string t
(** [chars_if f] parses a string of chars that satisfy [f] *)

val chars1_if : (char -> bool) -> string t
(** Same as {!chars_if}, but only non-empty strings *)

val endline : char t
(** Parses '\n' *)

val space : char t
(** Tab or space *)

val white : char t
(** Tab or space or newline *)

val skip_chars : (char -> bool) -> unit t
(** Skip 0 or more chars satisfying the predicate *)

val skip_space : unit t
(** Skip ' ' and '\t' *)

val skip_white : unit t
(** Skip ' ' and '\t' and '\n' *)

val is_alpha : char -> bool
(** Is the char a letter? *)

val is_num : char -> bool
(** Is the char a digit? *)

val is_alpha_num : char -> bool

val is_space : char -> bool
(** True on ' ' and '\t' *)

val is_white : char -> bool
(** True on ' ' and '\t' and '\n' *)

val (<|>) : 'a t -> 'a t -> 'a t
(** [a <|> b] tries to parse [a], and if [a] fails without
    consuming any input, backtracks and tries
    to parse [b], otherwise it fails as [a].
    See {!try_} to ensure [a] does not consume anything (but it is best
    to avoid wrapping large parsers with {!try_}) *)

val (<?>) : 'a t -> string -> 'a t
(** [a <?> msg] behaves like [a], but if [a] fails without
    consuming any input, it fails with [msg]
    instead. Useful as the last choice in a series of [<|>]:
    [a <|> b <|> c <?> "expected a|b|c"] *)

val try_ : 'a t -> 'a t
(** [try_ p] tries to parse like [p], but backtracks if [p] fails.
    Useful in combination with [<|>] *)

val suspend : (unit -> 'a t) -> 'a t
(** [suspend f] is  the same as [f ()], but evaluates [f ()] only
    when needed *)

val string : string -> string t
(** [string s] parses exactly the string [s], and nothing else *)

val many : 'a t -> 'a list t
(** [many p] parses a list of [p], eagerly (as long as possible) *)

val many1 : 'a t -> 'a list t
(** parses a non empty list *)

val skip : _ t -> unit t
(** [skip p] parses zero or more times [p] and ignores its result *)

val sep : by:_ t -> 'a t -> 'a list t
(** [sep ~by p] parses a list of [p] separated by [by] *)

val sep1 : by:_ t -> 'a t -> 'a list t
(** [sep1 ~by p] parses a non empty list of [p], separated by [by] *)


val fix : ('a t -> 'a t) -> 'a t
(** Fixpoint combinator *)

val memo : 'a t -> 'a t
(** Memoize the parser. [memo p] will behave like [p], but when called
    in a state (read: position in input) it has already processed, [memo p]
    returns a result directly. The implementation uses an underlying
    hashtable.
    This can be costly in memory, but improve the run time a lot if there
    is a lot of backtracking involving [p].

    This function is not thread-safe. *)

val fix_memo : ('a t -> 'a t) -> 'a t
(** Same as {!fix}, but the fixpoint is memoized. *)

val get_lnum : int t
(** Reflects the current line number *)

val get_cnum : int t
(** Reflects the current column number *)

val get_pos : (int * int) t
(** Reflects the current (line, column) numbers *)

(** {2 Parse}

    Those functions have a label [~p] on the parser, since 0.14.
*)

val parse : 'a t -> state -> 'a or_error
(** [parse p st] applies [p] on the input, and returns [Ok x] if
    [p] succeeds with [x], or [Error s] otherwise *)

val parse_exn : 'a t -> state -> 'a
(** Unsafe version of {!parse}
    @raise ParseError if it fails *)

val parse_string : 'a t -> string -> 'a or_error
(** Specialization of {!parse} for string inputs *)

val parse_string_exn : 'a t -> string -> 'a
(**  @raise ParseError if it fails *)

val parse_file : 'a t -> string -> 'a or_error
(** [parse_file p file] parses [file] with [p] by opening the file
    and reading it whole. *)

val parse_file_exn : 'a t -> string -> 'a
(** @raise ParseError if it fails *)

(** {2 Infix} *)

module Infix : sig
  val (>|=) : 'a t -> ('a -> 'b) -> 'b t
  val (>>=) : 'a t -> ('a -> 'b t) -> 'b t
  val (<*>) : ('a -> 'b) t -> 'a t -> 'b t
  val (<* ) : 'a t -> _ t -> 'a t
  val ( *>) : _ t -> 'a t -> 'a t
  val (<|>) : 'a t -> 'a t -> 'a t
  val (<?>) : 'a t -> string -> 'a t
end

(** {2 Utils}

    This is useful to parse OCaml-like values in a simple way. *)

module U : sig
  val list : ?start:string -> ?stop:string -> ?sep:string -> 'a t -> 'a list t
  (** [list p] parses a list of [p], with the OCaml conventions for
      start token "[", stop token "]" and separator ";".
      Whitespace between items are skipped *)

  val int : int t

  val word : string t
  (** non empty string of alpha num, start with alpha *)

  val pair : ?start:string -> ?stop:string -> ?sep:string ->
    'a t -> 'b t -> ('a * 'b) t
  (** Parse a pair using OCaml whitespace conventions.
      The default is "(a, b)". *)

  val triple : ?start:string -> ?stop:string -> ?sep:string ->
    'a t -> 'b t -> 'c t -> ('a * 'b * 'c) t
  (** Parse a triple using OCaml whitespace conventions.
      The default is "(a, b, c)". *)
end
