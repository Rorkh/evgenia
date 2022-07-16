# A Nim library for parsing NBT file format used in Minecraft
# https://wiki.vg/NBT was used as a reference to the format

# Credits
# https://github.com/Antelsa/Antelsa/blob/dev/src/nimnbt.nim
# https://github.com/Antelsa/Antelsa/blob/dev/LICENSE

import streams, endians, tables, json
import zippy

type
  TagKind* {.pure.} = enum
    End, Byte, Short, Int, Long, Float, Double, ByteArray,
    String, List, Compound, IntArray, LongArray

  Tag* = object
    name*: string
    case kind*: TagKind
    of End: discard
    of Byte: byteVal*: int8
    of Short: shortVal*: int16
    of Int: intVal*: int32
    of Long: longVal*: int64
    of Float: floatVal*: float32
    of Double: doubleVal*: float64 # XXX: this might be incorrect
    of ByteArray: bytes*: seq[int8]
    of String: str*: string
    of List:
      typ*: TagKind           ## List type
      values*: seq[Tag]
    of Compound: compound*: Table[string, Tag]
    of IntArray: ints*: seq[int32]
    of LongArray: longs*: seq[int64]


const isLittle = system.cpuEndian == littleEndian

template endian(x: untyped): untyped =
  ## A convenient template to swap endianness of variables to big endian
  # When we are on big-endian platform, we don't need to change endianness
  when not isLittle:
    x
  else:
    var val = x
    when isLittle:
      when sizeof(x) == 2:
        bigEndian16(addr val, addr val)
      elif sizeof(x) == 4:
        bigEndian32(addr val, addr val)
      elif sizeof(x) == 8:
        bigEndian64(addr val, addr val)
      else: discard
    val


proc readString(s: Stream): string {.inline.} =
  # Thankfully strings in NBT are UTF-8 (same as in Nim)
  let len = endian(s.readUint16())
  if len == 0: ""
  else: s.readStr(int(len))


proc parseNbtInternal(s: Stream, tagKind = End, parseName = true): Tag =
  result = Tag(kind: if tagKind == End: TagKind(s.readUint8()) else: tagKind)
  if result.kind == End: return

  if parseName: result.name = s.readString()
  case result.kind
  of End: return
  of Byte:
    result.byteVal = s.readInt8()
  of Short:
    result.shortVal = endian(s.readInt16())
  of Int:
    result.intVal = endian(s.readInt32())
  of Long:
    result.longVal = endian(s.readInt64())
  of Float:
    result.floatVal = endian(s.readFloat32())
  of Double:
    result.doubleVal = endian(s.readFloat64())
  of ByteArray:
    let size = endian(s.readInt32())
    var i = 0
    result.bytes = newSeqOfCap[int8](size)

    while i < size:
      result.bytes.add(s.readInt8())
      inc(i)
  of String:
    result.str = s.readString()
  of List:
    result.typ = TagKind(s.readUint8())
    let size = endian(s.readInt32())
    var i = 0
    result.values = newSeqOfCap[Tag](size)

    while i < size:
      # Tags in lists don't have names at all
      result.values.add(s.parseNbtInternal(result.typ, parseName = false))
      inc(i)
  of Compound:
    result.compound = initTable[string, Tag]()
    while true:
      var nextTag = s.parseNbtInternal()
      if nextTag.kind == End: break
      result.compound[nextTag.name] = nextTag
  of IntArray:
    let size = endian(s.readInt32())
    var i = 0
    result.ints = newSeqOfCap[int32](size)

    while i < size:
      result.ints.add(endian(s.readInt32()))
      inc(i)
  of LongArray:
    let size = endian(s.readInt32())
    var i = 0
    result.longs = newSeqOfCap[int64](size)

    while i < size:
      result.longs.add(endian(s.readInt64()))
      inc(i)


proc parseNbt*(s: Stream): Tag =
  ## Parses NBT data structure from the stream *s*.
  ##
  ## *s* may be compressed via gzip/zlib
  result = parseNbtInternal(s)


proc parseNbtFile*(filename: string): Tag =
  ## Parses NBT data structure from the file *filename*.
  ##
  ## File may be compressed via gzip/zlib
  let data = uncompress(readFile(filename))

  let stream = newStringStream()
  stream.write(data)
  stream.setPosition(0)

  result = parseNbtInternal(stream)


proc parseNbt*(s: string): Tag =
  ## Parses NBT data structure from the string *s*
  ##
  ## *s* may be compressed via gzip/zlib
  let stream = newStringStream()
  stream.write(uncompress(s))
  stream.setPosition(0)

  result = parseNbtInternal(stream)


template `[]`*(t: Tag, name: string): Tag =
  ## A convenient proc to access tag in the compound
  assert t.kind == Compound
  t.compound[name]


template `in`*(t: Tag, name: string): bool =
  ## Check if an item with *name* is in the compound
  assert t.kind == Compound
  name in t.compound


proc len*(t: Tag): int =
  ## A convenient proc to access length of some container types
  ## Works for ByteArray, String, List, Compound, IntArray, LongArray
  case t.kind
  of ByteArray: t.bytes.len
  of String: t.str.len
  of List: t.values.len
  of Compound: t.compound.len
  of IntArray: t.ints.len
  of LongArray: t.longs.len
  else: raise newException(ValueError, "invalid tag kind!")

proc toJson*(s: Tag): JsonNode =
  ## Converts an NBT tag to the JSON for printing/serialization
  case s.kind
    of Byte:
      result = newJInt(s.byteVal)
    of Short:
      result = newJInt(s.shortVal)
    of Int:
      result = newJInt(s.intVal)
    of Long:
      result = newJInt(s.longVal)
    of Float:
      result = newJFloat(s.floatVal)
    of Double:
      result = newJFloat(s.doubleVal)
    of ByteArray:
      result = newJArray()
      for itm in s.bytes:
        result.add(newJInt(itm))
    of String:
      result = newJString(s.str)
    of List:
      result = newJArray()
      for itm in s.values:
        result.add(toJson(itm))
    of Compound:
      result = newJObject()
      for k, v in s.compound:
        result.add(k, toJson(v))
    of IntArray:
      result = newJArray()
      for itm in s.bytes:
        result.add(newJInt(itm))
    of LongArray:
      var arr = newJArray()
      for itm in s.bytes:
        arr.add(newJInt(itm))
    of End:
      return

proc `$`*(t: Tag): string =
  ## Converts Tag to a string for easier debugging/visualising
  $toJson(t).pretty()


proc writeString(strm: StringStream, str: string) =
  strm.write(endian(str.len.uint16))
  strm.write(str)

proc toNbtInternal(t: Tag, strm: StringStream, withName: bool = true, kind: TagKind = End) =
  var k = if kind == End: t.kind else: kind
  if (kind == End):
    strm.write(t.kind.uint8)
  if withName: strm.writeString(t.name)

  case k
  of End: return
  of Byte:
    strm.write(t.byteVal)
  of Short:
    strm.write(endian(t.shortVal))
  of Int:
    strm.write(endian(t.intVal))
  of Long:
    strm.write(endian(t.longVal))
  of Float:
    strm.write(endian(t.floatVal))
  of Double:
    strm.write(endian(t.doubleVal))
  of ByteArray:
    strm.write(endian(t.bytes.len.uint32)) # size
    for b in t.bytes:
      strm.write(endian(b.int8))
  of String:
    strm.writeString(t.str)
  of List:
    strm.write(endian(t.typ.uint8)) # type
    strm.write(endian(t.values.len.uint32)) # size
    for v in t.values:
      toNbtInternal(v, strm, false, t.typ)
  of Compound:
    for k, v in t.compound.pairs:
      toNbtInternal(v, strm)
    strm.write(End.uint8) # end
  of IntArray:
    strm.write(endian(t.ints.len.uint32)) # size
    for i in t.ints:
      strm.write(endian(i.int32))
  of LongArray:
    strm.write(endian(t.longs.len.uint32)) # size
    for l in t.longs:
      strm.write(endian(l.int64))


proc toNbt*(t: Tag, withoutCompress: bool = false): string =
  var strm = newStringStream()
  t.toNbtInternal(strm)
  strm.setPosition 0
  if (withoutCompress):
    result = strm.readAll
  else:
    result = compress(strm.readAll)
  strm.close()


proc TAG_End*(): Tag =
  result = Tag(kind: End)

proc TAG_Byte*(name: string = "", val: int8 = 0): Tag =
  result = Tag(kind: Byte, name: name, byteVal: val)

proc TAG_Short*(name: string = "", val: int16 = 0): Tag =
  result = Tag(kind: Short, name: name, shortVal: val)

proc TAG_Int*(name: string = "", val: int32 = 0): Tag =
  result = Tag(kind: Int, name: name, intVal: val)

proc TAG_Long*(name: string = "", val: int64 = 0): Tag =
  result = Tag(kind: Long, name: name, longVal: val)

proc TAG_Float*(name: string = "", val: float32 = 0.0): Tag =
  result = Tag(kind: Float, name: name, floatVal: val)

proc TAG_Double*(name: string = "", val: float64 = 0.0): Tag =
  result = Tag(kind: Double, name: name, doubleVal: val)

proc TAG_Byte_Array*(name: string = "", val: seq[int8] = newSeq[int8]()): Tag =
  result = Tag(kind: ByteArray, name: name, bytes: val)

proc TAG_String*(name: string = "", val: string = ""): Tag =
  result = Tag(kind: String, name: name, str: val)

proc TAG_List*(name: string = "", typ: TagKind = End, val: seq[Tag] = newSeq[Tag]()): Tag =
  result = Tag(kind: List, name: name, values: val)
  if val.len == 0 and typ == End:
    result.typ = End 
  else: 
    if (typ != End):
      result.typ = typ
    else:
      result.typ = val[0].kind

proc TAG_Compound*(name: string = "", tags: seq[Tag] = newSeq[Tag]()): Tag =
  result = Tag(kind: Compound, name: name)
  for tag in tags:
    result.compound[tag.name] = tag

proc TAG_Int_Array*(name: string = "", val: seq[int32] = newSeq[int32]()): Tag =
  result = Tag(kind: IntArray, name: name, ints: val)

proc TAG_Long_Array*(name: string = "", val: seq[int64] = newSeq[int64]()): Tag =
  result = Tag(kind: LongArray, name: name, longs: val)