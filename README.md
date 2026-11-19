# Simple 8-bit Accumulator-based CPU

An 8-bit accumulator-based CPU with a Harvard architecture, written in Verilog for the **Sipeed Tang Nano 9K** (Gowin GW1NR-9 FPGA).

Specification: [`docs/Design Guide.pdf`](docs/Design%20Guide.pdf)  
Control signals per instruction: [`docs/Control Unit Signal Table.pdf`](docs/Control%20Unit%20Signal%20Table.pdf)  
Synthesized netlist schematic: [`docs/cpu_netlist.svg`](docs/cpu_netlist.svg)

## Features

- **8-bit data path** built around a single accumulator (ACC)
- **Harvard architecture:** separate instruction ROM (256 × 12-bit) and data memory (256 × 8-bit, with an I/O block at `0x80`–`0x87`)
- **12-bit instructions:** 4-bit opcode + 8-bit operand, 16 instructions; addressing mode encoded in the opcode
- **3-state control cycle:** FETCH, EXECUTE, WRITEBACK (2 or 3 clocks per instruction), plus a HALT state
- **Zero (Z) and Carry (C) flags** for conditional skips
- **Memory-mapped I/O:** two 8-bit GPIO ports (each pin input or output, set by a direction register) and a 4-digit 7-segment display
- **Runs on the Tang Nano 9K** at the full 27 MHz board clock, or slowed down with a clock divider

## Instruction set

Format: `[11:8]` opcode, `[7:0]` operand (address, immediate value or option bits).

| Opcode | Mnemonic | Operation |
| --- | --- | --- |
| `0x0` | ADD | ACC ← ACC + MEM[addr] |
| `0x1` | SUB | ACC ← ACC − MEM[addr] |
| `0x2` | AND | ACC ← ACC & MEM[addr] |
| `0x3` | OR | ACC ← ACC \| MEM[addr] |
| `0x4` | ADDI | ACC ← ACC + imm |
| `0x5` | SUBI | ACC ← ACC − imm |
| `0x6` | ANDI | ACC ← ACC & imm |
| `0x7` | ORI | ACC ← ACC \| imm |
| `0x8` | LD | ACC ← MEM[addr] |
| `0x9` | STE | MEM[addr] ← ACC |
| `0xA` | LDI | ACC ← imm |
| `0xB` | GOTO | PC ← addr |
| `0xC` | SKIP | Skip next instruction if the selected flag equals operand[1] (operand[0]: 0 = Z, 1 = C) |
| `0xD` | NOT | ACC ← ~ACC |
| `0xE` | CTL | 0 = NOP, 1 = HALT |
| `0xF` | CLR | 0 = clear ACC, 1 = clear flags |

Opcode bit 2 selects the operand for ALU instructions: `0x0`–`0x3` read data memory, `0x4`–`0x7` use the immediate. SKIP operands: `0x00` skip if Z = 0, `0x02` skip if Z = 1, `0x01` skip if C = 0, `0x03` skip if C = 1. INC and DEC are written as `ADDI 0x01` and `SUBI 0x01`.

## Memory map (data memory)

| Address | Register | Read (`LD`) | Write (`STE`) |
| --- | --- | --- | --- |
| `0x00`–`0x7F` | RAM | RAM | RAM |
| `0x80` | PINA | port A pin levels | ignored |
| `0x81` | DISPLAY | display register | value shown on the 7-segment display and LEDs |
| `0x82` | PORTA | port A output register | values driven on port A output pins |
| `0x83` | DDRA | port A direction | 1 = output, 0 = input, per pin |
| `0x84` | PINB | port B pin levels | ignored |
| `0x85` | PORTB | port B output register | values driven on port B output pins |
| `0x86` | DDRB | port B direction | 1 = output, 0 = input, per pin |
| `0x87` | reserved | `0x00` | ignored |
| `0x88`–`0xFF` | RAM | RAM | RAM |

Reset clears every I/O register, so all GPIO pins start as inputs. `0x80` (input) and `0x81` (output) keep their original meaning, so Tests A, B and C are unchanged.

### Using a GPIO port

```
        LDI  0xF0       ; pins 7..4 outputs, pins 3..0 inputs
        STE  0x86       ; DDRB
        LD   0x80       ; read port A pins
        STE  0x85       ; drive port B output pins
```

The pins have internal pull-ups: a button wired from a pin to GND reads 1 when released and 0 when pressed.

## Programs

| File | What it does |
| --- | --- |
| `programs/test_a.hex` | Test A: counts down from 5 to 0, writing each value to the output device, then halts |
| `programs/test_b.hex` | Test B: addition and subtraction through data memory |
| `programs/test_c.hex` | Test C: reads the input device, adds 1, writes the output device |
| `programs/countdown.hex` | Board demo: Test A that repeats forever instead of halting |
| `programs/1sec_countdown.hex` | Board demo at 27 MHz: counts 5 to 0 on the display, exactly one count per second, forever |
| `programs/test_gpio.asm` / `.hex` | GPIO test: copies port A to port B (pins 7..4 outputs) and shows the port B pins on the display |

On the board, the display and LEDs show the DISPLAY register (`0x81`), so a program must write to `0x81` to show anything.

## Repository structure

```
rtl/          Verilog source for each CPU block, the CPU top level, the board peripherals and the Tang Nano 9K top level
sim/          Testbenches
programs/     Machine-code programs for instruction memory
constraints/  Tang Nano 9K pin constraints (.cst)
fpga/         Gowin EDA project
docs/         Design guide, control unit signal table and netlist schematic
tools/        Schematic generator
```

## Simulation

Run from the repository root (Icarus Verilog), for example the full CPU running Tests A, B and C:

```
iverilog -o tb_cpu.vvp sim/tb_cpu.v rtl/cpu.v rtl/program_counter.v rtl/instruction_memory.v rtl/instruction_register.v rtl/instruction_decoder.v rtl/control_unit.v rtl/nto1mux.v rtl/alu.v rtl/accumulator.v rtl/flag_register.v rtl/data_memory.v
vvp tb_cpu.vvp
gtkwave tb_cpu.vcd
```

Each testbench prints `PASS` or the failing checks.

## Building for the Tang Nano 9K

The board top level `rtl/top_tang9k.v` contains:

- **CPU clock:** the 27 MHz board clock directly (`DIVISOR = 1`), or divided by `clock_divider` for slow, visible stepping
- **Reset:** S1, synchronized to the CPU clock (`synchronizer.v`); the CPU also resets itself at power-up
- **GPIO:** two 8-bit ports with tri-state pins; pin levels are synchronized before the CPU reads them
- **Display:** `seven_seg_display.v` shows the DISPLAY register in decimal on a 5641BS 4-digit display
- **LEDs:** the six onboard LEDs show DISPLAY[5:0] in binary (active-low)

1. Open `fpga/fpga/fpga.gprj` in Gowin EDA (device GW1NR-LV9QN88PC6/I5, version C).
2. Choose the program with the `PROGRAM` parameter in `rtl/top_tang9k.v`, e.g. `"../../programs/countdown.hex"` (paths are relative to the Gowin project folder).
3. Run Synthesize, then Place & Route.
4. Open Programmer and load the bitstream (SRAM for a quick test, embedded flash to keep it after power-off).
5. Press S1 to restart the program.

Add `rtl/synchronizer.v` and `rtl/seven_seg_display.v` to the Gowin project together with the CPU modules.

### Wiring

| Signal | FPGA pins | Connection |
| --- | --- | --- |
| `seg[7:0]` (a, b, c, d, e, f, g, dp) | 25, 26, 27, 28, 29, 30, 33, 34 | 5641BS pins 11, 7, 4, 2, 1, 10, 5, 3, each through 330 Ω |
| `dig[3:0]` (DIG1 to DIG4) | 40, 35, 41, 42 | PNP transistor bases through 1 kΩ; emitters to 3.3 V, collectors to 5641BS pins 12, 9, 8, 6 |
| `gpio_a[7:0]` | 51, 53, 54, 55, 56, 57, 38, 37 | port A; buttons to GND through ~330 Ω |
| `gpio_b[7:0]` | 79, 80, 81, 82, 83, 84, 85, 86 | port B |

All external pins are 3.3 V header pins (check each against the board pinout). Pins 68–75 (shared with HDMI) and 17–18 (USB-UART) are left free. The ~330 Ω in series with each button protects the pin if a program sets it as an output driving 1.

## Progress

### RTL

- [x] Program counter (`program_counter.v`)
- [x] Instruction register (`instruction_register.v`)
- [x] Instruction decoder (`instruction_decoder.v`)
- [x] Accumulator (`accumulator.v`)
- [x] Flag register (`flag_register.v`)
- [x] ALU (`alu.v`)
- [x] N-to-1 multiplexer (`nto1mux.v`)
- [x] Instruction memory (`instruction_memory.v`)
- [x] Data memory with memory-mapped I/O block (`data_memory.v`)
- [x] Timing and control unit (FSM)
- [x] CPU top level (`cpu.v`)
- [x] Clock divider (`clock_divider.v`)
- [x] Tang Nano 9K top level (`top_tang9k.v`)
- [x] Two flip-flop synchronizer (`synchronizer.v`)
- [x] 4-digit 7-segment display driver (`seven_seg_display.v`)
- [x] GPIO ports A and B (direction, output and pin registers)

### Verification

- [x] ALU testbench
- [x] Registers testbench (PC, IR, ACC, flags)
- [x] Instruction memory testbench
- [x] Data memory testbench
- [x] Control unit testbench
- [x] Test A: countdown from 5 to 0 on the output device, then halt
- [x] Test B: addition and subtraction through memory
- [x] Test C: memory-mapped I/O
- [x] Clock divider testbench
- [x] Board top level testbench (clock divider, reset synchronizer, CPU and LEDs)
- [x] Data memory testbench with the GPIO and DISPLAY registers
- [x] Board top level testbench with GPIO (tri-state outputs, pulled-up inputs, read-back)
- [ ] Synchronizer and 7-segment display testbenches

### Hardware

- [x] Tang Nano 9K pin constraints
- [x] Synthesis and on-board test
- [x] Full-speed 27 MHz operation (timing: about 62 MHz maximum)
- [ ] 7-segment display and GPIO wired and tested on the board

### Software

- [ ] Assembler: assembly source to `.hex` for instruction memory
- [ ] Browser simulator: write, assemble and step through programs; view PC, IR, ACC, flags and memory
- [ ] Cross-check simulator against RTL using Tests A, B and C

## Tools

- **Synthesis / place and route:** Gowin EDA
- **Simulation:** Icarus Verilog + GTKWave
- **Schematic:** Yosys + ELK (`schematic.ps1`)
