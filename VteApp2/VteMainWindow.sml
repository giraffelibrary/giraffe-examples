structure VteMainWindow =
  struct
    open Gtk


    fun log level msg = GLib.log ("VteApp", level, msg)
    val logMessage = log GLib.LogLevelFlags.LEVEL_MESSAGE
    val logWarning = log GLib.LogLevelFlags.LEVEL_WARNING


    fun parseCheckRgba name =
      let
        val rgba = Gdk.Rgba.new {red = 1.0, green = 1.0, blue = 1.0, alpha = 1.0}
      in
        if Gdk.Rgba.parse rgba name
        then SOME rgba
        else (
          logWarning (concat ["color \"", name, "\" not known"]);
          NONE
        )
      end


    fun runWarnDlg parent title msg =
      let
        val dlg =
          GObject.Object.new (
            MessageDialogClass.t,
            [
              Property.init Window.titleProp              (SOME title),
              Property.init Window.transientForProp       (SOME parent),
              Property.init Window.modalProp              true,
              Property.init MessageDialog.messageTypeProp MessageType.WARNING,
              Property.init MessageDialog.buttonsProp     ButtonsType.OK,
              Property.init MessageDialog.textProp        (SOME (concat msg))
            ]
          )

        val _ = Signal.connect dlg (Dialog.responseSig, Fn.const o Widget.destroy)

        val () = Window.setModal dlg true
        val () = Widget.show dlg
      in
        ()
      end


    type proc = {
      pid : GLib.Pid.t
    }

    val theProc : proc option ref = ref NONE


    fun setWidgetProps {vte, cmdEntry, execBtn, killBtn} running =
      if running
      then (
        Widget.setCanFocus vte true;
        Widget.grabFocus vte;
        Widget.setSensitive cmdEntry false;
        Widget.setSensitive execBtn false;
        Widget.setSensitive killBtn true
      )
      else (
        Widget.setSensitive cmdEntry true;
        Widget.setSensitive execBtn true;
        Widget.setSensitive killBtn false;
        Widget.grabFocus cmdEntry;
        Widget.setCanFocus vte false
      )


    fun childClose widgets status =
      (
        logMessage (
          concat [
            "childClose: application exited with status ",
            LargeInt.toString status
          ]
        );
        theProc := NONE;
        setWidgetProps widgets false
      )


    fun kill () =
      case !theProc of
        SOME {pid, ...} => (
          Posix.Process.kill (Posix.Process.K_GROUP pid, Posix.Signal.kill)
        )
      | NONE            => logMessage "Application not running"


    (* ---------------------------------------------------------------------- *
     * Accelerators                                                           *
     * ---------------------------------------------------------------------- *)

    fun makeAccel (name, accels) = (name, Utf8CPtrArray.fromList accels)
    fun makeAccels () =
      List.map makeAccel [
        ("app.quit", ["<control>q"])
      ]

    fun addAccels app =
      List.app (Application.setAccelsForAction app) (makeAccels ())


    (* ---------------------------------------------------------------------- *
     * Actions                                                                *
     * ---------------------------------------------------------------------- *)

    fun cmdExec mainWnd widgets () =
      case !theProc of
        SOME _ => logMessage "Application already started"
      | NONE   =>
          let
            val argv = GLib.shellParseArgv (Entry.getText (#cmdEntry widgets))

            val () =
              logMessage (
                concat [
                  "About to execute \"",
                  String.concatWith " " (Utf8CPtrArray.toList argv),
                  "\""
                ]
              )

            val pid =
              VteTerminal.spawnSync (#vte widgets) (
                VtePtyFlags.DEFAULT,
                NONE,
                argv,
                NONE,
                GLib.SpawnFlags.SEARCH_PATH,
                NONE,
                NONE
              )
          in
            theProc := SOME {pid = pid};
            setWidgetProps widgets true
          end
            handle
              GLib.Error (dom, err) => (
                logMessage (
                  case dom of
                    GLib.ShellError _ => "Failed to parse command"
                  | GLib.SpawnError _ => "Application failed to start"
                  | _                 => "Error with unknown origin"
                );
                runWarnDlg mainWnd "Error" [#get GLib.Error.message err]
              )

    fun cmdKill () = kill ()

    fun cmdFont mainWnd {vte, ...} () =
      let
        val dlg = FontChooserDialog.new (SOME "Choose font", SOME mainWnd)

        val () =
          FontChooser.setFontDesc (FontChooserDialog.asFontChooser dlg)
            (Vte.Terminal.getFont vte)

        fun onResponse dlg res =
          let
            val () =
              if res = ResponseType.OK
              then
                Vte.Terminal.setFont vte
                  (FontChooser.getFontDesc (FontChooserDialog.asFontChooser dlg))
              else
                ()
 
            val () = Widget.destroy dlg
          in
            ()
          end
        val _ = Signal.connect dlg (Dialog.responseSig, onResponse)

        val () = Window.setModal dlg true
        val () = Widget.show dlg
      in
        ()
      end

    fun cmdQuit mainWnd () = Widget.destroy mainWnd

    fun addSimpleAction actionMap (name, activateFun : (unit -> unit) option) =
      let
        open Gio

        val action = SimpleAction.new (name, NONE)
        fun check f _ =
          fn
            NONE   => f ()
          | SOME _ =>
              log GLib.LogLevelFlags.LEVEL_WARNING
                "activate function expected argument NONE"

        val () =
          case activateFun of
            SOME f => ignore (
              Signal.connect action (SimpleAction.activateSig, check f)
            )
          | NONE   => ()
        val () = SimpleAction.setEnabled action true
        val () = ActionMap.addAction actionMap (SimpleAction.asAction action)
      in
        ()
      end


    (* ---------------------------------------------------------------------- *
     * Main window initialization                                             *
     * ---------------------------------------------------------------------- *)

    fun deleteEvent _ _ = false

    fun destroy app _ = (
      case !theProc of
        SOME _ => kill ()
      | _      => ();
      Gio.Application.quit app
    )

    fun new app =
      let
        val spinLbl = Label.new (SOME "Scrollback lines:")
        val spinBtn = SpinButton.newWithRange (0.0, 999999999.0, 1.0)
        val cmdLbl = Label.new (SOME "Command:")
        val cmdEntry = Entry.new ()
        val execBtn = Button.newWithMnemonic "_Execute"
        val killBtn = Button.newWithMnemonic "_Kill"
        val fontBtn = Button.newWithMnemonic "_Font"
        val quitBtn = Button.newWithMnemonic "_Quit"
        val vte = VteTerminal.new ()
        val widgets = {
          cmdEntry = cmdEntry,
          execBtn  = execBtn,
          killBtn  = killBtn,
          vte      = vte
        }

        val hBox = Box.new (Orientation.HORIZONTAL, 0)
        val vBox = Box.new (Orientation.VERTICAL, 0)
        val scrWnd = ScrolledWindow.new (NONE, NONE)
        val mainWnd = ApplicationWindow.new app

        (* main window signals *)
        val _ = Signal.connect mainWnd (Widget.deleteEventSig, deleteEvent)
        val _ = Signal.connect mainWnd (Widget.destroySig, destroy app)

        (* main window layout *)
        val () = Box.setHomogeneous hBox false
        val () = Box.packStart hBox (cmdLbl,   false, false, 0)
        val () = Box.packStart hBox (cmdEntry, false, false, 0)
        val () = Box.packStart hBox (execBtn,  false, false, 0)
        val () = Box.packStart hBox (killBtn,  false, false, 0)
        val () = Box.packStart hBox (fontBtn,  true,  false, 0)
        local
          val spinBox = Box.new (Orientation.HORIZONTAL, 0)
        in
          val () = Box.setHomogeneous spinBox false
          val () = Box.packStart spinBox (spinLbl, false, false, 0)
          val () = Box.packStart spinBox (spinBtn, false, false, 0)
          val () = Box.packStart hBox (spinBox, true, false, 0)
        end
        val () = Box.packEnd   hBox (quitBtn,  false, false, 0)

        val () = Container.add scrWnd vte
        local
          val v = ValueAccessor.new int ~1
          val () = Widget.styleGetProperty scrWnd ("scrollbar-spacing", v)
          val spacing = ValueAccessor.get int v
        in
          val () = Container.setBorderWidth scrWnd spacing
        end
        val () = ScrolledWindow.setPolicy scrWnd (PolicyType.NEVER, PolicyType.ALWAYS)

        val () = Box.setHomogeneous vBox false
        val () = Box.packStart vBox (hBox,   false, false, 0)
        val () = Box.packEnd   vBox (scrWnd, true,  true,  0)

        val () = Container.add mainWnd vBox

        val () = Window.setTitle mainWnd "VteApp"
        val () = Window.setDefaultSize mainWnd (800, 450)

        (* Set up control widgets *)
        (*   - set actions *)
        local
          fun setButtonActionName (button, actionName) =
            Actionable.setActionName (Button.asActionable button) actionName
        in
          val () =
            List.app setButtonActionName [
              (execBtn, SOME "win.exec"),
              (killBtn, SOME "win.kill"),
              (fontBtn, SOME "win.font"),
              (quitBtn, SOME "app.quit")
            ]
        end

        (*   - set accelerators *)
        val () = addAccels app

        (*   - add actions to window *)
        val () =
          List.app (addSimpleAction (ApplicationWindow.asActionMap mainWnd)) [
            ("exec", SOME (cmdExec mainWnd widgets)),
            ("kill", SOME cmdKill),
            ("font", SOME (cmdFont mainWnd widgets))
          ]

        (*   - add actions to application *)
        val () =
          List.app (addSimpleAction (Application.asActionMap app)) [
            ("quit", SOME (cmdQuit mainWnd))
          ]

        (*   - set focus/sensitivity, must be done after actions *)
        val () = setWidgetProps widgets false

        (*   - set window default command and activate on enter in `cmdEntry` *)
        val () = Widget.setCanDefault execBtn true
        val () = Widget.grabDefault execBtn
        val () = Entry.setActivatesDefault cmdEntry true

        (*   - set default number of lines in scroll history *)
        val () = SpinButton.setValue spinBtn 10.0

        (*   - virtual terminal *)
        val () =
          VteTerminal.setColors vte (
            parseCheckRgba "black",
            parseCheckRgba "lightblue",
            GdkRgbaRecordCArrayN.fromList []
          )
        val _ = Signal.connect vte (VteTerminal.childExitedSig, fn _ => childClose widgets)
        local
          fun setVteScrollback spinBtn =
            VteTerminal.setScrollbackLines vte (SpinButton.getValueAsInt spinBtn)
        in
          (* set scrollback lines now... *)
          val () = setVteScrollback spinBtn

          (* ...and when changed.        *)
          val _ = Signal.connect spinBtn (SpinButton.valueChangedSig, setVteScrollback)
        end

        (* show everything *)
        val () = Widget.showAll mainWnd
      in
        mainWnd
      end

  end
