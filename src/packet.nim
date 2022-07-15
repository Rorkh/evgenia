import streams
import asyncnet, asyncdispatch

type
  AnyPacket* = object
    id*: uint8
  CIdentificationPacket* = object
    protocol*: uint8
    username*: string
    verification*: string
  SIdentificationPacket* = object
    protocol*: uint8
    server_name*: string
    motd*: string
    user_type*: uint8

proc writeStr(stream: StringStream, str: string, length: int) =
  let l = len(str)
  var res = ""

  for i in 0..length:
    if i < l:
      res = res & str[i]
    else:
      res = res & ""

  stream.write(res)

proc read*(packet: var CIdentificationPacket, stream: StringStream) =
  packet.protocol = stream.peekUint8()

  packet.username = stream.peekStr(64)
  packet.verification = stream.peekStr(64)

proc send*(packet: SIdentificationPacket, stream: StringStream, client: AsyncSocket) {.async.} =
  stream.write(cast[uint8](0))
  stream.write(packet.protocol)

  stream.writeStr(packet.server_name, 64)
  stream.writeStr(packet.motd, 64)

  stream.write(cast[uint8](packet.user_type))
  stream.setPosition(0)

  echo stream.readAll()
  await client.send(stream.readAll())

proc proccess*(pkt: AnyPacket, stream: StringStream, client: AsyncSocket) =
  case pkt.id
    of 0x00:
      var packet = CIdentificationPacket()
      packet.read(stream)

      let response = SIdentificationPacket(protocol: 0, server_name: "Shit", motd: "Cum", user_type: 0)
      asyncCheck response.send(stream, client)

      echo 0x00, " processed", packet.username
    else:
      echo "Not implemented"