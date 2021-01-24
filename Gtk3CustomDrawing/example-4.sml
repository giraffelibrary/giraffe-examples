(* Surface to store current scribbles *)
val surface : Cairo.Surface.t option ref = ref NONE

fun clearSurface () =
  case !surface of
    NONE         => ()
  | SOME surface =>
      let
        val cr = Cairo.Context.create surface

        val () = Cairo.Context.setSourceRgb cr (1.0, 1.0, 1.0)
        val () = Cairo.Context.paint cr
      in
        ()
      end

(* Create a new surface of the appropriate size to store our scribbles *)
fun configureEventCb widget _ =
  let
    val () =
      case Gtk.Widget.getWindow widget of
        NONE        => ()  (* `widget` not realized, do nothing *)
      | SOME window => (
          surface :=
            SOME (
              Gdk.Window.createSimilarSurface window
                (
                  Cairo.Content.COLOR,
                  Gtk.Widget.getAllocatedWidth widget,
                  Gtk.Widget.getAllocatedHeight widget
                )
            )

          ; (* Initialize the surface to white *)
            clearSurface ()
        )
  in
    (* We've handled the configure event, no need for further processing. *)
    true
  end

(* Redraw the screen from the surface. Note that the ::draw
 * signal receives a ready-to-be-used cairo_t that is already
 * clipped to only draw the exposed areas of the widget
 *)
fun drawCb cr =
  case !surface of
    NONE         => false
  | SOME surface =>
      let
        val () = Cairo.Context.setSourceSurface cr (surface, 0.0, 0.0)
        val () = Cairo.Context.paint cr
      in
        false
      end

(* Draw a rectangle on the surface at the given position *)
fun drawBrush widget (x, y) =
  case !surface of
    NONE         => ()
  | SOME surface =>
      let
        (* Paint to the surface, where we store our state *)
        val cr = Cairo.Context.create surface

        val () = Cairo.Context.rectangle cr (x - 3.0, y - 3.0, 6.0, 6.0)
        val () = Cairo.Context.fill cr

        val xInt = Real.toLargeInt IEEEReal.TO_ZERO x
        val yInt = Real.toLargeInt IEEEReal.TO_ZERO y

        (* Now invalidate the affected region of the drawing area. *)
        val () = Gtk.Widget.queueDrawArea widget (xInt - 3, yInt - 3, 6, 6)
      in
        ()
      end

(* Handle button press events by either drawing a rectangle
 * or clearing the surface, depending on which button was pressed.
 * The ::button-press signal handler receives a GdkEventButton
 * struct which contains this information.
 *)
fun buttonPressEventCb widget (event : Gdk.EventButtonRecord.t) =
  (* paranoia check, in case we haven't gotten a configure event *)
  case !surface of
    NONE   => false
  | SOME _ =>
      let
        open Gdk

        val () =
          if #get Gdk.EventButton.button event = Gdk.BUTTON_PRIMARY
          then
            drawBrush widget (#get EventButton.x event, #get EventButton.y event)
          else if #get Gdk.EventButton.button event = Gdk.BUTTON_SECONDARY
          then
            (
              clearSurface ()
            ; Gtk.Widget.queueDraw widget
            )
          else
            ()
      in
        (* We've handled the event, stop processing *)
        true
      end

(* Handle motion events by continuing to draw if button 1 is
 * still held down. The ::motion-notify signal handler receives
 * a GdkEventMotion struct which contains this information.
 *)
fun motionNotifyEventCb widget event =
  (* paranoia check, in case we haven't gotten a configure event *)
  case !surface of
    NONE   => false
  | SOME _ =>
      let
        open Gdk

        val () =
          if ModifierType.anySet (#get EventMotion.state event, ModifierType.BUTTON_1_MASK)
          then
            drawBrush widget (#get EventMotion.x event, #get EventMotion.y event)
          else
            ()
      in
        (* We've handled it, stop processing *)
        true
      end

fun closeWindow () =
  case !surface of
    SOME _ => surface := NONE
  | NONE   => ()

fun activate app () =
  let
    open Gtk

    val window = ApplicationWindow.new app
    val () = Window.setTitle window "Window"

    val _ = Signal.connect window Widget.destroySig closeWindow

    val () = Container.setBorderWidth window 8

    val frame = Frame.new NONE
    val () = Frame.setShadowType frame ShadowType.IN
    val () = Container.add window frame

    val drawingArea = DrawingArea.new ()
    (* set a minimum size *)
    val () = Widget.setSizeRequest drawingArea (100, 100)

    val () = Container.add frame drawingArea

    (* Signals used to handle the backing surface *)
    val _ = Signal.connect drawingArea Widget.drawSig drawCb
    val _ = Signal.connect drawingArea Widget.configureEventSig
                                                  (configureEventCb drawingArea)

    (* Event signals *)
    val _ = Signal.connect drawingArea Widget.motionNotifyEventSig
                                               (motionNotifyEventCb drawingArea)
    val _ = Signal.connect drawingArea Widget.buttonPressEventSig
                                                (buttonPressEventCb drawingArea)

    (* Ask to receive events the drawing area doesn't normally
     * subscribe to. In particular, we need to ask for the
     * button press and motion notify events that want to handle.
     *)
    val () =
      Widget.setEvents drawingArea
        let
          open Gdk.EventMask
        in
          flags [Widget.getEvents drawingArea, BUTTON_PRESS_MASK, POINTER_MOTION_MASK]
        end

    val () = Widget.showAll window
  in
    ()
  end

fun main () =
  let
    val app = Gtk.Application.new (SOME "org.gtk.example", Gio.ApplicationFlags.FLAGS_NONE)
    val _ = Signal.connect app Gio.Application.activateSig (activate app)

    val argv = Utf8CPtrArrayN.fromList (CommandLine.name () :: CommandLine.arguments ())
    val status = Gio.Application.run app argv
  in
    Giraffe.exit status
  end
    handle e => Giraffe.error 1 ["Uncaught exception\n", exnMessage e, "\n"]
