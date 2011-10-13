(*****************)
(* General types *)
(*****************)

type asn1_class =
  | C_Universal
  | C_Application
  | C_ContextSpecific
  | C_Private

let class_map = [| C_Universal; C_Application;
		   C_ContextSpecific; C_Private |]


type asn1_universal_tag =
  | T_EndOfContents
  | T_Boolean
  | T_Integer
  | T_BitString
  | T_OctetString
  | T_Null
  | T_OId
  | T_ObjectDescriptor
  | T_External
  | T_Real
  | T_Enumerated
  | T_EmbeddedPDV
  | T_UTF8String
  | T_RelativeOId
  | T_Sequence
  | T_Set
  | T_NumericString
  | T_PrintableString
  | T_T61String
  | T_VideoString
  | T_IA5String
  | T_UTCTime
  | T_GeneralizedTime
  | T_GraphicString
  | T_VisibleString
  | T_GeneralString
  | T_UniversalString
  | T_UnspecifiedCharacterString
  | T_BMPString
  | T_Unknown

let universal_tag_map =
  [| T_EndOfContents; T_Boolean; T_Integer; T_BitString; T_OctetString;
     T_Null; T_OId; T_ObjectDescriptor; T_External; T_Real;
     T_Enumerated; T_EmbeddedPDV; T_UTF8String; T_RelativeOId; T_Unknown;
     T_Unknown; T_Sequence; T_Set; T_NumericString; T_PrintableString;
     T_T61String; T_VideoString; T_IA5String; T_UTCTime; T_GeneralizedTime;
     T_GraphicString; T_VisibleString; T_GeneralString; T_UniversalString;
     T_UnspecifiedCharacterString; T_BMPString |]


type asn1_object = {
  a_class : asn1_class;
  a_tag : int;
  a_content : asn1_content;
  a_name : string;
}

and asn1_content =
  | EndOfContents
  | Boolean of bool
  | Integer of Big_int.big_int
  | BitString of int * string
  | Null
  | OId of int list
  | String of (string * bool)       (* bool : isBinary *)
  | Constructed of asn1_object list
  | Unknown of string



(*****************************)
(* Header printing functions *)
(*****************************)

let string_of_class = function
  | C_Universal -> "Universal"
  | C_Application -> "Application"
  | C_ContextSpecific -> "Context Specific"
  | C_Private -> "Private"

let string_of_universal_tag = function
  | T_EndOfContents -> "EOC"
  | T_Boolean -> "Boolean"
  | T_Integer -> "Integer"
  | T_BitString -> "Bit String"
  | T_OctetString -> "Octet String"
  | T_Null -> "Null"
  | T_OId -> "OId"
  | T_ObjectDescriptor -> "Object Descriptor"
  | T_External -> "External"
  | T_Real -> "Real"
  | T_Enumerated -> "Enumerated"
  | T_EmbeddedPDV -> "EmbeddedPDV"
  | T_UTF8String -> "UTF8 String"
  | T_RelativeOId -> "Relative OId"
  | T_Sequence -> "Sequence"
  | T_Set -> "Set"
  | T_NumericString -> "Numeric String"
  | T_PrintableString -> "Printable String"
  | T_T61String -> "T61 String"
  | T_VideoString -> "Video String"
  | T_IA5String -> "IA5 String"
  | T_UTCTime -> "UTC Time"
  | T_GeneralizedTime -> "Generalized Time"
  | T_GraphicString -> "Graphic String"
  | T_VisibleString -> "Visible String"
  | T_GeneralString -> "General String"
  | T_UniversalString -> "Universal String"
  | T_UnspecifiedCharacterString -> "Unspecified Character String"
  | T_BMPString -> "BMP String"
  | T_Unknown -> "Unknown"

let string_of_header_raw c isC t =
  let cstr = match c with
    | C_Universal -> "[UNIVERSAL "
    | C_Private -> "[PRIVATE "
    | C_Application -> "[APPLICATION "
    | C_ContextSpecific -> "[CONTEXT SPE "
  in
  let isCstr = if isC then "] (cons)" else "] (prim)" in
  cstr ^ (string_of_int t) ^ isCstr

let string_of_header_pretty c isC t =
  if c = C_Universal && t >= 0 && t < Array.length universal_tag_map
  then begin
    match universal_tag_map.(t) with
      | T_Unknown -> string_of_header_raw c isC t
      | univ_tag -> string_of_universal_tag univ_tag
  end else string_of_header_raw c isC t  



(******************)
(* Parsing engine *)
(******************)

module Asn1EngineParams = struct
  type parsing_error =
    | InternalMayhem
    | OutOfBounds of string
    | NotImplemented of string
    | IncorrectLength of string
    | NotInNormalForm of string
    | UnknownUniversal of (bool * int)
    | UnexpectedHeader of (asn1_class * bool * int) * (asn1_class * bool * int) option
    | WrongNumberOfObjects of int * int
    | TooManyObjects of (int * int) option
    | TooFewObjects of (int * int) option

  let out_of_bounds_error s = OutOfBounds s

  let string_of_perror = function
    | InternalMayhem -> "Internal mayhem"
    | OutOfBounds s -> "Out of bounds (" ^ s ^ ")"
    | NotImplemented s -> "Not implemented (" ^ s ^  ")"
    | IncorrectLength t -> "Incorrect length for a " ^ t
    | NotInNormalForm t -> t ^ " not in normal form"
    | UnknownUniversal (isC, t) ->
      "Unknown " ^ (if isC then "constructed" else "primitive") ^
	"universal type " ^ (string_of_int t)

    | UnexpectedHeader ((c, isC, t), None) ->
      "Unexpected header " ^ (string_of_header_pretty c isC t)
    | UnexpectedHeader ((c, isC, t), Some (exp_c, exp_isC, exp_t)) ->
      "Unexpected header " ^ (string_of_header_pretty c isC t) ^
	" (" ^ (string_of_header_pretty exp_c exp_isC exp_t) ^
	" expected)"

    | WrongNumberOfObjects (n, exp_n) ->
      "Too many objects (" ^ (string_of_int n) ^ " read; " ^
	(string_of_int exp_n) ^ " expected)"
    | TooManyObjects (Some (n, exp_n)) ->
      "Too many objects (" ^ (string_of_int n) ^ " read; at most " ^
	(string_of_int exp_n) ^ " expected)"
    | TooManyObjects None -> "Too many objects in sequence"
    | TooFewObjects (Some (n, exp_n)) ->
      "Too few objects (" ^ (string_of_int n) ^ " read; at least " ^
	(string_of_int exp_n) ^ " expected)"
    | TooFewObjects None -> "Too few objects in sequence"

  type severity =
    | S_OK
    | S_Benign
    | S_IdempotenceBreaker
    | S_SpecLightlyViolated
    | S_SpecFatallyViolated
    | S_Fatal

  let fatal_severity = S_Fatal

  let string_of_severity = function
    | S_OK -> "OK"
    | S_Benign -> "Benign"
    | S_IdempotenceBreaker -> "IdempotenceBreaker"
    | S_SpecLightlyViolated -> "SpecLightlyViolated"
    | S_SpecFatallyViolated -> "SpecFatallyViolated"
    | S_Fatal -> "Fatal"

  let int_of_severity = function
    | S_OK -> 0
    | S_Benign -> 1
    | S_IdempotenceBreaker -> 2
    | S_SpecLightlyViolated -> 3
    | S_SpecFatallyViolated -> 4
    | S_Fatal -> 5

  let compare_severity x y =
    compare (int_of_severity x) (int_of_severity y)
end

open Asn1EngineParams;;
module Engine = ParsingEngine.ParsingEngine (Asn1EngineParams);;
open Engine;;



(*********************)
(* Parsing functions *)
(*********************)

(* Header *)

let extract_class (x : int) : asn1_class =
  let i = x lsr 6 in
  class_map.(i)

let extract_isConstructed (x : int) : bool =
  let i = (x lsr 5) land 1 in
  i = 1

let extract_shorttype (x : int) : int =
  x land 31

let extract_longtype pstate : int =
  raise (ParsingError (NotImplemented "Long type", S_Fatal, pstate))


let extract_header pstate : (asn1_class * bool * int) =
  let hdr = pop_byte pstate in
  let c = extract_class hdr in
  let isC = extract_isConstructed hdr in
  let t = extract_shorttype hdr in
  if (t < 0x1f)
  then (c, isC, t)
  else (c, isC, extract_longtype pstate)

let extract_length pstate name =
  let first = pop_byte pstate in
  if first land 0x80 = 0
  then go_down pstate name first
  else begin
    let accu = ref 0 in
    for i = 1 to (first land 0x7f) do
      accu := (!accu lsl 8) lor (pop_byte pstate);
    done;
    go_down pstate name !accu
  end

type parse_function = parsing_state -> asn1_content


(* Boolean *)

let der_to_boolean pstate =
  let value = pop_list pstate in
  match value with
    | [] ->
      emit (IncorrectLength "boolean") S_IdempotenceBreaker pstate;
      Boolean false
    | [0] -> Boolean false
    | [255] -> Boolean true
    | v::_ ->
      emit (NotInNormalForm "boolean") S_IdempotenceBreaker pstate;
      Boolean (v <> 0)


(* Integer *)

(* TODO: Put all this shit inside a correct BigNum implementation *)
let bigint_of_intlist l =
  let rec aux accu = function
    | [] -> accu
    | d::r -> aux (Big_int.add_int_big_int d (Big_int.mult_int_big_int 256 accu)) r
  in aux Big_int.zero_big_int l

let der_to_int pstate =
  let l = pop_list pstate in
  let negative = match l with
    | [] ->
      emit (IncorrectLength "integer") S_IdempotenceBreaker pstate;
      false
    | x::y::r when x = 0xff ->
      emit (NotInNormalForm "integer") S_IdempotenceBreaker pstate;
      true
    | x::y::r when (x = 0) && (y land 0x80) = 0 ->
      emit (NotInNormalForm "integer") S_IdempotenceBreaker pstate;
      false
    | x::r -> (x land 0x80) = 0x80
  in
  if negative
  then raise (ParsingError (NotImplemented "Negative integer", S_Fatal, pstate))
  else Integer (bigint_of_intlist l)

(* Null *)

let der_to_null pstate =
  if not (eos pstate)
  then emit (IncorrectLength "null") S_IdempotenceBreaker pstate;
  Null


(* OId *)

let der_to_subid pstate : int =
  let rec aux accu =
    let c = pop_byte pstate in
    let new_accu = (accu lsl 7) lor (c land 0x7f) in
    if c land 0x80 != 0
    then aux new_accu
    else new_accu
  in aux 0

let der_to_oid pstate =
  let rec aux () =
    if eos pstate
    then []
    else begin
      try
	let next = der_to_subid pstate in
	next::(aux ())
      with ParsingError (OutOfBounds _, _, _) ->
	emit (IncorrectLength "null") S_IdempotenceBreaker pstate;
	[]
    end
  in
  OId (aux ())


(* Bit String *)

let der_to_bitstring _type pstate =
  let nBits =
    if eos pstate then begin
      emit (IncorrectLength "null") S_IdempotenceBreaker pstate;
      0
    end else pop_byte pstate
  in
  let content = pop_string pstate in
  (* TODO: Checks on nBits and on the final zeros *)
  BitString (nBits, content)


(* Octet String *)

(* TODO: Add constraints *)
(* In particular, wether the octetstring is binary or not *)
let der_to_octetstring _constraints pstate =
  String (pop_string pstate, true)

let der_to_unknown pstate =
  Unknown (pop_string pstate)


(* Constructed and global function *)

let rec der_to_constructed pstate =
  let rec parse_aux () =
    if eos pstate
    then []
    else
      let next = parse pstate in
      next::(parse_aux ())
  in
  Constructed (parse_aux ())
    
and choose_parse_fun pstate (c : asn1_class) (isC : bool) (t : int) : parse_function =
  match c with
    | C_Universal when t >= 0 && t < Array.length universal_tag_map -> begin
      match (universal_tag_map.(t), isC) with
	| (T_Boolean, false) -> der_to_boolean
	| (T_Integer, false) -> der_to_int
	  
	| (T_EndOfContents, false)
	| (T_Null, false) -> der_to_null
	  
	| ( T_OId, false) -> der_to_oid
	  
	| (T_BitString, false) -> der_to_bitstring None
	  
	| ( T_OctetString, false)
	| ( T_UTF8String, false)
	| ( T_NumericString, false)
	| ( T_PrintableString, false)
	| ( T_T61String, false)
	| ( T_VideoString, false)
	| ( T_IA5String, false)
	| ( T_UTCTime, false)
	| ( T_GeneralizedTime, false)
	| ( T_GraphicString, false)
	| ( T_VisibleString, false)
	| ( T_GeneralString, false)
	| ( T_UniversalString, false)
	| ( T_UnspecifiedCharacterString, false)
	| ( T_BMPString, false) -> der_to_octetstring None
	  
	| (T_Sequence, true)
	| (T_Set, true) -> der_to_constructed
	  
	| (_, false) ->
	  emit (UnknownUniversal (false, t)) S_SpecLightlyViolated pstate;
	  der_to_unknown

	| (_, true) ->
	  emit (UnknownUniversal (true, t)) S_SpecLightlyViolated pstate;
	  der_to_constructed
    end
      
    | C_Universal ->
      emit (UnknownUniversal (isC, t)) S_SpecLightlyViolated pstate;
      if isC then der_to_constructed else der_to_unknown

    | _ -> if isC then der_to_constructed else der_to_unknown
      
and parse pstate : asn1_object =
  let (c, isC, t) = extract_header pstate in
  extract_length pstate (string_of_header_pretty c isC t);
  let parse_fun = choose_parse_fun pstate c isC t in
  let res = {a_class = c; a_tag = t; a_content = parse_fun pstate; a_name = ""} in
  go_up pstate;
  res


let exact_parse ehf orig str : asn1_object =
  let pstate = pstate_of_string ehf orig str in
  let res = parse pstate in
  if not (eos pstate)
  then failwith "Trailing bytes at the end of the string"
  else res




(**************************)
(* Content pretty printer *)
(**************************)

type type_representation =
  | NoType
  | RawType
  | PrettyType
  | NamedType

type data_representation =
  | NoData
  | RawData
  | PrettyData

type print_options = {
  type_repr : type_representation;
  data_repr : data_representation;
  resolver : (int list, string) Hashtbl.t option;
  indent_output : bool;     (* indent output and add eols *)
}


(* Useful func *)

let isConstructed o = match o.a_content with
  | Constructed _ -> true
  | _ -> false


let string_of_bitstring raw nBits s =
  if raw && nBits == 0
  then "[" ^ (string_of_int nBits) ^ "]:" ^ (Common.hexdump s)
  else Common.hexdump s

let string_of_oid diropt oid = match diropt with
  | Some dir when Hashtbl.mem dir oid ->
    Hashtbl.find dir oid
  | _ ->
    String.concat "." (List.map string_of_int oid)


let rec string_of_object indent popts o =

  let type_string = match popts.type_repr with
    | NoType -> []
    | RawType -> [string_of_header_raw o.a_class (isConstructed o) o.a_tag]
    | PrettyType -> [string_of_header_pretty o.a_class (isConstructed o) o.a_tag]
    | NamedType -> [o.a_name]
  in

  let content_string = match popts.data_repr, o.a_content with
    | _, Constructed l -> [string_of_constructed indent popts l]

    | NoData, _
    | _, EndOfContents
    | _, Null -> []

    | _, Boolean true -> ["true"]
    | _, Boolean false -> ["false"]

    (* TODO: I would like it to be in hexa *)
    | _, Integer i -> [Big_int.string_of_big_int i]

    | _, BitString (nBits, s) -> [string_of_bitstring (popts.data_repr = RawData) nBits s]
    | _, OId oid -> [string_of_oid popts.resolver oid]

    | RawData, String (s, _)
    | _, String (s, true)
    | _, Unknown s -> ["[HEX:]" ^ (Common.hexdump s)]  
    | _, String (s, _) -> [s]
  in

  let res = String.concat ": " (type_string@content_string) in
  if popts.indent_output
  then indent ^ res ^ "\n"
 else res

and string_of_constructed indent popts l =
  let newindent = if popts.indent_output
    then indent ^ "  "
    else indent
  in
  let objects = List.map (string_of_object newindent popts) l in
  if popts.indent_output
  then "{\n" ^ (String.concat "" objects) ^ indent ^ "}"
  else "{" ^ (String.concat "; " objects) ^ "}"



(*
(********************)
(* Content DER dump *)
(********************)

(* Header *)

let dump_class c =
  match c with
    | C_Universal -> 0
    | C_Private -> 0x40
    | C_Application -> 0x80
    | C_ContextSpecific -> 0xc0
      
let dump_isConstructed isC =
  if isC then 0x20 else 0
    
let dump_longtype t =
  raisego "Long type not implemented"
    
let dump_header (c : asn1_class) (isC : bool) (t : int) : string =
  let t' = if t < 0x1f then t else 0x1f in
  let h = (dump_class c) lor (dump_isConstructed isC) lor t' in
  let res = String.make 1 (char_of_int h) in
  if t' = 0x1f
  then res ^ dump_longtype t
  else res
    
let dump_length l =
  let rec aux accu lg = match lg with
    | 0 -> accu
    | _ -> aux ((char_of_int (lg land 0xff))::accu) (lg lsr 8)
  in
  
  if l < 0x80
  then String.make 1 (char_of_int l)
  else begin
    let x = aux [] l in
    let prefix = char_of_int ((List.length x) lor 0x80) in
    string_of_charlist (prefix::x)
  end



(* Trivial useful functions *)

let string_of_charlist il =
  let res = String.create (List.length il) in
  let rec aux offset l =
    match l with
      | [] -> res
      | i::r ->
	String.set res offset i;
	aux (offset + 1) r
  in aux 0 il*)



  
(*

(* DER export functions *)
    
let boolean_to_der b =
  if b then "\xff" else "\x00"
    
let int_to_der i =
  raisego "Not implemented yet"
    
let null_to_der = ""
  
let subid_to_charlist id =
  let rec aux x =
    let q = x lsr 7 in
    let c = char_of_int (x land 0x7f) in
    match q with
      | 0 -> [c]
      | _ -> c::(aux q)
  in aux id
  
let oid_to_der idlist =
  let cll = List.map subid_to_charlist idlist in
  string_of_charlist (List.flatten cll)
    
let bitstring_to_der nBits s =
  let prefix = String.make 1 (char_of_int nBits) in
  prefix ^ s



let rec dump (c, t, o) =
  let isC, contents = match o with
    | EndOfContents | Null -> false, null_to_der
    | Boolean b -> false, boolean_to_der b
    | Integer i -> false, int_to_der i
    | BitString (nb, s) -> false, bitstring_to_der nb s
    | OId id -> false, oid_to_der id
    | String s | Unknown s -> false, s
    | Constructed objects -> true, constructed_to_der objects
  in
  let hdr = dump_header c isC t in
  let lg = dump_length (String.length contents) in
  hdr ^ lg ^ contents
    
and constructed_to_der objlist =
  let subdumps = List.map dump objlist in
  String.concat "" subdumps


(* Useful functions *)
    
let decapsulate = function
  | (_, _, Constructed l) -> l
  | _ -> raisego "Cannot decapsulate a primitive type"
    
let encapsulate c t l =
  (c, t, Constructed l)
      
*)
