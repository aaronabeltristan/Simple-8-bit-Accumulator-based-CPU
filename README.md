# Simple 8-bit Accumulator-based CPU

An 8-bit accumulator-based CPU with a Harvard architecture, written in Verilog for the **Sipeed Tang Nano 9K** (Gowin GW1NR-9 FPGA).

Full specification: [`docs/Design Guide.pdf`](docs/Design%20Guide.pdf)

## Features

- **8-bit data path** built around a single accumulator (ACC)
- **Harvard architecture:** separate instruction memory (256 × 12-bit) and data memory (256 × 8-bit)
- **12-bit instructions:** 4-bit opcode + 8-bit operand, 16 instructions
- **Fixed 6-state control cycle** (T1–T6) for every instruction
- **Zero (Z) and Carry (C) flags** for conditional skips
- **Memory-mapped I/O:** input at `0x80`, output at `0x81`

## Instruction set

Format: `[11:8]` opcode, `[7:0]` operand (address, immediate value or option bit).

| Opcode | Mnemonic | Operation |
| --- | --- | --- |
| `0x0` | ADD | ACC ← ACC + B |
| `0x1` | SUB | ACC ← ACC − B |
| `0x2` | AND | ACC ← ACC & B |
| `0x3` | OR | ACC ← ACC \| B |
| `0x4` | NOT | ACC ← ~ACC |
| `0x5` | INC | ACC ← ACC + 1 |
| `0x6` | DEC | ACC ← ACC − 1 |
| `0x7` | LD | ACC ← MEM[addr] |
| `0x8` | STE | MEM[addr] ← ACC |
| `0x9` | LDI | ACC ← imm |
| `0xA` | GOTO | PC ← addr |
| `0xB` | SF1 | Skip next instruction if flag = 1 (operand[0]: 0 = Z, 1 = C) |
| `0xC` | SF0 | Skip next instruction if flag = 0 (operand[0]: 0 = Z, 1 = C) |
| `0xD` | ALM | Set ALU operand mode (0 = memory, 1 = immediate) |
| `0xE` | CTL | 0 = NOP, 1 = HALT |
| `0xF` | CLR | 0 = clear ACC, 1 = clear flags |

`B` is `MEM[operand]` in memory mode (default) or the operand itself in immediate mode, as set by `ALM`.

## Memory map (data memory)

| Address | Contents |
| --- | --- |
| `0x00`–`0x7F` | General-purpose RAM |
| `0x80` | Input device (read only) |
| `0x81` | Output device |
| `0x82`–`0xFF` | Reserved |

## Repository structure

```
rtl/          Verilog source for each CPU block
sim/          Testbenches
programs/     Machine-code programs for instruction memory
constraints/  Tang Nano 9K pin constraints (.cst)
docs/         Design guide
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
- [ ] Instruction memory
- [ ] Data memory with memory-mapped I/O
- [ ] Timing and control unit (FSM)
- [ ] Datapath / top-level integration

### Verification

- [x] ALU testbench
- [ ] Registers testbenches
- [ ] Unit testbenches for each block
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
