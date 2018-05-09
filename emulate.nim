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
var lastPauseStep = 0



proc mainLoop() =
    while true:
        chip.emulateCycle
        if pause:
            block pause_loop:
              while pause:
                for res in processKeys():
                  if res[0] == KeyDown:
                    case res[1]:
                    of "pause":
                      pause = false
                      break
                    of "space":
                      # will run one step but remain paused
                      echo "break pause"
                      break pause_loop
                    of "quit":
                      echo "USER QUIT"
                      quit(QuitSuccess)
                    else:
                      sleep(100)
        else:
          for res in processKeys():
            echo "KEY RESULTS: ", res
            let evt_kind: EventType = res[0]
            let res_str = res[1]
            if evt_kind == KeyDown:
              case res_str:
              of "pause":
                  if chip.programStep - lastPauseStep >= 10:
                    pause = true
                    lastPauseStep = chip.programStep
                    write(stdout, "PAUSED (press any key): ")
                    break
              of "quit":
                  echo "USER QUIT"
                  quit(QuitSuccess)
              else:
                if res_str in keyMap:
                  let key_log_level = trace
                  let idx = getKeycode(res_str)
                  if evt_kind == KeyDown:
                    #log("keydown: {res_str}".fmt, level=key_log_level)
                    chip.keyDown(idx)
                  elif evt_kind == KeyUp:
                    #log("keyup: {res_str}".fmt, level=key_log_level)
                    chip.keyUp(idx)
                  else:
                    discard
                    #log("unhandled event type: {evt_kind}".fmt, level=key_log_level)
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
