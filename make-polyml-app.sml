let
  val () = PolyML.SaveState.loadState "polyml-libs.state"
  val () = use "polyml-app.sml"
  val () = use "polyml-export.sml"
in
  OS.Process.exit OS.Process.success : unit
end
  handle e => (app print [exnMessage e, "\n"]; OS.Process.exit OS.Process.failure)
