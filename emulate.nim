import chip8
import strformat
import chiputils
import times
import strutils
import sdl2utils
import os
import sdl2

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

let keyMap = [
  "1", "2", "3", "4",
  "Q", "W", "E", "R",
  "A", "S", "D", "F",
  "Z", "X", "C", "V"
]

proc mainLoop() =
    while true:
        chip.emulateCycle
        if pause:
            while pause:
                for res in processKeys():
                  if res[0] == KeyDown:
                    case res[1]:
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
        for res in processKeys():
          echo "KEY RESULTS: ", res
          let evt_kind: EventType = res[0]
          let res_str = res[1]
          case res_str:
          of "pause":
              echo "toggle pause"
              pause = not pause
              write(stdout, "PAUSED (press any key): ")
          of "quit":
              echo "USER QUIT"
              quit(QuitSuccess)
          else:
            if res_str in keyMap:
              let idx = keyMap.find(res_str)
              if evt_kind == KeyDown:
                chip.keyDown(idx)
              elif evt_kind == KeyUp:
                chip.keyUp(idx)
              else:
                echo "unhandled event type: ", evt_kind
              #echo "RES: {res_str}, IDX: {idx}".fmt
              #sleep(1000)
            else:
              discard


#         if chip.drawFlag:
#             drawGraphics()
# 
#         chip.setKeys()

initialize()
mainLoop()
