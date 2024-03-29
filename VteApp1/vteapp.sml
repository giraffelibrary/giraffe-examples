fun activate app () =
  let
    val window = VteMainWindow.new app
    val () = Gtk.Window.present window
  in
    ()
  end

fun main () =
  let
    val appId = "org.giraffelibrary.demo.vteapp1"
    val app = Gtk.Application.new (SOME appId, Gio.ApplicationFlags.flags [])
    val id = Signal.connect app (Gio.Application.activateSig, activate app)

    val argv = Utf8CPtrArrayN.fromList (CommandLine.name () :: CommandLine.arguments ())
    val status = Gio.Application.run app argv

    val () = Signal.handlerDisconnect app id
  in
    Giraffe.exit status
  end
    handle e => Giraffe.error 1 ["Uncaught exception\n", exnMessage e, "\n"]
