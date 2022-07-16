import streams

proc readByte*(stream: StringStream): uint8 =
  return stream.peekUint8()

proc readSByte*(stream: StringStream): int8 =
  return stream.peekInt8()

proc readShort*(stream: StringStream): int16 =
  return stream.peekInt16()

proc readString*(stream: StringStream): string =
  return stream.peekStr(64)

proc writeByte*(stream: StringStream, `byte`: uint8) =
  stream.write(`byte`)

proc writeSByte*(stream: StringStream, sbyte: uint8) =
  stream.write(sbyte)

proc writeShort*(stream: StringStream, short: int16) =
  stream.write(short)

proc writeString*(stream: StringStream, `string`: string) =
  stream.write(`string`)

proc writeByteArray*(stream: StringStream, sequence: seq[int8]) =
  for _, `byte` in sequence:
    stream.write(`byte`)