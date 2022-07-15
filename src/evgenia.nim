import asyncnet, asyncdispatch
import strutils, streams

import packet

var clients {.threadvar.}: seq[AsyncSocket]

proc processClient(client: AsyncSocket) {.async.} =
  while true:
    let data = await client.recv(1024)
    
    if data != "":
      let stream = newStringStream(data)

      let packet = AnyPacket(id: stream.peekUint8())
      packet.proccess(stream, client)
    else:
      client.close()

      for i, c in clients:
        if c == client:
          clients.del(i)
          break
      break

proc sendHeartbeat() {.async.} =
  var socket = newAsyncSocket()
  await socket.connect("classicube.net", Port(80))
  await socket.send("WHEN I WILL IMPLEMENT OPTIONS THIS SHIT WILL BE")
  socket.close()

proc heartbeat(fd: AsyncFd): bool =
  asyncCheck sendHeartbeat()
  return false

proc serve() {.async.} =
  var server = newAsyncSocket(buffered=false)
  server.bindAddr(Port(25565))
  server.listen()
  
  addTimer(45000, false, heartbeat)

  let ping = proc (fd: AsyncFd): bool {.closure.} =
    for client in clients:
      asyncCheck SPingPacket().send(client)
      return false
      
  addTimer(5000, false, ping)

  while true:
    let client = await server.accept()
    clients.add client

    asyncCheck processClient(client)

asyncCheck serve()
runForever()