import evgenia/stream
import streams

import asyncnet, asyncdispatch

type
  AnyPacket* = object
    id*: uint8
  CIdentificationPacket = object
    protocol: uint8
    username: string
    verification: string
  SIdentificationPacket = object
    protocol: uint8
    server_name: string
    motd: string
    user_type: uint8
  SPingPacket* = object

proc read(packet: var CIdentificationPacket, stream: StringStream) =
  packet.protocol = stream.readByte()

  packet.username = stream.readString()
  packet.verification = stream.readString()

proc send(packet: SIdentificationPacket, stream: StringStream, client: AsyncSocket) {.async.} =
  stream.writeByte(0)
  stream.writeByte(packet.protocol)

  stream.writeString(packet.server_name)
  stream.writeString(packet.motd)

  stream.writeByte(packet.user_type)
  stream.setPosition(0)

  echo stream.readAll()
  await client.send(stream.readAll())

proc send*(packet: SPingPacket, client: AsyncSocket) {.async.} =
  let stream = newStringStream()

  stream.writeByte(1)
  stream.setPosition(0)
  
  await client.send(stream.readAll())

proc proccess*(pkt: AnyPacket, stream: StringStream, client: AsyncSocket) =
  case pkt.id
    of 0x00:
      var packet = CIdentificationPacket()
      packet.read(stream)

      let response = SIdentificationPacket(protocol: 0, server_name: "Shit", motd: "Cum", user_type: 0)
      asyncCheck response.send(stream, client)

      asyncCheck SPingPacket().send(client)

      echo 0x00, " processed", packet.username
    else:
      echo "Not implemented"