let get_name answer =
  if String.length answer.AnswerDump.name = 0
  then Common.string_of_ip answer.AnswerDump.ip
  else answer.AnswerDump.name;;


let pstate = AnswerDump.pstate_of_channel "(stdin)" stdin;;

let asn1_ehf = (Asn1.Engine.default_error_handling_function
		  Asn1.Asn1EngineParams.S_SpecFatallyViolated
		  Asn1.Asn1EngineParams.S_SpecFatallyViolated)
let parse_record = TlsParser.parse_record asn1_ehf;;

try
  while not (AnswerDump.Engine.eos pstate) do
    let answer = AnswerDump.parse_answer_record pstate in
    let name = get_name answer in
    Printf.printf "%s:" name;
   try
      let tls_pstate = TlsParser.pstate_of_string (TlsParser.Engine.default_error_handling_function
						     TlsParser.TlsEngineParams.S_Benign
						     TlsParser.TlsEngineParams.S_OK) name answer.AnswerDump.content in
      while not (TlsParser.Engine.eos tls_pstate) do
	try
	  let record = parse_record tls_pstate in begin
	    match record.Tls.content with
	      | Tls.Alert _ | Tls.ChangeCipherSpec _ -> Printf.printf " %s" (Tls.string_of_record_content record.Tls.content)
	      | Tls.ApplicationData _ -> Printf.printf " ApplicationData"
	      | Tls.Handshake hm -> Printf.printf " Handshake (%s)" (Tls.string_of_handshake_msg_type (Tls.type_of_handshake_msg hm))
	      | Tls.UnparsedRecord (ct, _) ->
		TlsParser.Engine.emit (TlsParser.TlsEngineParams.NotImplemented "SSLv2 ?")
		  TlsParser.TlsEngineParams.S_Fatal tls_pstate
	  end;
	with
	  | Asn1.Engine.ParsingError (err, sev, pstate) ->
	    output_string stderr ("Asn1.Error (" ^ (Asn1.Engine.string_of_exception err sev pstate) ^ ")\n");
      done;
      print_newline ();
    with
      | TlsParser.Engine.ParsingError (err, sev, pstate) ->
	print_newline ();
	output_string stderr ("Tls.Error (" ^ (TlsParser.Engine.string_of_exception err sev pstate) ^ ")\n");
  done
with
  | AnswerDump.Engine.ParsingError (err, sev, pstate) ->
    print_newline ();
    output_string stderr ("AnswerDump.Fatal (" ^ (AnswerDump.Engine.string_of_exception err sev pstate) ^ ")\n")
  | Asn1.Engine.ParsingError (err, sev, pstate) ->
    print_newline ();
    output_string stderr ("Asn1.Fatal (" ^ (Asn1.Engine.string_of_exception err sev pstate) ^ ")\n")
  | TlsParser.Engine.ParsingError (err, sev, pstate) ->
    print_newline ();
    output_string stderr ("Tls.Fatal (" ^ (TlsParser.Engine.string_of_exception err sev pstate) ^ ")\n");;
