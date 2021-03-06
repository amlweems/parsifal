open Parsifal
open BasePTypes
open PTypes


enum file_type (8, UnknownVal UnknownFileType) =
  | 0 -> NormalFile
  | 0x30 -> NormalFile
  | 0x31 -> HardLink
  | 0x32 -> SymbolicLink
  | 0x33 -> CharacterSpecial
  | 0x34 -> BlockSpecial
  | 0x35 -> Directory
  | 0x36 -> FIFO
  | 0x37 -> ContiguousFile


type tar_numstring = int

let parse_tar_numstring len input =
  let octal_value = parse_string (len - 1) input in
  drop_bytes 1 input;
  try int_of_string ("0o" ^ octal_value)
  with _ -> raise (ParsingException (CustomException "int_of_string", _h_of_si input))

let dump_tar_numstring len buf v =
  POutput.bprintf buf "%*.*o\x00" len len v

let value_of_tar_numstring v = VInt v


union optional_tar_numstring [both_param len; enrich] (UnparsedNum of binstring(len)) =
  | CharacterSpecial -> Num of tar_numstring[len]
  | BlockSpecial -> Num of tar_numstring[len]


struct ustar_header [param file_type] =
{
  ustar_magic : magic("ustar");
  ustar_magic_padding : binstring(3);
  owner_user : string(32);
  owner_group : string(32);
  device_major : optional_tar_numstring[8](file_type);
  device_minor : optional_tar_numstring[8](file_type);
  filename_prefix : string(155)
}

struct tar_header =
{
  file_name : string(100);
  file_mode : tar_numstring[8];
  owner_uid : tar_numstring[8];
  owner_gid : tar_numstring[8];
  file_size : tar_numstring[12];
  timestamp : tar_numstring[12];
  checksum  : string(8);
  file_type : file_type;
  linked_file : string(100);
  optional ustar_header : ustar_header(file_type);
  hdr_padding : binstring
}


struct tar_entry =
{
  header : container(512) of tar_header;
  file_content : binstring(header.file_size);
  file_padding : binstring(512 - (header.file_size mod 512))
}


let rec handle_entry input =
  let entry = parse_tar_entry input in
  print_endline (print_value (value_of_tar_header entry.header));
  handle_entry input

let _ =
  let input = string_input_of_filename "test.tar" in
  handle_entry input
