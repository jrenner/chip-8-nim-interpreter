# chip 8 emulator written in Nim
# author: github.com/jrenner


const DEBUG_CYCLE_SLEEP_DISABLED = true

#const CYCLE_TIME: int = int(1000.0 / 60.0)
#const CYCLE_TIME: int = int(1000.0 / 300.0)
#const CYCLE_TIME: int = 1000
const CYCLE_TIME: int = 1

import strformat
import strutils
import tables
import unsigned
import chiputils
import os
import times
import math
import sdl2utils
import random

# Chip8 has 4K total memory
# System memory map:
# 0x000-0x1FF - Chip 8 interpreter (contains font set in emu)
# 0x050-0x0A0 - Used for the built in 4x5 pixel font set (0-F)
# 0x200-0xFFF - Program ROM and work RAM
#
const memSize = 4096
type
    Memory = array[0..memSize-1, uint8]

proc readValues*(memory: Memory) =
    var map = initTable[int, int]()
    for n in 0..memSize-1:
        let value: int = int(memory[n])
        map[value] = map[value] + 1
    log("memory values:")
    for k, v in map:
        log("value: {k:0>2x} -- count: {v:>4}".fmt)


proc viewSection*(memory: Memory, start: int, length: int) =
    log("View memory section 0x{start:0>4X} to 0x{start+(length-1):0>4X}".fmt)
    var ct = 0
    for i in start..(start+length)-1:
        write(stdout, " [{i:0>4X}] {memory[i]:0>2X} |".fmt)
        ct += 1
        if ct mod 8 == 0:
            write(stdout, "\n")
    # guarantee new line at end of output
    if ct mod 8 != 0:
        write(stdout, "\n")


# Chip8 has 15 8-bit general purpose registers named V0,V1..VE
# 16th register is used for a 'carry flag'
type
    Registers = array[0..15, uint8]

proc readValues*(V: Registers) =
    log("Registers:")
    for i, value in V:
        let name =
            if i == 15:
                "CF"
            else:
                "V{i:X}".fmt
        if name == "CF":
            log("Carry Flag:")
        log("[{name}]: {value.int:04X}".fmt)


# The graphics system: The chip 8 has one instruction that draws sprite to the screen.
# Drawing is done in XOR mode and if a pixel is turned off as a result of drawing, the VF register is set.
# This is used for collision detection.
# The graphics of the Chip 8 are black and white and the screen has a total of 2048 pixels (64 x 32).
# This can easily be implemented using an array that hold the pixel state (1 or 0):

const GRAPHICS_WIDTH* = 64
const GRAPHICS_HEIGHT* = 32
const NUM_PIXELS = GRAPHICS_WIDTH * GRAPHICS_HEIGHT
type
    Graphics = array[0..NUM_PIXELS-1, bool]

proc pixelLocation*(g: Graphics, x: int, y: int): uint16 =
    let modX = x mod GRAPHICS_WIDTH
    let modY = y mod GRAPHICS_HEIGHT
    return uint16((modY * GRAPHICS_WIDTH) + modX)

proc setPixel*(g: var Graphics, x: int, y: int, state: bool) =
    let loc = g.pixelLocation(x, y)
    g[loc] = state

proc getPixelState*(g: var Graphics, x: int, y: int): bool =
    let loc = g.pixelLocation(x, y)
    return g[loc]

proc clearGraphics*(g: var Graphics) =
  for item in g.mitems:
    item = false

proc printGraphics*(g: Graphics) =
    var res = ""
    for i in 0..g.len-1:
        if g[i]:
            res.add("#")
        else:
            res.add("_")
        if i mod GRAPHICS_WIDTH >= GRAPHICS_WIDTH - 1:
            res.add("\n")
    echo res

type
    TimerObj = object
        time*: uint8
    Timer* = ref TimerObj not nil


proc tick*(t: Timer) =
    if t.time > 0'u8:
        t.time -= 1

type
    Chip8Obj* = object
        memory*: Memory
        V*: Registers
        gfx*: Graphics
        display*: Display
        drawRequired*: bool
        keyboardPressed: array[16, bool]

        # index register (I) and program counter (PC), value from 0x000 to 0xFFF
        I*, pc*: uint16

        # Interupts and hardware registers.
        # The Chip 8 has none, but there are two timer registers that count at 60 Hz.
        # When set above zero they will count down to zero.
        sound_timer*, delay_timer*: Timer not nil

        # The Chip 8 has a HEX based keypad (0x0-0xF)
        key*: array[0..15, uint8]

        # It is important to know that the Chip 8 instruction set has opcodes
        
        # While the specification don’t mention a stack, you will need to implement
        # one as part of the interpreter yourself. The stack is used to remember the
        # current location before a jump is performed. So anytime you perform a jump or
        # call a subroutine, store the program counter in the stack before proceeding.
        # The system has 16 levels of stack and in order to remember which level of the
        # stack is used, you need to implement a stack pointer (sp).
        stack*: array[0..15, uint16]
        sp*: uint16 # stack pointer

        # keep track of program size for debugging
        programSize*: int
        programStep*: int
        
    Chip8* = ref Chip8Obj not nil


proc createChip8*(): Chip8 =
    let c = Chip8(sound_timer: Timer(), delay_timer: Timer())
    c.drawRequired = false
    return c

proc loadSprites(c: Chip8) =
    ## load sprites into memory
    log "loading sprites into memory.."
    let sprites = [
        0xF0, 0x90, 0x90, 0x90, 0xF0, # 0
        0x20, 0x60, 0x20, 0x20, 0x70, # 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
        0x90, 0x90, 0xF0, 0x10, 0x10, # 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
        0xF0, 0x10, 0x20, 0x40, 0x40, # 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, # A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
        0xF0, 0x80, 0x80, 0x80, 0xF0, # C
        0xE0, 0x90, 0x90, 0x90, 0xE0, # D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
        0xF0, 0x80, 0xF0, 0x80, 0x80, # F
    ]
    for i in 0..sprites.len - 1:
        c.memory[0x050 + i] = uint8(sprites[i])

proc drawGraphics*(c: Chip8) =
    for y in 0..GRAPHICS_HEIGHT-1:
        for x in 0..GRAPHICS_WIDTH-1:
            let pixelState = c.gfx[c.gfx.pixelLocation(x, y)]
            if pixelState:
                #echo x, ", ", y
                c.display.drawPixel(x, y)
    c.display.draw
    #c.gfx.printGraphics()
    #sleep(1000)

# utilities

proc spriteLocation(x: int): uint16 =
    return uint16(0x050 + x * 5)

proc printSprite*(c: Chip8, sp: int) =
    let loc: uint16 = uint16(spriteLocation(sp))
    var result : array[0..7, char]
    for i in loc..loc+4:
        let b: uint8 = c.memory[i]
        for i in 0'u8..7'u8:
            let i_reversed = 7'u8 - i
            if ((1'u8 shl i_reversed) and b) != 0:
                result[i] = '#'
            else:
                result[i] = '_'
        echo result

proc getHexDigit*(n_u16: uint16, position: int = 1): int =
    let n: int = int(n_u16)
    assert position >= 1 and position <= 4
    var digit: int
    case position
    of 1:
        digit = n and 0xF000
    of 2:
        digit = n and 0x0F00
    of 3:
        digit = n and 0x00F0
    of 4:
        digit = n and 0x000F
    else:
        log("failed to get hex digit for position: {position}, n: {n}".fmt)
        discard
    #echo "n_u16:{:X}, n:{:X}, digit: {:X}".fmt(n_u16, n, digit)
    digit

proc registerX(opcode: uint16): int =
    let hexDigit = opcode.getHexDigit(2)
    let res = hexDigit shr 8
    #echo "registerX, opcode is: {:X}, hexDigit: {:X}, regX: {:X}".fmt(opcode, hexDigit, res)
    return int(res)

proc registerY(opcode: uint16): int =
    let hexDigit = opcode.getHexDigit(3)
    let res = hexDigit shr 4
    #echo "registerY, opcode is: {:X}, hexDigit: {:X}, regY: {:X}".fmt(opcode, hexDigit, res)
    return res

proc nibble(opcode: uint16, position: int): int =
    let digit = opcode.getHexDigit(position)
    digit shr (16 - position * 4)

proc address(opcode: uint16): uint16 =
    uint16(opcode and 0x0FFF)

proc kkbyte(opcode: uint16): uint8 =
    uint8(opcode and 0x00FF)

# handlers

proc JP(c: Chip8, address: uint16) =
    ## Jump to location nnn.
    c.pc = address

proc CALL(c: Chip8, address: uint16) =
    ## Call subroutine at nnn
    c.sp = (c.sp + 1) mod 16
    c.stack[c.sp] = c.pc
    c.pc = address

proc SEVx(c: Chip8, x: int, kk: uint8) =
    if c.V[x] == kk:
        log("skipping next instruction")
        c.pc += 2

proc SNEVx(c: Chip8, x: int, kk: uint8) =
    if c.V[x] != kk:
        log("skipping next instruction")
        c.pc += 2

proc SEVxVy(c: Chip8, x: int, y: int) =
    if c.V[x] == c.V[y]:
        log("skipping next instruction")
        c.pc += 2

proc LDVx(c: Chip8, x: int, kk: uint8) =
    c.V[x] = kk

proc ADDVx(c: Chip8, x: int, kk: uint8) =
    c.V[x] += kk
    #c.V.readValues


proc LDVxVy(c: Chip8, x: int, y: int) =
    c.V[x] = c.V[y]

proc ORVxVy(c: Chip8, x: int, y: int) =
    c.V[x] = c.V[x] or c.V[y]

proc ANDVxVy(c: Chip8, x: int, y: int) =
    c.V[x] = c.V[x] and c.V[y]

proc XORVxVy(c: Chip8, x: int, y: int) =
    c.V[x] = c.V[x] xor c.V[y]

proc ADDVxVy(c: Chip8, x: int, y: int) =  
    let sum: int = int(c.V[x]) + int(c.V[y])
    if sum > 255:
        c.V[0xF] = 1
    else:
        c.V[0xF] = 0
    c.V[x] = c.V[x] + c.V[y]

proc SUBVxVy(c: Chip8, x: int, y: int) =
    if c.V[x] > c.V[y]:
      c.V[0xF] = 1
    else:
      c.V[0xF] = 0
    c.V[x] = c.V[x] - c.V[y]


proc SHRVx(c: Chip8, x: int) =
    ## Set Vx = Vx SHR 1.
    ## If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0.
    ## Then Vx is divided by 2.
    if (c.V[x] and 0x01) == 1:
        c.V[0xF] = 1
    else:
        c.V[0xF] = 0
    c.V[x] = uint8(c.V[x] div 2)
    
proc SHLVx(c: Chip8, x: int) =
    ## Set Vx = Vx SHL 1.
    ## If the most-significant bit of Vx is 1, then VF is set to 1,
    ## otherwise to 0. Then Vx is multiplied by 2.
    if (c.V[x] and 0b1000_0000) == 0b1000_000:
        c.V[0xF] = 1
    else:
        c.V[0xF] = 0
    c.V[x] *= 2


proc SUBNVxVy(c: Chip8, x: int, y: int) =
    ## Set Vx = Vy - Vx, set VF = NOT borrow.
    ## If Vy > Vx, then VF is set to 1, otherwise 0.
    ## Then Vx is subtracted from Vy, and the results stored in Vx.
    if c.V[y] > c.V[x]:
        c.V[0xF] = 1
    else:
        c.V[0xF] = 0
    c.V[x] = c.V[y] - c.V[x]

proc SNEVxVy(c: Chip8, x: int, y: int) =
    if c.V[x] != c.V[y]:
        log("skipping next instruction")
        c.pc += 2

proc LDI(c: Chip8, address: uint16) =
    c.I = address

proc JPV0(c: Chip8, address: uint16) =
    c.pc = address + c.V[0]

proc RNDVx(c: Chip8, x: int, kk: uint8) =
    ## Set Vx = random byte AND kk.
    ## The interpreter generates a random number from 0 to 255, 
    ## which is then ANDed with the value kk. The results are stored in Vx.
    ## See instruction 8xy2 for more information on AND.
    let r1 = random(256)
    let r2 = uint8(r1 mod 256) and kk
    log("{r1} mod 256 & {kk} = {r2}".fmt)
    c.V[x] = r2
    #echo "RANDOM register: {c.V[x]}".fmt
    

proc DRW(c: Chip8, x: int, y: int, nibble: int) =
    ## Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.
    ##
    ## The interpreter reads n bytes from memory, starting at the address stored in I.
    ## These bytes are then displayed as sprites on screen at coordinates (Vx, Vy).
    ## Sprites are XORed onto the existing screen. If this causes any pixels to be erased,
    ## VF is set to 1, otherwise it is set to 0. If the sprite is positioned so part
    ## of it is outside the coordinates of the display, it wraps around to the opposite
    ## side of the screen. See instruction 8xy3 for more information on XOR, and section 2.4,
    ## Display, for more information on the Chip-8 screen and sprites.

    #echo "DRAW X: {}, Y: {}".fmt(x, y)
    var any_pixels_erased = false
    c.drawRequired = true
    for i in 0..nibble - 1:
        let spriteByte = c.memory[c.I + uint16(i)]
        for j in 0..7:
            # mirror everythiung horizationally to get it correct
            # i.e. don't print R facing left
            let pixOffsetX = 7 - j
            let mask = uint8(1 shl pixOffsetX)
            #if b != 0:
            #    echo "mask:   {}".fmt(int(mask).toBin(8))
            #    echo "b:      {}".fmt(int(b).toBin(8))
            #    echo "result: {}".fmt(int(b and mask).toBin(8))
            let toggle = (spriteByte and mask) != 0
            if toggle:
                let currentState = c.gfx.getPixelState(x+j, y+i)
                let pixelState = not currentState
                if pixelState == false:
                  any_pixels_erased = true 
                #echo "set pix state for ({}, {}): {}".fmt(x+j, y+i, pixelState)
                c.gfx.setPixel(x+j, y+i, pixelState)
    if any_pixels_erased:
      c.V[0xF] = 1
    else:
      c.V[0xF] = 0


proc isKeyPressed*(c: Chip8, keynum: int): bool =
  result = c.keyboardPressed[keynum]

proc keyDown*(c: Chip8, keynum: int) =
  log("CHIP8 KeyDown: {keynum} - {keynum.hex}".fmt, level=trace)
  c.keyboardPressed[keynum] = true

proc keyUp*(c: Chip8, keynum: int) =
  c.keyboardPressed[keynum] = false

proc resetKeyboard*(c: Chip8) =
  for i in 0..c.keyboardPressed.len - 1:
    c.keyUp(i)

proc printKeyboard*(c: Chip8) =
  for i in 0..c.keyboardPressed.len - 1:
    echo "key {i}: {c.keyboardPressed[i]}".fmt

proc SKPVx(c: Chip8, x: int) =
    ## Skip next instruction if key with the value of Vx is pressed.
    ## Checks the keyboard, and if the key corresponding to the value
    ## of Vx is currently in the down position, PC is increased by 2.
    var should_skip = c.isKeyPressed(x)
    if should_skip:
      log("skipping next instruction")
      c.pc += 2

proc SKNPVx(c: Chip8, x: int) =
    ## Skip next instruction if key with the value of Vx is not pressed.
    ## Checks the keyboard, and if the key corresponding to the value of Vx
    ## is currently in the up position, PC is increased by 2.
    var should_skip = not c.isKeyPressed(x)
    #log("register: {x} should_skip: {should_skip}".fmt)
    #c.printKeyboard()
    #sleep(1000)
    if should_skip:
      log("skipping next instruction")
      c.pc += 2

proc printDelayTimer(c: Chip8) =
  echo "delay_timer: {c.delay_timer.time}".fmt

proc LDVxDT(c: Chip8, x: int) =
    ## Set Vx = delay timer value
    c.V[x] = c.delay_timer.time
    c.printDelayTimer

proc LDVxK(c: Chip8, x: int) =
    ## Wait for a key press, store the value of the key in Vx.
    ## All execution stops until a key is pressed, then the value of that key is stored in Vx.
    block main_loop:
      while true:
        #echo "LDvxK TEMPORARY DEBUG IMPLEMENTATION"
        let res_list = processKeys()
        for res in res_list:
          let evt_kind = res[0]
          let res_str = res[1]
          #echo "evt_kind: {evt_kind}, res_str: {res_str}".fmt
          let keycode = getKeycode(res_str)
          if keycode != -1:
            c.V[x] = keycode.uint8
            break main_loop
        sleep(500)

proc LDDTVx(c: Chip8, x: int) =
    ## Set delay timer value = Vx
    c.delay_timer.time = c.V[x]
    c.printDelayTimer

proc LDSTVx(c: Chip8, x: int) =
    ## Set sound timer value = Vx
    c.sound_timer.time = c.V[x]
    discard

proc ADDIVx(c: Chip8, x: int) =
    ## Set I = I + Vx
    c.I = c.I + c.V[x]
    discard
    
proc LDFVx(c: Chip8, x: int) =
    ## Set I = location of sprite for digit Vx
    c.I = c.I + spriteLocation(x)
    discard
    
proc LDBVx(c: Chip8, x: int) =
    ## Store BCD representation of Vx in memory locations I, I+1, and I+2.
    ## The interpreter takes the decimal value of Vx, and places the hundreds
    ## digit in memory at location in I, the tens digit at location I+1,
    ## and the ones digit at location I+2.
    let num = c.V[x]
    c.memory[c.I] = (num div 100)
    c.memory[c.I+1] = (num div 10) mod 10
    c.memory[c.I+2] = (num mod 100) mod 10
    
proc LDIVx(c: Chip8, x: int) =
    ## Store registers V0 through Vx in memory starting at location I.
    ## The interpreter copies the values of registers V0 through Vx into memory,
    ## starting at the address in I.
    for i in 0..x:
        c.memory[c.I + uint16(i)] = c.V[i]


proc LDVxI(c: Chip8, x: int) =
    ## Read registers V0 through Vx from memory starting at location I.
    ## The interpreter reads values from memory starting at location I into registers V0 through Vx.
    for n in 0..x:
        c.V[n] = c.memory[c.I + uint16(n)]


proc CLS(c: Chip8) =
    c.gfx.clearGraphics()
    c.drawRequired = true


proc RET(c: Chip8) =
    c.pc = c.stack[c.sp]
    c.sp = (c.sp - 1) mod 16

proc SYS(c: Chip8) =
    log("SYS not implemented", level = warning)

const PROGRAM_START: uint16 = 0x0200

proc initialize*(c: Chip8) =
    # init registers and memory
    for i in 0..memSize-1:
        c.memory[i] = 0
    for i in 0..c.V.len() - 1:
        c.V[i] = 0
    c.loadSprites()
    c.pc = PROGRAM_START
    # put font in memory
    #
    # graphics?

# not sure if this is correct
const MAX_PROGRAM_SIZE: uint16 = 4096'u16 - PROGRAM_START

proc loadProgram*(c: Chip8, filename: string) =
    let fin = open(filename)
    var buf : array[0..4095, uint8]
    let read = fin.readBytes(buf, start=0, len=4096)
    assert uint16(read) < MAX_PROGRAM_SIZE
    for i in 0..read-1:
        let j = i + 0x0200 # program starts at 512 bytes
        c.memory[j] = buf[i]
    fin.close()
    log("LOAD PROGRAM: '{filename}' ({read} bytes)".fmt)
    #c.programSize = read div 2



proc fetchOpCode(c: Chip8): uint16 =
    let op_byte1 = c.memory[c.pc]
    let op_byte2 = c.memory[c.pc + 1]
    let opcode: uint16 = (uint16(op_byte1) shl 8) or op_byte2
    # log("op1: {:X}, op2: {:X}, opcode: {:X}".fmt(op_byte1, op_byte2, opcode)
    c.pc += 2
    return opcode

proc emulateCycle*(c: Chip8) =
    c.programStep += 1
    if c.programSize > 0 and c.programStep > c.programSize:
        log("exceed program size: {c.programSize} -- EXIT".fmt)
        quit(1)
    let orig_pc = c.pc
    when not DEBUG_CYCLE_SLEEP_DISABLED:
      sleep(CYCLE_TIME)
    # fetch opcode
    let opcode = c.fetchOpCode
    var opName: string

    # decode
    case opcode and 0xF000
    of 0x1000:
        opName = "JP addr"
        c.JP(opcode.address)
    of 0x2000:
        opName = "CALL addr"
        c.CALL(opcode.address)
    of 0x3000:
        opName = "SE Vx, byte"
        c.SEVx(opcode.registerX, opcode.kkbyte)
    of 0x4000:
        opName = "SNE Vx, byte"
        c.SNEVx(opcode.registerX, opcode.kkbyte)
    of 0x5000:
        opName = "SE Vx, Vy"
        c.SEVxVy(opcode.registerX, opcode.registerY)
    of 0x6000:
        opName = "LD Vx, byte"
        c.LDVx(opcode.registerX, opcode.kkbyte)
    of 0x7000:
        opName = "ADD Vx, byte"
        c.ADDVx(opcode.registerX, opcode.kkbyte)
    of 0x8000:
        case opcode and 0x000F
        of 0x0:
            opName = "LD Vx, Vy"
            c.LDVxVy(opcode.registerX, opcode.registerY)
        of 0x1:
            opName = "OR Vx, Vy"
            c.ORVxVy(opcode.registerX, opcode.registerY)
        of 0x2:
            opName = "AND Vx, Vy"
            c.ANDVxVy(opcode.registerX, opcode.registerY)
        of 0x3:
            opName = "XOR Vx, Vy"
            c.XORVxVy(opcode.registerX, opcode.registerY)
        of 0x4:
            opName = "ADD Vx, Vy"
            c.ADDVxVy(opcode.registerX, opcode.registerY)
        of 0x5:
            opName = "SUB Vx, Vy" 
            c.SUBVxVy(opcode.registerX, opcode.registerY)
        of 0x6:
            opName = "SHR Vx {, Vy}"
            c.SHRVx(opcode.registerX)
        of 0x7:
            opName = "SUBN Vx, Vy"
            c.SUBNVxVy(opcode.registerX, opcode.registerY)
        of 0xE:
            opName = "SHL Vx {, Vy}"
            c.SHLVx(opcode.registerX)
        else:
            discard
    of 0x9000:
        opName = "SNE Vx, Vy"
        c.SNEVxVy(opcode.registerX, opcode.registerY)
    of 0xA000:
        opName = "LD I, addr"
        c.LDI(opcode.address)
    of 0xB000:
        opName = "JP V0, addr"
        c.JPV0(opcode.address)
    of 0xC000:
        opName = "RND Vx, byte"
        c.RNDVx(opcode.registerX, opcode.kkbyte)
    of 0xD000:
        opName = "DRW Vx, Vy, nibble"
        let posX = int(c.V[opcode.registerX])
        let posY = int(c.V[opcode.registerY])
        c.DRW(posX, posY, opcode.nibble(4))
    of 0xE000:
        case opcode and 0x00FF
        of 0x009E:
            opName = "SKP Vx"
            c.SKPVx(opcode.registerX)
        of 0x00A1:
            opName = "SKNP Vx"
            c.SKNPVx(opcode.registerX)
        else:
            discard
    of 0xF000:
        case opcode and 0x00FF
        of 0x07:
            opName = "LD Vx, DT"
            c.LDVxDT(opcode.registerX)
        of 0x0A:
            opName = "LD Vx, K"
            c.LDVxK(opcode.registerX)
        of 0x15:
            opName = "LD DT, Vx"
            c.LDDTVx(opcode.registerX)
        of 0x18:
            opName = "LD ST, Vx"
            c.LDSTVx(opcode.registerX)
        of 0x1E:
            opName = "ADD I, Vx"
            c.ADDIVx(opcode.registerX)
        of 0x29:
            opName = "LD F, Vx"
            c.LDFVx(opcode.registerX)
        of 0x33:
            opName = "LD B, Vx"
            c.LDBVx(opcode.registerX)
        of 0x55:
            opName = "LD [I], Vx"
            c.LDIVx(opcode.registerX)
        of 0x65:
            opName = "LD Vx, [I]"
            c.LDVxI(opcode.registerX)
        else:
            discard         
    else: # anything not matching 0xF000
        case opcode
        of 0x00E0:
            # clear the screen
            opName = "CLS"
            c.CLS()
        of 0x00EE:
            # return from sub-routine
            opName = "RET"
            c.RET()
        else:
            if (opcode and 0xF000) == 0:
                # jump to a machine code routine at NNN
                opName = "SYS"
                c.SYS()
           
    if opName == nil:
        proc fmtLine() =
            log("---------------------------------------")
        log("")
        fmtLine()
        log("ERROR: UNKNOWN opcode: {opcode.hex}".fmt)
        fmtLine()
        log("")
        quit(QuitFailure)
    assert opName != nil
    if c.drawRequired:
        c.drawGraphics
        c.drawRequired = false
    log("[@{orig_pc.hex} STEP: {c.programStep}] opcode [{opcode.hex}]: {opName}".fmt, level=trace)

    # execute
    
    # update timers
    c.delay_timer.tick
    c.sound_timer.tick
    #c.printDelayTimer
    
