val localInterface = NONE
val localPort = 6600
val multicastAddr = "239.255.201.1"

fun fmtInetSocketAddress inetSockAddr =
  let
    open Gio

    val addr = InetSocketAddress.getAddress inetSockAddr
    val port = InetSocketAddress.getPort inetSockAddr

    val addrStr = InetAddress.toString addr
    val portStr = LargeInt.toString port
  in
    concat [addrStr, ":", portStr]
  end

fun main () : unit =
  let
    val () = GObject.typeInit ()
    open Gio

    (* create UDP socket *)
    val socket = Socket.new (SocketFamily.IPV_4, SocketType.DATAGRAM, SocketProtocol.DEFAULT)

    (* get multicast internet address *)
    val multicastInetAddr =
      case InetAddress.newFromString multicastAddr of
        SOME address => address
      | NONE         => Giraffe.error 1 ["address \"", multicastAddr, "\" not valid\n"]
    val multicastInetAddrStr = InetAddress.toString multicastInetAddr

    (* get multicast socket address *)
    val multicastInetSockAddr = InetSocketAddress.new (multicastInetAddr, localPort)
    val multicastInetSockAddrStr = fmtInetSocketAddress multicastInetSockAddr
  in
    (* behave as the sender or the receiver depending on the arguments *)
    case CommandLine.arguments () of
      num :: _ =>
      (* one or more aguments: sender *)
      let
        (* convert the first argument to an integer *)
        val n0 =
          case Int.fromString num of
            SOME n => n
          | NONE   => Giraffe.error 1 ["first argument is not a signed integer\n"]

        val delay = Time.fromSeconds 1

        (* send integers as strings to the socket, increasing by 1 until "0" is sent *)
        fun log msg = app print ["sending to ", multicastInetSockAddrStr, ": \"", msg, "\"\n"]

        fun send n =
          let
            val msg = Int.toString n
            val () = log msg
            val buffer =
              GUInt8CArrayN.tabulate
                (String.size msg, fn i => Byte.charToByte (String.sub (msg, i)))
            val _ =
              Socket.sendTo socket (SOME multicastInetSockAddr, buffer, NONE)
                handle GLib.Error _ => Giraffe.error 1 ["failed to send message\n"]
            val () = GC.full ()
          in
            if n <> 0
            then (Posix.Process.sleep delay; send (n + 1))
            else ()
          end

        val () = send n0
      in
        ()
      end

    | [] =>
      (* no arguments: receiver *)
      let
        (* bind the socket to the multicast address *)
        val () = app print ["binding to ", multicastInetSockAddrStr, "\n"]
        val () = Socket.bind socket (multicastInetSockAddr, true)

        (* join the multicast group *)
        val () =
          app (app print) [
            ["joining multicast group ", multicastInetAddrStr, " via "],
            case localInterface of
              SOME iface => ["local interface ", iface]
            | NONE       => ["default local interface"],
            ["\n"]
          ]
        val () =
          Socket.joinMulticastGroup socket (multicastInetAddr, false, localInterface)
            handle
              GLib.Error _ => Giraffe.error 1 ["failed to join multicast group\n"]

        (* create a buffer to receive data *)
        val maxRecvSize = 128

        (* receive from the socket until a string that represents zero is received *)
        fun log inetSockAddr msg =
          app print ["received from ", fmtInetSocketAddress inetSockAddr, ": \"", msg, "\"\n"]

        fun receive () =
          let
            val (n, fromSockAddr, buffer) = Socket.receiveFrom socket (maxRecvSize, NONE)
            val fromInetSockAddr =
              case SocketAddress.getFamily fromSockAddr of
                SocketFamily.IPV_4 =>
                  SocketAddressClass.toDerived InetSocketAddressClass.t fromSockAddr
              | _ => Giraffe.error 1 ["message received from non-inet socket address\n"]
            val msg = CharVector.tabulate (n, Byte.byteToChar o GUInt8CArrayN.get buffer)
            val () = log fromInetSockAddr msg
            val () = GC.full ()
          in
            case Int.fromString msg of
              SOME 0 => ()
            | _      => receive ()
          end

        val () = receive ()

        (* leave the multicast group *)
        val () =
          app (app print) [
            ["leaving multicast group ", multicastInetAddrStr, " via "],
            case localInterface of
              SOME iface => ["local interface ", iface]
            | NONE       => ["default local interface"],
            ["\n"]
          ]
        val () =
          Socket.leaveMulticastGroup socket (multicastInetAddr, false, localInterface)
            handle
              GLib.Error _ => Giraffe.error 1 ["failed to leave multicast group\n"]
      in
        Giraffe.exit 0
      end
  end
    handle e => Giraffe.error 1 ["Uncaught exception\n", exnMessage e, "\n"]
