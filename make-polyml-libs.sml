let
  val () = PolyML.Compiler.reportExhaustiveHandlers := false
  val () = PolyML.Compiler.reportUnreferencedIds := true

  val smlDir =
    case OS.Process.getEnv "GIRAFFE_SML_LIB" of
      SOME dir => dir
    | NONE     => raise Fail "GIRAFFE_SML_LIB not set"

  val () = PolyML.use (OS.Path.joinDirFile {dir = smlDir, file = "polyml.sml"})
  val () = PolyML.use "polyml-libs.sml"

  val () = PolyML.SaveState.saveState "polyml-libs.state"
in
  OS.Process.exit OS.Process.success : unit
end
  handle e => (app print [exnMessage e, "\n"]; OS.Process.exit OS.Process.failure)
