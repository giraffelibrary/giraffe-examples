local
  open GLib.ChecksumType
in
  val checksumTypeToString =
    fn
      MD_5    => "MD5"
    | SHA_1   => "SHA-1"
    | SHA_256 => "SHA-256"
    | SHA_512 => "SHA-512"
end

fun main () : unit =
  let
    val () = GObject.typeInit ()
    open GLib Gio

    (* get filename from command line *)
    val file =
      case CommandLine.arguments () of
        arg :: _ => File.newForCommandlineArg arg
      | []       => Giraffe.error 1 ["usage: checksum <file>\n"]

    (* create the checksum object *)
    val checksumType = ChecksumType.SHA_256
    val checksum = Checksum.new checksumType

    (* buffer for reading the file into *)
    val bufferSize = 5 * 1024 * 1024

    (* open the file *)
    val istream =
      File.read file NONE
        handle
          Error _ =>
            Giraffe.error 1 ["failed to read file \"", File.getParseName file, "\"\n"]

    (* read the input stream and compute the checksum *)
    val () =
      let
        fun updateChecksum () =
          let
            val (n, buffer) = InputStream.read istream (bufferSize, NONE)
          in
            if n > 0
            then
              let
                val data = GUInt8CArrayN.subslice (buffer, n)
                val () = Checksum.update checksum data
                val () = Giraffe.GC.full ()  (* ensure memory for `buffer` is released *)
              in
                updateChecksum ()
              end
            else
              ()
          end
      in
        updateChecksum ()
      end
        handle e => (
          (* try closing the input stream on error *)
          InputStream.close istream NONE handle _ => ();
          raise e
        )

    (* get the string representation of the checksum *)
    val checksumStr = Checksum.getString checksum

    (* close the input stream *)
    val () =
      InputStream.close istream NONE
        handle
          GLib.Error _ =>
            Giraffe.error 1 ["failed to close file \"", File.getParseName file, "\"\n"]

    (* print the checksum *)
    val () =
      app print [checksumTypeToString checksumType, ": ", checksumStr, "\n"]
  in
    Giraffe.exit 0
  end
    handle e => Giraffe.error 1 ["Uncaught exception\n", exnMessage e, "\n"]
