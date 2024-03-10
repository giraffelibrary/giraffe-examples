fun printHello _ () = print "Hello World\n"

(* Wrap Gtk.Builder.getObject to check for `NONE` and to downcast the result. *)
fun getObject subclass builder name =
  case Gtk.Builder.getObject builder name of
    SOME object => GObject.ObjectClass.toDerived subclass object
  | NONE => Giraffe.error 1 ["Error getting builder object: \"", name, "\" not found\n"]

fun main () =
  let
    val argv = Utf8CPtrArrayN.fromList (CommandLine.name () :: CommandLine.arguments ())
    val _ = Gtk.init argv

    (* Construct a GtkBuilder instance and load our UI description *)
    val builder = Gtk.Builder.new ()
    val _ =
      Gtk.Builder.addFromFile builder "builder.ui"
        handle
          GLib.Error (_, error) =>
            Giraffe.error 1 ["Error loading file: ", #get GLib.Error.message error, "\n"]

    (* Connect signal handlers to the constructed widgets. *)
    val window = getObject Gtk.WindowClass.t builder "window"
    val _ = Signal.connect window (Gtk.Widget.destroySig, fn _ => Gtk.mainQuit)

    val button = getObject Gtk.ButtonClass.t builder "button1"
    val _ = Signal.connect button (Gtk.Button.clickedSig, printHello)

    val button = getObject Gtk.ButtonClass.t builder "button2"
    val _ = Signal.connect button (Gtk.Button.clickedSig, printHello)

    val button = getObject Gtk.ButtonClass.t builder "quit"
    val _ = Signal.connect button (Gtk.Button.clickedSig, fn _ => Gtk.mainQuit)

    val () = Gtk.main ()
  in
    Giraffe.exit 0
  end
    handle e => Giraffe.error 1 ["Uncaught exception\n", exnMessage e, "\n"]
