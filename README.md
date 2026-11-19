# Simple 8-bit Accumulator-based CPU

An 8-bit accumulator-based CPU with a Harvard architecture, written in Verilog for the **Sipeed Tang Nano 9K** (Gowin GW1NR-9 FPGA).

Specification: [`docs/Design Guide.pdf`](docs/Design%20Guide.pdf)  
Control signals per instruction: [`docs/Control Unit Signal Table.pdf`](docs/Control%20Unit%20Signal%20Table.pdf)  
Synthesized netlist schematic: [`docs/cpu_netlist.svg`](docs/cpu_netlist.svg)

## Features

- **8-bit data path** built around a single accumulator (ACC)
- **Harvard architecture:** separate instruction ROM (256 × 12-bit) and data memory (256 × 8-bit, with I/O at `0x80`–`0x81`)
- **12-bit instructions:** 4-bit opcode + 8-bit operand, 16 instructions; addressing mode encoded in the opcode
- **3-state control cycle:** FETCH, EXECUTE, WRITEBACK (2 or 3 clocks per instruction), plus a HALT state
- **Zero (Z) and Carry (C) flags** for conditional skips
- **Memory-mapped I/O:** input at `0x80`, output at `0x81`

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

| Address | Contents |
| --- | --- |
| `0x00`–`0x7F` | RAM |
| `0x80` | Input device (read only; writes ignored) |
| `0x81` | Output device register (read/write) |
| `0x82`–`0xFF` | RAM |

## Programs

| File | What it does |
| --- | --- |
| `programs/test_a.hex` | Test A: counts down from 5 to 0, writing each value to the output device, then halts |
| `programs/test_b.hex` | Test B: addition and subtraction through data memory |
| `programs/test_c.hex` | Test C: reads the input device, adds 1, writes the output device |
| `programs/countdown.hex` | Board demo: Test A that repeats forever instead of halting |

On the board, the LEDs show `output_device[5:0]`, so a program must write to `0x81` to show anything.

## Repository structure

```
rtl/          Verilog source for each CPU block, the CPU top level and the Tang Nano 9K top level
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

The board top level `rtl/top_tang9k.v` divides the 27 MHz clock down for the CPU (`DIVISOR`, 20 Hz by default), synchronizes the S1 reset button and drives the six LEDs (active-low) from `output_device[5:0]`. The input device is tied to `0x0A`.

1. Open `fpga/fpga/fpga.gprj` in Gowin EDA (device GW1NR-LV9QN88PC6/I5, version C).
2. Choose the program with the `PROGRAM` parameter in `rtl/top_tang9k.v`, e.g. `"../../programs/countdown.hex"` (paths are relative to the Gowin project folder).
3. Run Synthesize, then Place & Route.
4. Open Programmer and load the bitstream (SRAM for a quick test, embedded flash to keep it after power-off).
5. Press S1 to restart the program.

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
- [x] Data memory with memory-mapped I/O (`data_memory.v`)
- [x] Timing and control unit (FSM)
- [x] CPU top level (`cpu.v`)
- [x] Clock divider (`clock_divider.v`)
- [x] Tang Nano 9K top level (`top_tang9k.v`)

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

### Hardware

- [x] Tang Nano 9K pin constraints
- [x] Synthesis and on-board test

### Software

- [ ] Assembler: assembly source to `.hex` for instruction memory
- [ ] Browser simulator: write, assemble and step through programs; view PC, IR, ACC, flags and memory
- [ ] Cross-check simulator against RTL using Tests A, B and C

## Tools

- **Synthesis / place and route:** Gowin EDA
- **Simulation:** Icarus Verilog + GTKWave
- **Schematic:** Yosys + ELK (`schematic.ps1`)
