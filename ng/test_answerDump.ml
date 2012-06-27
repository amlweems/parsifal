open ParsingEngine
open AnswerDump
open Tls
open TlsEnums


let dump = "\x6c\x6b\x2e\xf1\x01\xbb\x00\x00\x00\x00\x00\x00\x03\x34\x16\x03"^
  "\x01\x00\x4a\x02\x00\x00\x46\x03\x01\x4c\x57\x55\x7e\xc0\x5e\x00"^
  "\x03\x9c\x8a\x64\xc5\x26\x73\x1a\x1d\xf4\x72\xc5\xff\x79\xc9\x50"^
  "\x40\xb6\xa1\x96\xab\xc8\x86\xef\xed\x20\xe1\x05\x8c\x64\x88\xb2"^
  "\xf5\x7b\x17\x25\x1d\x0e\x55\xb8\x03\x25\x46\x7a\x8c\xde\x73\xcc"^
  "\x8f\x9d\xcc\x9c\x7f\x39\xee\x79\x0d\xd1\x00\x39\x00\x16\x03\x01"^
  "\x02\xe0\x0b\x00\x02\xdc\x00\x02\xd9\x00\x02\xd6\x30\x82\x02\xd2"^
  "\x30\x82\x01\xba\xa0\x03\x02\x01\x02\x02\x04\x26\x5c\xbe\xa9\x30"^
  "\x0d\x06\x09\x2a\x86\x48\x86\xf7\x0d\x01\x01\x05\x05\x00\x30\x2b"^
  "\x31\x11\x30\x0f\x06\x03\x55\x04\x03\x13\x08\x46\x6f\x72\x74\x69"^
  "\x6e\x65\x74\x31\x16\x30\x14\x06\x03\x55\x04\x0a\x13\x0d\x46\x6f"^
  "\x72\x74\x69\x6e\x65\x74\x20\x4c\x74\x64\x2e\x30\x1e\x17\x0d\x30"^
  "\x38\x31\x31\x32\x35\x30\x37\x35\x38\x33\x32\x5a\x17\x0d\x31\x38"^
  "\x31\x31\x32\x36\x30\x37\x35\x38\x33\x32\x5a\x30\x2b\x31\x11\x30"^
  "\x0f\x06\x03\x55\x04\x03\x13\x08\x46\x6f\x72\x74\x69\x6e\x65\x74"^
  "\x31\x16\x30\x14\x06\x03\x55\x04\x0a\x13\x0d\x46\x6f\x72\x74\x69"^
  "\x6e\x65\x74\x20\x4c\x74\x64\x2e\x30\x82\x01\x22\x30\x0d\x06\x09"^
  "\x2a\x86\x48\x86\xf7\x0d\x01\x01\x01\x05\x00\x03\x82\x01\x0f\x00"^
  "\x30\x82\x01\x0a\x02\x82\x01\x01\x00\xd2\xf2\xe6\xd4\xb2\x3a\x4a"^
  "\x70\x1f\xf2\xd2\x5b\x6f\x74\xd5\xff\x3d\xfa\xff\x16\x73\x08\xcb"^
  "\x14\x67\x3b\xd9\xf7\xb5\x2b\xbc\xf4\x92\xff\x2e\xea\x7f\x65\x35"^
  "\x70\xff\xe4\xd7\x24\xd8\x22\xe2\x6b\x30\x42\x2b\xc0\x78\xc2\x1f"^
  "\x70\x0c\x62\x0c\x8f\xd9\xef\x49\x57\x38\xbd\xc9\x94\x83\x82\x2a"^
  "\x3d\x21\x97\x97\xa6\x8f\x08\xd4\x41\xf6\xa4\x12\xa2\xea\x7e\x1c"^
  "\xcb\x0f\x0c\xf5\xed\x69\x6d\xeb\x10\xa3\x6e\x1b\x30\xb4\x62\x7b"^
  "\xb4\xa9\x76\x21\xfb\x24\x09\xdd\x93\x78\xb6\xe1\x08\x19\x26\xf3"^
  "\x0e\xde\xb1\x5c\x86\x6e\x44\xe3\x42\x71\x38\xf4\x3b\x9a\x30\x92"^
  "\xd3\x38\x5d\xb6\x25\x06\x64\x1c\xfd\xad\xd6\x66\x29\x19\x66\x0e"^
  "\x30\xd2\x85\x27\x91\x6f\x75\xb9\xd2\x79\xc5\x48\xce\xd0\x7b\xcc"^
  "\xc5\xbe\x82\xb2\x1d\x9c\x95\x2a\x5b\x68\x24\xc3\x63\x06\xcd\x40"^
  "\xff\x69\x24\x6c\xcf\x5d\x9d\x5f\xe2\x77\x66\xd3\x03\x1f\xe0\xfe"^
  "\x00\xb5\x84\xa7\xe1\x96\xc6\x36\xc6\x23\xa1\x05\xf4\xd4\xfa\x9d"^
  "\x54\x33\x14\x0f\x2a\x80\xfa\x6a\xfb\x4d\xfa\xf7\xe4\x8b\x45\x59"^
  "\xc2\x98\x91\x5b\xea\x61\xca\xe4\x57\xcf\xda\x21\x1f\x18\x1d\x1e"^
  "\x02\xc5\xe9\x6e\x6d\x30\xb0\xfb\xd5\x02\x03\x01\x00\x01\x30\x0d"^
  "\x06\x09\x2a\x86\x48\x86\xf7\x0d\x01\x01\x05\x05\x00\x03\x82\x01"^
  "\x01\x00\x43\x62\x1a\x33\xc6\xd6\x93\xb5\x91\x65\xe4\x9c\xb5\x24"^
  "\x75\x9d\xa5\xec\x4c\x38\x5a\x61\xb2\x8b\x23\xff\x06\xbf\x7b\x05"^
  "\xde\xb6\xa5\x46\x35\x1c\xbf\xfb\xf6\xb4\x28\x93\x6a\x3e\xde\x8e"^
  "\x79\xa6\x1e\xcf\xd9\x9f\xc9\x44\x7c\x5b\x78\xac\x57\x66\xf5\x00"^
  "\x76\xe2\x2f\x11\xc2\x41\x94\x4a\xac\xd4\x37\x43\xbe\xea\xe5\x08"^
  "\x46\x75\x60\x09\x4b\x9c\x2d\xb8\x8f\x79\x71\xee\x28\x2c\x1d\x75"^
  "\x4e\x1a\x78\x1e\x37\x56\xef\xda\xf6\xab\x6f\x3b\xff\x40\x4d\xf5"^
  "\x6d\x9d\x53\xc5\x3d\x84\x3b\xf5\x25\xcf\xa5\xe9\xbb\xb4\x5a\x43"^
  "\x94\x08\xb8\xcc\xa8\x48\xe0\xa9\x4b\xca\x8b\x32\x39\x7c\x31\x2d"^
  "\x1e\x38\xd3\xb1\xaa\x0e\xe6\x5a\x72\x4b\x24\x2e\x89\x79\xf4\xc6"^
  "\x78\x0f\x85\x24\x73\x63\xb8\x4a\x2a\xff\xe8\x10\x0d\xbf\x8c\x40"^
  "\xb4\x14\x9b\x47\x17\x3b\x4b\xfa\x0c\x10\x84\xf9\x7d\xc9\x38\x4c"^
  "\xff\x2c\xae\x3a\x84\x65\x22\xb8\xe5\x1e\xef\x13\xe0\x4c\x3f\xe9"^
  "\xef\x79\x0e\xd4\x58\xea\x81\xb8\xab\x35\xc9\x68\xb9\x93\x79\xe6"^
  "\x1d\xa1\xf8\xce\x8f\x90\x8d\xb6\xef\x91\x3b\x5f\x92\x10\xfd\xa3"^
  "\xe1\xec\x5e\x10\x40\xf4\x16\x9c\x71\x1c\xd3\xbd\x94\xdc\x88\x28"^
  "\x06\x57"

let _ =
  let input = input_of_string "Test" dump in
  let answer = parse_answer_dump input in
  print_endline (print_answer_dump "" "AnswerDump" answer);
  if dump_answer_dump answer = dump
  then print_endline "Yes!"
  else print_endline "NO!";

  let s = answer.content in
  enrich_record_content := true;
  let input = input_of_string "TLS Record" s in
  while not (eos input) do
    let tls_record = parse_tls_record input in
    print_endline (print_tls_record "" "TLS_Record" tls_record);
  done;

  print_newline ();

  let s = answer.content in
  enrich_record_content := false;
  let input = input_of_string "TLS Record" s in
  let rec read_records () =
    if not (eos input)
    then begin
      let next = (parse_tls_record input) in
      next::(read_records())
    end else []
  in
  let records = TlsUtil.merge_records ~enrich:false (read_records()) in
  List.iter (fun r -> print_endline (print_tls_record "" "TLS_Record" r)) records;
