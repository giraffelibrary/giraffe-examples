fun activate app =
  let
    val window = VteMainWindow.new app
    val () = Gtk.Window.present window
  in
    ()
  end

fun main () =
  let
    val appId = "org.giraffelibrary.demo.vteapp2"
    val app = Gtk.Application.new (SOME appId, Gio.ApplicationFlags.flags [])
    val _ = Signal.connect app (Gio.Application.activateSig, activate)

    val argv = Utf8CPtrArrayN.fromList (CommandLine.name () :: CommandLine.arguments ())
    val status = Gio.Application.run app argv
  in
    Giraffe.exit status
  end
    handle e => Giraffe.error 1 ["Uncaught exception\n", exnMessage e, "\n"]
