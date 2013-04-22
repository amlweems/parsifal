open Parsifal
open BasePTypes
open PTypes


enum rr_type (16, UnknownVal UnknownQueryType) =
  | 1 -> RRT_A, "A"
  | 2 -> RRT_NS, "NS"
  | 3 -> RRT_MD, "MD"
  | 4 -> RRT_MF, "MF"
  | 5 -> RRT_CNAME, "CNAME"
  | 6 -> RRT_SOA, "SOA"
  | 7 -> RRT_MB, "MB"
  | 8 -> RRT_MG, "MG"
  | 9 -> RRT_MR, "MR"
  | 10 -> RRT_NULL, "NULL"
  | 11 -> RRT_WKS, "WKS"
  | 12 -> RRT_PTR, "PTR"
  | 13 -> RRT_HINFO, "HINFO"
  | 14 -> RRT_MINFO, "MINFO"
  | 15 -> RRT_MX, "MX"
  | 252 -> RRT_AXFR, "AXFR"
  | 253 -> RRT_MAILB, "MAILB"
  | 254 -> RRT_MAILA, "MAILA"
  | 255 -> RRT_ANYTYPE, "*"

enum rr_class (16, UnknownVal UnknownQueryClass) =
  | 1 -> RRC_IN, "IN"
  | 2 -> RRC_CS, "CSNET"
  | 3 -> RRC_CH, "CHAOS"
  | 4 -> RRC_HS, "Hesiod"
  | 255 -> RRC_ANYCLASS, "*"


type domain =
  | DomainLabel of string * domain
  | DomainPointer of int
  | DomainEnd


type dns_pcontext = {
  base_offset : int;
  direct_resolver : (int, domain) Hashtbl.t;
}

type dns_dcontext = {
  output_offset : int;
  reverse_resolver : (domain, int) Hashtbl.t;
}

let parse_dns_pcontext input = {
  base_offset = input.cur_base + input.cur_offset;
  direct_resolver = Hashtbl.create 10;
}

let dump_dns_dcontext buf _ = {
  output_offset = Buffer.length buf;
  reverse_resolver = Hashtbl.create 10;
}

let resolve_domains = ref true
let compress_domains = ref true

let rec parse_domain ctx input =
  let o = input.cur_base + input.cur_offset in
  let n = parse_uint8 input in
  match (n land 0xc0), (n land 0x3f) with
  | 0, 0 -> DomainEnd
  | 0xc0, hi_offset ->
    let lo_offset = parse_uint8 input in
    let offset = (hi_offset lsl 8) lor lo_offset in
    let d = DomainPointer offset in
    if should_enrich resolve_domains input.enrich
    then hash_get ctx.direct_resolver offset d
    else d
  | 0, len ->
    let label = parse_string len input in
    let rem = parse_domain ctx input in
    let d = DomainLabel (label, rem) in
    if should_enrich resolve_domains input.enrich
    then Hashtbl.replace ctx.direct_resolver (o - ctx.base_offset) d;
    d
  | _ -> raise (ParsingException (CustomException "Invalid label length", _h_of_si input))

let rec dump_domain ctx buf = function
  | DomainEnd -> dump_uint8 buf 0
  | DomainPointer p -> dump_uint16 buf (0xc000 land p)
  | (DomainLabel (l, r)) as d ->
    if !compress_domains then begin
      try
	dump_domain ctx buf (DomainPointer (Hashtbl.find ctx.reverse_resolver d))
      with Not_found ->
	Hashtbl.replace ctx.reverse_resolver d (Buffer.length buf - ctx.output_offset);
	dump_varlen_string dump_uint8 buf l;
	dump_domain ctx buf r
    end else begin
      dump_varlen_string dump_uint8 buf l;
      dump_domain ctx buf r
    end

let rec string_of_domain = function
  | DomainLabel (s, rem) -> s::(string_of_domain rem)
  | DomainPointer p -> ["@" ^ (string_of_int p)]
  | DomainEnd -> []

let value_of_domain d =
  let content = string_of_domain d in
  VRecord [
    "@name", VString ("domain", false);
    "@string_of", VString (String.concat "." content, false);
    "content", VList (List.map (value_of_string false) content)
  ]


struct mx_rdata [both_param ctx] = {
  mx_preference : uint16;
  mx_host : domain[ctx]
}

(* TODO: Improve value_of *)

union rdata [enrich; both_param ctx] (UnparsedRData) =
  | RRT_A -> Address of ipv4
  | RRT_NS -> Domain of domain[ctx]
  (* | 3 -> RRT_MD, "MD" *)
  (* | 4 -> RRT_MF, "MF" *)
  | RRT_CNAME -> Domain of domain(ctx)
  (* | 6 -> RRT_SOA, "SOA" *)
  (* | 7 -> RRT_MB, "MB" *)
  (* | 8 -> RRT_MG, "MG" *)
  (* | 9 -> RRT_MR, "MR" *)
  (* | 10 -> RRT_NULL, "NULL" *)
  (* | 11 -> RRT_WKS, "WKS" *)
  | RRT_PTR -> Domain of domain[ctx]
  (* | 13 -> RRT_HINFO, "HINFO" *)
  (* | 14 -> RRT_MINFO, "MINFO" *)
  | RRT_MX -> MX of mx_rdata[ctx]



struct question [both_param ctx] = {
  qname : domain[ctx];
  qtype : rr_type;
  qclass : rr_class
}

struct rr [both_param ctx] = {
  rname : domain[ctx];
  rtype : rr_type;
  rclass : rr_class;
  ttl : uint32;
  rdata : container[uint16] of rdata(BOTH ctx; rtype)
}


struct dns_message [with_exact] = {
  parse_checkpoint ctx : dns_pcontext;
  dump_checkpoint ctx : dns_dcontext;
  id : uint16;
  unparsedStuff : uint16;
  qdcount : uint16;
  ancount : uint16;
  nscount : uint16;
  arcount : uint16;
  questions : list(qdcount) of question[ctx];
  answers : list(ancount) of rr[ctx];
  authority_answers : list(nscount) of rr[ctx];
  additional_records : list(arcount) of rr[ctx]
}
