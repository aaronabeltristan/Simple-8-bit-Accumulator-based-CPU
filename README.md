# Simple 8-bit Accumulator-based CPU

An 8-bit accumulator-based CPU with a Harvard architecture, written in Verilog for the **Sipeed Tang Nano 9K** (Gowin GW1NR-9 FPGA).

Specification: [`docs/Design Guide.pdf`](docs/Design%20Guide.pdf)  
Control signals per instruction: [`docs/Control Unit Signal Table.pdf`](docs/Control%20Unit%20Signal%20Table.pdf)

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

## Repository structure

```
rtl/          Verilog source for each CPU block
sim/          Testbenches
programs/     Machine-code programs for instruction memory
constraints/  Tang Nano 9K pin constraints (.cst)
docs/         Design guide and control unit signal table
```

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
- [ ] Timing and control unit (FSM)
- [ ] Datapath / top-level integration

### Verification

- [x] ALU testbench
- [x] Registers testbench (PC, IR, ACC, flags)
- [x] Instruction memory testbench
- [x] Data memory testbench
- [ ] Control unit testbench
- [ ] Test A: countdown from 5 to 0, then halt
- [ ] Test B: addition and subtraction through memory
- [ ] Test C: memory-mapped I/O

### Hardware

- [ ] Tang Nano 9K pin constraints
- [ ] Synthesis and on-board test

### Software

- [ ] Assembler: assembly source to `.hex` for instruction memory
- [ ] Browser simulator: write, assemble and step through programs; view PC, IR, ACC, flags and memory
- [ ] Cross-check simulator against RTL using Tests A, B and C

## Tools

- **Synthesis / place and route:** Gowin EDA
- **Simulation:** Icarus Verilog + GTKWave
