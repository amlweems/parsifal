open Lwt
open Parsifal
open Asn1PTypes
open X509
open RSAKey
open Getopt

type action = Text | Dump | Subject | Issuer | Serial | CheckSelfSigned

let verbose = ref false
let keep_going = ref false
let action = ref Text

let options = [
  mkopt (Some 'h') "help" Usage "show this help";
  mkopt (Some 'v') "verbose" (Set verbose) "print more info to stderr";
  mkopt (Some 'k') "keep-going" (Set keep_going) "keep working even when errors arise";

  mkopt (Some 't') "text" (TrivialFun (fun () -> action := Text)) "prints the certificates given";
  mkopt (Some 'D') "dump" (TrivialFun (fun () -> action := Dump)) "dumps the certificates given";
  mkopt (Some 'S') "serial" (TrivialFun (fun () -> action := Serial)) "prints the certificates serial number";
  mkopt (Some 's') "subject" (TrivialFun (fun () -> action := Subject)) "prints the certificates subject";
  mkopt (Some 'i') "issuer" (TrivialFun (fun () -> action := Issuer)) "prints the certificates issuer";
  mkopt None "check-selfsigned" (TrivialFun (fun () -> action := CheckSelfSigned)) "checks the signature of a self signed";
]

let getopt_params = {
  default_progname = "test_x509";
  options = options;
  postprocess_funs = [];
}


let handle_input input =
  lwt_parse_certificate input >>= fun certificate ->
  match !action with
    | Serial ->
      print_endline (hexdump certificate.tbsCertificate.serialNumber);
      return ()
    | CheckSelfSigned ->
      let result = match certificate.tbsCertificate_raw,
	certificate.tbsCertificate.subjectPublicKeyInfo.subjectPublicKey,
	certificate.signatureValue
	with
	| m, RSA {p_modulus = n; p_publicExponent = e}, RSASignature (0, s) ->
	  (try Pkcs1.raw_verify 1 m s n e with Pkcs1.PaddingError -> false)
	| _ -> false
      in
      print_endline (string_of_bool (result));
      return ()
    | Subject ->
      print_endline ("[" ^ String.concat ", " (List.map string_of_atv (List.flatten certificate.tbsCertificate.subject)) ^ "]");
      return ()
    | Issuer ->
      print_endline ("[" ^ String.concat ", " (List.map string_of_atv (List.flatten certificate.tbsCertificate.issuer)) ^ "]");
      return ()
    | Dump ->
      print_endline (hexdump (dump_certificate certificate));
      return ()
    | Text ->
      print_endline (print_certificate certificate);
      return ()

let catch_exceptions e =
  if !keep_going
  then begin
    prerr_endline (Printexc.to_string e);
    return ()
  end else fail e

let rec iter_on_names = function
  | [] -> return ()
  | f::r ->
    let t = input_of_filename f >>= handle_input in
    catch (fun () -> t) catch_exceptions >>= fun () ->
    iter_on_names r



let _ =
  let args = parse_args getopt_params Sys.argv in
  let t = match args with
    | [] -> input_of_channel "(stdin)" Lwt_io.stdin >>= handle_input
    | _ -> iter_on_names args
  in
  try
    Lwt_unix.run t;
    exit 0
  with
    | ParsingException (e, h) -> prerr_endline (string_of_exception e h); exit 1
    | e -> prerr_endline (Printexc.to_string e); exit 1