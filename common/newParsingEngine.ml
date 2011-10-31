(*********)
(* Input *)
(*********)

(* Input interface *)

type input = {
  pop_byte : unit -> int;
  pop_string : int -> string;
  pop_bytes : int -> int list;
  peek_byte : int -> int;
  drop_bytes : int -> unit;
  eos : unit -> bool;

  mk_subinput : input -> int -> input;
}

exception RawOutOfBounds



(* String input *)

let s_pop_byte str offset () =
  try
    let res = str.[!offset] in
    incr offset;
    int_of_char res
  with Invalid_argument _ -> raise RawOutOfBounds

let s_pop_string str offset len =
  try
    let res = String.sub str !offset len in
    offset := !offset + len;
    res
  with Invalid_argument _ -> raise RawOutOfBounds

let s_pop_bytes str offset len =
  let rec aux accu o = function
    | 0 -> List.rev accu
    | n -> aux ((int_of_char str.[o])::accu) (o+1) (n-1)
  in
  try
    let res = aux [] !offset len in
    offset := !offset + len;
    res
  with Invalid_argument _ -> raise RawOutOfBounds

let s_peek_byte str offset off =
  try int_of_char (str.[!offset + off])
  with Invalid_argument _ -> raise RawOutOfBounds

let s_eos str offset () =
  !offset >= String.length str

let s_drop_bytes str offset n = offset := !offset + n

let s_mk_subinput i _ = i

let mk_string_input str initial_offset =
  let offset = ref initial_offset in
  let res = { pop_byte = s_pop_byte str offset;
	      pop_string = s_pop_string str offset;
	      pop_bytes = s_pop_bytes str offset;
	      peek_byte = s_peek_byte str offset;
	      drop_bytes = s_drop_bytes str offset;
	      eos = s_eos str offset;
	      mk_subinput = s_mk_subinput }
  in res



(* Stream input *)

let f_pop_byte str () =
  try int_of_char (Stream.next str)
  with Stream.Failure -> raise RawOutOfBounds

let f_pop_string str len =  
  let res = String.make len ' ' in
  let rec aux o =
    if o < len then begin
      res.[o] <- Stream.next str;
      aux (o+1)
    end else res
  in
  try aux 0 
  with Stream.Failure -> raise RawOutOfBounds

let f_pop_bytes str len =
  let rec aux accu = function
    | 0 -> List.rev accu
    | n ->
      let next_int = int_of_char (Stream.next str) in
      aux (next_int::accu) (n-1)
  in
  try aux [] len
  with Invalid_argument _ -> raise RawOutOfBounds

let f_peek_byte str off =
  let l = Stream.npeek (off + 1) str in
  try int_of_char (List.nth l off)
  with Failure _ -> raise RawOutOfBounds

let f_drop_bytes str off =
  try
    for i = 1 to off do Stream.junk str done
  with Stream.Failure -> raise RawOutOfBounds

let f_eos str () = Common.eos str

let f_mk_subinput str _ l =
  let s = f_pop_string str l in
  mk_string_input s 0

let mk_stream_input str =
  { pop_byte = f_pop_byte str;
    pop_string = f_pop_string str;
    pop_bytes = f_pop_bytes str;
    peek_byte = f_peek_byte str;
    drop_bytes = f_drop_bytes str;
    eos = f_eos str;
    mk_subinput = f_mk_subinput str }




(**************)
(* Severities *)
(**************)

type severity = int

let severities = [| "OK"; "Benign"; "IdempotenceBreaker";
		    "SpecLightlyViolated"; "SpecFatallyViolated";
		    "Fatal" |]
let string_of_severity sev =
  if sev >= 0 && sev < (Array.length severities)
  then severities.(sev)
  else "Wrong severity"

let s_ok = 0
let s_benign = 1
let s_idempotencebreaker = 2
let s_speclightlyviolated = 3
let s_specfatallyviolated = 4
let s_fatal = 5



(*****************)
(* Parsing state *)
(*****************)

type parsing_error = (int * string option)
type parsing_state = {
  ehf : error_handling_function;
  cur_name : string;
  cur_input : input;
  mutable cur_offset : int;
  cur_length : int option;
  history : (string * input * int * int option) list
}
and error_handling_function = parsing_error -> severity -> parsing_state -> unit

exception OutOfBounds of string
exception ParsingError of parsing_error * severity * parsing_state

let mk_pstate ehf n i o l h =
  { ehf = ehf; cur_name = n;
    cur_input = i; cur_offset = o;
    cur_length = l; history = h }

let push_history pstate =
  (pstate.cur_name, pstate.cur_input, pstate.cur_offset, pstate.cur_length)::pstate.history

let string_of_pstate pcontext =
  let string_of_elt (n, _, o, l) = match l with
    | None -> n ^ "[" ^ (string_of_int o) ^ "]"
    | Some len -> n ^ "[" ^ (string_of_int o) ^ "/" ^ (string_of_int len) ^ "]"
  in
  let positions = List.map string_of_elt (push_history pcontext) in
  "{" ^ (String.concat ", " (List.rev positions)) ^ "}"


let string_of_parsing_error title str_of_err err sev pstate =
  title ^ "(" ^ (string_of_severity sev) ^ "): " ^
    (match str_of_err with
      | None -> begin
	match err with
	  | errno, None -> "error " ^ (string_of_int errno)
	  | errno, Some errstring  -> "error " ^ (string_of_int errno) ^ " (" ^ errstring ^ ")"
      end
      | Some string_of_error -> string_of_error err) ^
    " inside " ^ (string_of_pstate pstate)


let default_error_handling_function str_of_err tolerance minDisplay err sev pstate =
  if sev >= tolerance || sev >= s_fatal
  then raise (ParsingError (err, sev, pstate))
  else if minDisplay <= sev
  then output_string stderr (string_of_parsing_error "Warning" str_of_err err sev pstate)




(*************)
(* Functions *)
(*************)

let check_bounds pstate to_be_read =
  match pstate.cur_length with
    | None -> true
    | Some len -> pstate.cur_offset + to_be_read <= len

let emit err sev pstate =  pstate.ehf err sev pstate


let pstate_of_stream ehf orig content =
  mk_pstate ehf orig (mk_stream_input content) 0 None []

let pstate_of_string ehf content =
  mk_pstate ehf "(inline string)" (mk_string_input content 0)
    0 (Some (String.length content)) []

let pstate_of_channel ehf orig content =
  pstate_of_stream ehf orig (Stream.of_channel content)

let go_down pstate name l =
  try
    if not (check_bounds pstate l) then raise RawOutOfBounds;
    let new_input = pstate.cur_input.mk_subinput pstate.cur_input l
    in mk_pstate pstate.ehf name new_input 0 (Some l) (push_history pstate)
  with RawOutOfBounds -> raise (OutOfBounds (string_of_pstate pstate))

let go_up orig_pstate l =
  orig_pstate.cur_offset <- orig_pstate.cur_offset + l

let pop_byte pstate =
  try
    if not (check_bounds pstate 1) then raise RawOutOfBounds;
    let res = pstate.cur_input.pop_byte () in
    pstate.cur_offset <- pstate.cur_offset + 1;
    res
  with RawOutOfBounds -> raise (OutOfBounds (string_of_pstate pstate))

let peek_byte pstate n =
  try
    if not (check_bounds pstate n) then raise RawOutOfBounds;
    pstate.cur_input.peek_byte n
  with RawOutOfBounds -> raise (OutOfBounds (string_of_pstate pstate))

let pop_string pstate =
  try
    match pstate.cur_length with
      | None -> raise RawOutOfBounds
      | Some len -> pstate.cur_input.pop_string (len - pstate.cur_offset)
  with RawOutOfBounds -> raise (OutOfBounds (string_of_pstate pstate))

let pop_bytes pstate n =
  try
    if not (check_bounds pstate n) then raise RawOutOfBounds;
    pstate.cur_input.pop_bytes n
  with RawOutOfBounds -> raise (OutOfBounds (string_of_pstate pstate))

let pop_all_bytes pstate n =
  try
    match pstate.cur_length with
      | None -> raise RawOutOfBounds
      | Some len -> pstate.cur_input.pop_bytes (len - pstate.cur_offset)
  with RawOutOfBounds -> raise (OutOfBounds (string_of_pstate pstate))

let eos pstate = pstate.cur_input.eos ()

let rec extract_uint_aux accu = function
  | i::r -> extract_uint_aux ((accu lsl 8) lor i) r
  | [] -> accu

let extract_uint32 pstate = extract_uint_aux 0 (pop_bytes pstate 4)
let extract_uint24 pstate = extract_uint_aux 0 (pop_bytes pstate 3)
let extract_uint16 pstate = extract_uint_aux 0 (pop_bytes pstate 2)
let extract_uint8 = pop_byte

let extract_string name len pstate =
  let new_pstate = go_down pstate name len in
  let res = pop_string new_pstate in
  go_up pstate len;
  res

let extract_variable_length_string name length_fun pstate =
  let len = length_fun pstate in
  let new_pstate = go_down pstate name len in
  let res = pop_string new_pstate in
  go_up pstate len;
  res
