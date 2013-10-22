open Parsifal
open BasePTypes
open PTypes

type crc_check = binstring

let parse_crc_check chunk_type chunk_data input =
  let crc = parse_string 4 input in
  let computed_crc = Crc.crc32 (chunk_type ^ chunk_data) in
  if computed_crc <> crc
  then Printf.printf "Invalid CRC: %s computed instead of %s\n" (hexdump computed_crc) (hexdump crc);
  crc

let dump_crc_check = dump_binstring
let value_of_crc_check = value_of_binstring


struct chunk = {
  chunk_size : uint32;
  chunk_type : string(4);
  chunk_data : binstring(chunk_size);
  chunk_crc : crc_check(chunk_type; chunk_data);
}

struct png_file = {
  magic : magic("\x89PNG\r\n\x1a\n");
  chunks : list of chunk;
}

let keep_critical_chunk c =
  match c.chunk_type with
    | "IHDR" | "IDAT" | "PLTE" | "IEND" -> true
    | _ -> false

let _ =
  if Array.length Sys.argv <> 3
  then failwith "Usage: ./pngtools <png file> <output>";

  let input = string_input_of_filename Sys.argv.(1) in
  let png_file = parse_png_file input in

  let new_chunks = List.filter keep_critical_chunk png_file.chunks in
  let new_png_file = { png_file with chunks = new_chunks } in

  let output_file = open_out Sys.argv.(2) in
  let output = POutput.create () in
  dump_png_file output new_png_file;
  POutput.output_buffer output_file output

