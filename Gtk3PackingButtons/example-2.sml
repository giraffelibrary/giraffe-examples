fun printHello () = print "Hello World\n"

fun activate app () =
  let
    open Gtk

    (* create a new window, and set its title *)
    val window = ApplicationWindow.new app
    val () = Window.setTitle window "Window"
    val () = Container.setBorderWidth window 10

    (* Here we construct the container that is going pack our buttons *)
    val grid = Grid.new ()

    (* Pack the container in the window *)
    val () = Container.add window grid

    val button = Button.newWithLabel "Button 1"
    val _ = Signal.connect button Button.clickedSig printHello

    (* Place the first button in the grid cell (0, 0), and make it fill
     * just 1 cell horizontally and vertically (ie no spanning)
     *)
    val () = Grid.attach grid (button, 0, 0, 1, 1)

    val button = Button.newWithLabel "Button 2"
    val _ = Signal.connect button Button.clickedSig printHello

    (* Place the second button in the grid cell (1, 0), and make it fill
     * just 1 cell horizontally and vertically (ie no spanning)
     *)
    val () = Grid.attach grid (button, 1, 0, 1, 1)

    val button = Button.newWithLabel "Quit"
    val _ = Signal.connect button Button.clickedSig (fn () => Widget.destroy window)

    (* Place the Quit button in the grid cell (0, 1), and make it
     * span 2 columns.
     *)
    val () = Grid.attach grid (button, 0, 1, 2, 1)

    (* Now that we are done packing our widgets, we show them all
     * in one go, by calling Gtk.Widget.showAll () on the window.
     * This call recursively calls Gtk.Widget.show () on all widgets
     * that are contained in the window, directly or indirectly.
     *)
    val () = Widget.showAll window
  in
    ()
  end

fun main () =
  let
    val app = Gtk.Application.new (SOME "org.gtk.example", Gio.ApplicationFlags.FLAGS_NONE)
    val id = Signal.connect app Gio.Application.activateSig (activate app)

    val argv = Utf8CPtrArrayN.fromList (CommandLine.name () :: CommandLine.arguments ())
    val status = Gio.Application.run app argv

    val () = Signal.disconnect app id
  in
    Giraffe.exit status
  end
    handle e => Giraffe.error 1 ["Uncaught exception\n", exnMessage e, "\n"]
