open Parsifal
open BasePTypes
open PTypes


enum color_type (8, UnknownVal UnknownColorType) =
| 0 -> Grayscale
| 0x02 -> Truecolor
| 0x03 -> Indexedcolor
| 0x04 -> GrayscaleWithAlphaChannel
| 0x06 -> TruecolorWithAlphaChannel

enum compression_method (8, UnknownVal UnknownCompressionMethod) =
| 0 -> Deflate

enum filter_method (8, UnknownVal UnknownFilterMethod) =
| 0 -> AdaptativeFilter

enum interlace_method (8, UnknownVal UnknownInterlaceMethod) =
| 0 -> NoInterlace
| 0x01 -> Adam7

struct image_header = {
  width : uint32;
  height : uint32;
  bit_depth : uint8;
  color_type : color_type;
  compression_method : compression_method;
  filter_method : filter_method;
  interlace_method : interlace_method;
}

union chunk_content [enrich] (UnparsedChunkContent) =
| "IHDR" -> ImageHeader of image_header
| "IDAT" -> ImageData of binstring
| "IEND" -> ImageEnd
| "PLTE" -> ImagePalette of list of array(3) of uint8


type png_chunk = {
  chunk_type : string;
  chunk_data : chunk_content;
}

let parse_png_chunk input =
  let chunk_size = parse_uint32 input in
  let chunk_raw_data = peek_string (chunk_size + 4) input in
  let chunk_type = parse_string 4 input in
  let chunk_data = parse_container chunk_size "chunk_data" (parse_chunk_content chunk_type) input in
  let chunk_crc = parse_string 4 input in
  let computed_crc = Crc.crc32 chunk_raw_data in
  if computed_crc <> chunk_crc then emit_parsing_exception false (CustomException "Invalid CRC") input;
  { chunk_type = chunk_type; chunk_data = chunk_data }

let dump_png_chunk buf chunk =
  let tmp_output = POutput.create () in
  dump_chunk_content tmp_output chunk.chunk_data;
  let len = POutput.length tmp_output in
  let crc = Crc.crc32 (chunk.chunk_type ^ (POutput.contents tmp_output)) in
  dump_uint32 buf len;
  POutput.add_string buf chunk.chunk_type;
  POutput.add_output buf tmp_output;
  POutput.add_string buf crc

let value_of_png_chunk chunk =
  VRecord [
    "@name", VString ("png_chunk", false);
    "type", VString (chunk.chunk_type, false);
    "data", value_of_chunk_content chunk.chunk_data;
  ]


struct png_file = {
  png_magic : magic("\x89\x50\x4e\x47\x0d\x0a\x1a\x0a");
  chunks : list of png_chunk;
}


type status = FirstChunk | BeforeIDAT | AfterIDAT | AfterIEND

let handle_chunk (hdr, palette, data, status) c =
  match c.chunk_type, c.chunk_data, hdr, palette, data, status with
  | _, _, _, _, _, AfterIEND -> failwith "There should be nothing after IEND chunk"

  | "IHDR", ImageHeader h, None, None, "", FirstChunk -> (Some h, None, "", BeforeIDAT)
  | "IHDR", _, Some _, _, _, _ -> failwith "Multiple headers are not allowed"
  | _, _, _, _, _, FirstChunk -> failwith "IHDR should be first"
  | "IHDR", _, _, _, _, _ -> failwith "Invalid or misplaced IHDR"    (* Should never happen *)

  | "PLTE", ImagePalette p, Some { color_type = Indexedcolor }, None, "", BeforeIDAT -> (hdr, Some p, "", BeforeIDAT)
  | "PLTE", _, _, None, "", BeforeIDAT -> failwith "Palette should only be present when color_type is Indexed"
  | "PLTE", _, _, Some _, _, _ -> failwith "Multiple palettes are not allowed"
  | "PLTE", _, _, _, _, AfterIDAT -> failwith "Palette should not appear after data"
  | "PLTE", _, _, _, _, _ -> failwith "Palette should not appear after data"

  | "IDAT", ImageData d, Some { color_type = Indexedcolor }, Some _, _, _
  | "IDAT", ImageData d, _, None, _, _ -> (hdr, palette, data ^ d, AfterIDAT)
  | "IDAT", _, Some { color_type = Indexedcolor }, None, _, _ -> failwith "Missing palette before IDAT"
  | "IDAT", _, _, _, _, _ -> failwith "Invalid or misplaced IDAT chunk"

  | "IEND", ImageEnd, Some { color_type = Indexedcolor }, Some _, _, AfterIDAT
  | "IEND", ImageEnd, _, None, _, AfterIDAT -> (hdr, palette, data, AfterIEND)
  | "IEND", _, _, _, _, BeforeIDAT -> failwith "Empty image"
  | "IEND", _, _, _, _, _ -> failwith "Unexpected IEND"

  | _, _, _, _, _, _ ->
    if ((int_of_char c.chunk_type.[0]) land 0x20) = 0x20
    then (hdr, palette, data, status)
    else failwith ("Unknown critical chunk encountered: " ^ c.chunk_type)

let clean_png_file png_file =
  let new_file = List.fold_left handle_chunk (None, None, "", FirstChunk) png_file.chunks in
  let new_chunks = match new_file with
    | Some ({ color_type = Indexedcolor } as h), Some p, data, AfterIEND ->
      [ { chunk_type = "IHDR"; chunk_data = ImageHeader h };
	{ chunk_type = "PLTE"; chunk_data = ImagePalette p };
	{ chunk_type = "IDAT"; chunk_data = ImageData data };
	{ chunk_type = "IEND"; chunk_data = ImageEnd } ]
    | Some h, None, data, AfterIEND ->
      [ { chunk_type = "IHDR"; chunk_data = ImageHeader h };
	{ chunk_type = "IDAT"; chunk_data = ImageData data };
	{ chunk_type = "IEND"; chunk_data = ImageEnd } ]
    | _, _, _, _ -> failwith "Invalid PNG file"
  in
  { png_file with chunks = new_chunks }


let display filename =
  let input = string_input_of_filename filename in
  let png_file = parse_png_file input in
  print_endline (print_value (value_of_png_file png_file))

let normalize src dst =
  let input = string_input_of_filename src in
  let png_file = parse_png_file input in
  let new_png_file = clean_png_file png_file in

  let output_file = open_out dst in
  let output = POutput.create () in
  dump_png_file output new_png_file;
  POutput.output_buffer output_file output


let _ =
  try
    match Array.length Sys.argv with
    | 2 -> display Sys.argv.(1); exit 0
    | 3 -> normalize Sys.argv.(1) Sys.argv.(2); exit 0
    | _ -> prerr_endline "Please provide one or two arguments."; exit 1
  with
    | ParsingException (e, h) -> prerr_endline (string_of_exception e h); exit 1
    | e -> prerr_endline (Printexc.to_string e); exit 1
