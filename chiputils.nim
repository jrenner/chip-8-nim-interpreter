import strutils
import strfmt
import os

proc hex*(n: Natural, length: int = 0): string =
    if n < 0:
        "NEGATIVE: {:X}".fmt(n)
    elif n < 0xFF:
        "{:0>2X}".fmt(n)
    elif n < 0xFFFF:
        "{:0>4X}".fmt(n)
    elif n < 0xFFFFFF:
        "{:0>6X}".fmt(n)
    elif n < 0xFFFFFFFF:
        "{:0>8X}".fmt(n)
    else:
        "{:X}".fmt(n)

type
    DebugLevel* = enum
        trace, debug, info, warning, error


var debugLevel* = trace

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
    echo "converted {} .prg files to .ch8".fmt(count)
        

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
    
