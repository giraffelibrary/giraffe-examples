fun printHello () = print "Hello World\n"

fun activate app () =
  let
    open Gtk

    val window = ApplicationWindow.new app
    val () = Window.setTitle window "Window"
    val () = Window.setDefaultSize window (200, 200)

    val buttonBox = ButtonBox.new Orientation.HORIZONTAL
    val () = Container.add window buttonBox

    val button = Button.newWithLabel "Hello World"
    val _ = Signal.connect button (Button.clickedSig, printHello)
    val _ = Signal.connect button (Button.clickedSig, fn () => Widget.destroy window)
    val () = Container.add buttonBox button

    val () = Widget.showAll window
  in
    ()
  end

fun main () =
  let
    val app = Gtk.Application.new (SOME "org.gtk.example", Gio.ApplicationFlags.FLAGS_NONE)
    val id = Signal.connect app (Gio.Application.activateSig, activate app)

    val argv = Utf8CPtrArrayN.fromList (CommandLine.name () :: CommandLine.arguments ())
    val status = Gio.Application.run app argv

    val () = Signal.handlerDisconnect app id
  in
    Giraffe.exit status
  end
    handle e => Giraffe.error 1 ["Uncaught exception\n", exnMessage e, "\n"]
