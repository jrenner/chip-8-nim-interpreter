import chip8
import strformat
import chiputils
import times
import strutils
import sdl2utils
import os

const FALLBACK_DEBUG_PROGRAM = false

var chip: Chip8 = createChip8()

proc initialize() =
    let programName = "zero"
    var program: string
    if paramCount() > 0:
        program = paramStr(1)
    elif FALLBACK_DEBUG_PROGRAM:
        program = "programs/{programName}.ch8".fmt
        echo "using debug fallback program: {program}".fmt
    else:
        echo "supply path to chip8 program as command argument"
        quit(QuitFailure)
    chip.initialize()
    echo "program: {program}".fmt
    chip.loadProgram("{program}".fmt)
  
var pause* = false

proc mainLoop() =
    while true:
        chip.emulateCycle
        if pause:
            while pause:
                case processKeys()
                of "pause":
                    pause = not pause
                    break
                of "space":
                    # will run one step but remain paused
                    break
                of "quit":
                    echo "USER QUIT"
                    quit(QuitSuccess)
                else:
                    sleep(100)
        let res = processKeys()
        case res
        of "pause":
            echo "toggle pause"
            pause = not pause
            write(stdout, "PAUSED (press any key): ")
        of "quit":
            echo "USER QUIT"
            quit(QuitSuccess)
        else:
            discard


#         if chip.drawFlag:
#             drawGraphics()
# 
#         chip.setKeys()

initialize()
mainLoop()
