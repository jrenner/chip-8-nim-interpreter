import chip8
import chiputils
import strfmt
import unsigned
import math

proc newChip(): Chip8 =
    let chip = createChip8()
    chip.initialize()
    chip

proc load(name: string): Chip8 =
    let c = newChip()
    c.loadProgram("programs/test/" & name)
    c

proc emu(c: Chip8) =
    c.emulateCycle()

proc testLDVx() =
    let chip = load("loadvx.ch8")
    assert chip.V[3] == 0
    assert chip.V[4] == 0

    chip.emu()
    #chip.memory.viewSection(0x200, 10)
    #chip.V.readValues()
    assert chip.V[3] == 0xFF
    assert chip.V[4] == 0    

    chip.emu()
    assert chip.V[3] == 0xAA
    assert chip.V[4] == 0

    chip.emu()
    assert chip.V[4] == 0x55

    chip.emu()
    assert chip.V[4] == 0x10

    chip.emu()
    assert chip.V[0xE] == 0xCC

proc testJP() =
    let chip = load("jp.ch8")
    chip.emu
    assert chip.V[3] == 0xAA
    chip.emu
    assert chip.pc == 0x208
    chip.emu
    assert chip.V[3] == 0xEE
    chip.emu
    assert chip.pc == 0x200
    chip.emu
    assert chip.V[3] == 0xAA


proc testSEVx() =
    let chip = load("sevx.ch8")
    chip.emu
    assert chip.V[5] == 0xAA
    chip.emu
    assert chip.V[5] == 0xAA
    # skip setting V5 to 0xFF
    chip.emu
    chip.emu
    chip.emu

proc testSEVxVy() =
    let chip = load("sevxvy.ch8")
    chip.emu
    assert chip.V[5] == 0xAA
    chip.emu
    assert chip.V[6] == 0xAA
    chip.emu
    chip.emu
    chip.emu
    chip.emu
    chip.emu
    assert chip.V[1] == 0xEE
    

proc testSNEVx() =
    let chip = load("snevx.ch8")
    chip.emu
    assert chip.V[5] == 0xAA
    chip.emu
    # skip setting V5 to FF
    chip.emu
    assert chip.V[5] == 0xFF

proc testADDVx() =
    let chip = load("addvx.ch8")
    assert chip.V[5] == 0x00
    chip.emu
    assert chip.V[5] == 0x10
    chip.emu
    assert chip.V[5] == 0x20
    chip.emu
    assert chip.V[5] == 0x2F

proc testLDVxVy() =
    let chip = load("loadvxvy.ch8")
    chip.emu
    chip.V.readValues()
    assert chip.V[5] == 0xBB
    assert chip.V[6] == 0x00
    chip.emu
    assert chip.V[5] == 0xBB
    assert chip.V[6] == 0xBB

proc testORVxVy() =
    let chip = load("orvxvy.ch8")
    chip.emu
    chip.emu
    assert chip.V[5] == 0xA0
    assert chip.V[6] == 0x0B
    chip.emu
    assert chip.V[5] == 0xAB

proc testANDVxVy() =
    let chip = load("andvxvy.ch8")
    chip.emu
    chip.emu
    assert chip.V[5] == 0x05
    assert chip.V[6] == 0x03
    chip.emu
    assert chip.V[5] == 0x01

proc testXORVxVy() =
    let chip = load("xorvxvy.ch8")
    chip.emu
    chip.emu
    assert chip.V[5] == 0x05
    assert chip.V[6] == 0x03
    chip.emu
    assert chip.V[5] == 0x06

proc testADDVxVy() =
    let chip = load("addvxvy.ch8")
    chip.emu
    chip.emu
    assert chip.V[5] == 0x05
    assert chip.V[6] == 0x04
    chip.emu
    assert chip.V[5] == 0x09

proc testSUBVxVy() =
    let chip = load("subvxvy.ch8")
    chip.emu
    chip.emu
    assert chip.V[5] == 0x05
    assert chip.V[6] == 0x03
    chip.emu
    assert chip.V[5] == 0x02

proc testSHRVx() =
    let chip = load("shrvx.ch8")
    chip.emu
    assert chip.V[5] == 0xCC #0b11001100
    chip.emu
    assert chip.V[5] == 0x66 #0b01100110

proc testSHLVx() =
    let chip = load("shlvx.ch8")
    chip.emu
    assert chip.V[5] == 0x66
    chip.emu
    assert chip.V[5] == 0xCC

proc testSUBNVxVy() =
    let chip = load("subnvxvy.ch8")
    chip.emu
    chip.emu
    assert chip.V[5] == 0x09
    assert chip.V[6] == 0x05
    chip.emu
    chip.V.readValues
    assert chip.V[0xF] == 0
    assert chip.V[5] == 0x05'u8 - 0x09'u8
    chip.emu
    chip.emu
    assert chip.V[5] == 0x09
    assert chip.V[6] == 0x0A
    chip.emu
    assert chip.V[5] == 0x01
    assert chip.V[0xF] == 1
    chip.V.readValues
    
proc testSNEVxVy() =
    let chip = load("snevxvy.ch8")
    chip.emu
    chip.emu
    assert chip.V[5] == 0xAA
    assert chip.V[6] == 0xBB
    chip.emu
    chip.emu
    assert chip.V[5] == 0xDD

proc testLDI() =
    let chip = load("ldi.ch8")
    assert chip.I == 0
    chip.emu
    assert chip.I == 0x300
    chip.emu
    assert chip.I == 0x123

proc testJPV0() =
    let chip = load("jpv0.ch8")
    for i in 1..5:
        assert chip.pc == 0x200
        chip.emu
        assert chip.pc == 0x208
        chip.emu

proc testRNDVx() =
    let chip = load("rndvx.ch8")
    for i in 1..5:
        chip.emu
        echo "value: " & chip.V[5].hex

proc testLDVxDT() =
    let chip = load("ldvxdt.ch8")
    chip.delay_timer.time = 0xCC
    chip.emu
    assert chip.delay_timer.time == 0xCB
    assert chip.V[5] == 0xCC

proc testLDDTVx() =
    let chip = load("lddtvx.ch8")
    chip.emu
    assert chip.V[5] == 0xAB
    chip.emu
    assert chip.delay_timer.time == 0xAB - 1

proc testLDSTVx() =
    let chip = load("ldstvx.ch8")
    chip.emu
    assert chip.V[5] == 0xAA
    chip.emu
    assert chip.sound_timer.time == 0xAA - 1

proc testADDIVx() =
    let chip = load("addivx.ch8")
    chip.emu
    assert chip.V[5] == 0xAA
    chip.I = 0x11
    chip.emu
    assert chip.I == 0xBB

proc testLDBVx() =
    proc check(chip: Chip8, match: string) =
        var hasNonZero = false
        var res: string = ""
        for i in 0'u16..2'u16:
            let num = chip.memory[chip.I + i]
            # dont write leading zeroes
            if num == 0 and not hasNonZero:
                continue
            res.add($num)
        if res.len == 0:
            res = "0"
        echo "res: {}, match: {}".fmt(res, match)
        assert match == res

    let chip = load("ldbvx.ch8")
    chip.emu
    assert chip.V[5] == 123 # 0x7B 
    chip.emu
    chip.check("123")

    chip.emu
    assert chip.V[5] == 58 # 0x3A
    chip.emu
    chip.check("58")

    chip.emu
    assert chip.V[5] == 7 # 0x07
    chip.emu
    chip.check("7")

    chip.emu
    assert chip.V[5] == 0
    chip.emu
    chip.check("0")

proc testLDIVx() =
    let chip = load("ldivx.ch8")
    for i in 1..6:
        chip.emu
    for i in 0..5:
        assert chip.V[uint16(i)] == uint8(0x10 * i)
    # load registers into memory
    chip.emu
    for i in 0..5:
        let reg = chip.V[uint16(i)]
        let mem = chip.memory[chip.I + uint16(i)]
        #echo "reg: 0x{}, mem: 0x{}".fmt(reg.hex, mem.hex)
        assert(reg == mem, "reg: 0x{}, mem: 0x{}".fmt(reg.hex, mem.hex))

proc testLDVxI() =
    let chip = load("ldvxi.ch8")
    chip.emu
    assert chip.I == 0x400
    for i in 1..6:
        chip.emu
    let checkVals = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
    for i in 0..5:
        assert chip.V[i] == uint8(checkVals[i])
    chip.emu
    echo "Memory:"
    for i in 0..5:
        let memLoc = chip.I + uint16(i)
        assert chip.memory[memLoc] == chip.V[i]
        echo "\t[{:04X}]: {:X}".fmt(i, chip.memory[i])


proc testCALLRET() =
    let chip = load("callret.ch8")
    for i in 1..3:
        assert chip.sp == 0
        chip.emu
        assert chip.V[5] == 0xFF 
        chip.emu
        assert chip.pc == 0x208
        assert chip.sp == 1
        assert chip.stack[chip.sp] == 0x204
        chip.emu
        assert chip.V[5] == 0xAA
        chip.emu
        assert chip.pc == 0x204
        assert chip.sp == 0
        chip.emu
        assert chip.V[5] == 0x01
        chip.emu
        assert chip.pc == 0x200

proc testGFX() =
    let chip = load("gfx.ch8")
    chip.emu
    chip.emu
    chip.emu
    chip.emu
    #chip.memory.viewSection(int(chip.I), 40)
    chip.gfx.printGraphics

convertAllPrograms()
#testLDVx()
#testJP()
#testSEVx()
#testSNEVx()
#testADDVx()
#testLDVxVy()
#testORVxVy()
#testANDVxVy()
#testXORVxVy()
#testADDVxVy()
#testSUBVxVy()
#testSHRVx()
#testSHLVx()
#testSUBNVxVy()
#testSNEVxVy()
#testLDI()
#testJPV0()
#testLDVxDT()
#testLDDTVx()
#testLDSTVx()
#testADDIVx()
#testLDBVx()
#testLDIVx()
#testCALLRET()
#testGFX()
#testSEVxVy()
#testLDVxI()

testRNDVx()

echo "\n========= ALL TESTS PASSED ========="
