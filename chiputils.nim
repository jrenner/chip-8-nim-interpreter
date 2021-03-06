import strutils
import strformat
import os

type
  DebugLevel* = enum
      trace, debug, info, warning, error


var debugLevel* = trace

const keyMap* = [
  "1", "2", "3", "4",
  "Q", "W", "E", "R",
  "A", "S", "D", "F",
  "Z", "X", "C", "V"
]

proc getKeycode*(s: string): int =
  result = keyMap.find(s)

proc hex*(n: Natural, length: int = 0): string =
    if n < 0:
        "NEGATIVE: {n:X}".fmt
    elif n < 0xFF:
        "{n:0>2X}".fmt
    elif n < 0xFFFF:
        "{n:0>4X}".fmt
    elif n < 0xFFFFFF:
        "{n:0>6X}".fmt
    elif n < 0xFFFFFFFF:
        "{n:0>8X}".fmt
    else:
        "{n:X}".fmt


proc log*(msg: string, level: DebugLevel = trace) =
    if level >= debugLevel:
        echo msg
    

proc convertTextToProgram(dummyPath: string, convertedPath: string) =
    ## This function will convert a sort of chip 8 source to bytes
    ## i.e. source written as "6504" will be converted to its hex bytes
    ## two bytes per line
    #echo "convert: {}".fmt(dummyPath)
    let dummy = open(dummyPath)
    let converted = open(convertedPath, fmWrite)
    var bytes : array[0..4095, uint8]
    var i = 0
    while true:
        try:
            #write(stdout, "BYTE: ", i)
            let line = dummy.readLine().strip()
            if line.startswith("#") or line.len() == 0:
                continue
            else:
                let firstByte: uint8 = uint8(line[0..1].parseHexInt)
                let secondByte: uint8 = uint8(line[2..3].parseHexInt)
                bytes[i] = firstByte
                bytes[i+1] = secondByte
                i += 2
                #echo "[{}] {}, first: {}, second: {}".fmt(line.len, line, firstByte.hex, secondByte.hex)
        except IOError:
            let msg = getCurrentExceptionMsg()
            if not msg.contains("EOF"):
                echo "IOError: " & getCurrentExceptionMsg()
                quit(QuitFailure)
            break
    #echo "bytes converted: {}".fmt(i)
    let written = converted.writeBytes(bytes, 0, i)
    #echo "wrote {} bytes to {}".fmt(written, convertedPath)
    converted.close()
    dummy.close()

proc convertAllPrograms*() =
    var count = 0
    for kind, filename in walkDir("programs/test"):
        if kind == pcFile:
           let f = filename.splitFile()
           if f.ext == ".prg":
               count += 1
               let converted = joinPath(f.dir, f.name & ".ch8")
               #echo "writing converted program: ", converted
               convertTextToProgram(filename, converted)
    echo "converted {count} .prg files to .ch8".fmt
        

if isMainModule:
    # echo 255.hex
    # echo 255'u8.hex
    # echo uint16(65535).hex
    # echo 314958390458'i64.hex
    convertAllPrograms()
    

proc getFileSizeInBytes*(filename: string): int =
    let f = open(filename)
    # shouldn't be using this on anything larger than 2^16 bytes
    var hugeBuf: array[0..0xFFFF, uint8]
    let sz = f.readBytes(hugeBuf, 0, 0xFFFF)
    f.close()
    return sz
    
