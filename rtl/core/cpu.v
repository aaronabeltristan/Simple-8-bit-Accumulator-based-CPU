`timescale 1ns/1ps

// Top level: connects every block of the accumulator-based CPU.
// I/O: input_device = PINA (0x80), output_device = OUT (0x81), GPIO port registers at 0x82-0x89.
// Debug outputs (pc, ir, acc, flags, state) are for testbenches and the board; they do not affect the CPU.
module cpu #(
    parameter PROGRAM = "programs/test_a.hex"
) (
    input wire clk,
    input wire rst_n,
    input wire [7:0] input_device,              // PINA: port A pin levels
    input wire [7:0] pin_b,                     // PINB: port B pin levels
    input wire [7:0] pin_c,                     // PINC: port C pin levels
    output wire [7:0] output_device,            // OUT register
    output wire [7:0] port_a,                   // GPIO port A output values
    output wire [7:0] ddr_a,                    // GPIO port A direction (1 = output)
    output wire [7:0] port_b,                   // GPIO port B output values
    output wire [7:0] ddr_b,                    // GPIO port B direction (1 = output)
    output wire [7:0] port_c,                   // GPIO port C output values
    output wire [7:0] ddr_c,                    // GPIO port C direction (1 = output)
    output wire [7:0] pc,
    output wire [11:0] ir,
    output wire [7:0] acc,
    output wire [1:0] flags,
    output wire [1:0] state
);

    // Instruction path
    wire [11:0] rom_out;
    wire [3:0] opcode;
    wire [7:0] operand;

    // Data path
    wire [7:0] dm_rdata;
    wire [7:0] alu_b;
    wire [7:0] alu_out;
    wire [1:0] alu_flags;
    wire [7:0] acc_in;

    // Control signals
    wire ir_load_en;
    wire pc_inc_en;
    wire pc_load_en;
    wire [1:0] aws;
    wire acc_load_en;
    wire acc_clear_en;
    wire flag_load_en;
    wire flag_clear_en;
    wire dm_read_en;
    wire dm_write_en;

    // Program Counter: increments in FETCH, loads the operand on GOTO
    program_counter #(
        .WIDTH(8)
    ) u_pc (
        .clk(clk),
        .rst_n(rst_n),
        .inc_en(pc_inc_en),
        .load_en(pc_load_en),
        .data_in(operand),
        .data_out(pc)
    );

    // Instruction ROM: asynchronous read of the word at PC
    instruction_memory #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(12),
        .PROGRAM(PROGRAM)
    ) u_rom (
        .addr(pc),
        .data_out(rom_out)
    );

    // Instruction Register: latches the ROM word in FETCH
    instruction_register #(
        .WIDTH(12)
    ) u_ir (
        .clk(clk),
        .rst_n(rst_n),
        .load_en(ir_load_en),
        .data_in(rom_out),
        .data_out(ir)
    );

    // IR Decoder: opcode [11:8], operand [7:0]
    instruction_decoder #(
        .OPCODE_WIDTH(4),
        .OPERAND_WIDTH(8)
    ) u_decoder (
        .data_in(ir),
        .opcode(opcode),
        .operand(operand)
    );

    // Timing and Control Unit
    control_unit #(
        .OPCODE_WIDTH(4),
        .FLAG_WIDTH(2)
    ) u_cu (
        .clk(clk),
        .rst_n(rst_n),
        .opcode(opcode),
        .option(operand[1:0]),
        .flags(flags),
        .ir_load_en(ir_load_en),
        .pc_inc_en(pc_inc_en),
        .pc_load_en(pc_load_en),
        .aws(aws),
        .acc_load_en(acc_load_en),
        .acc_clear_en(acc_clear_en),
        .flag_load_en(flag_load_en),
        .flag_clear_en(flag_clear_en),
        .dm_read_en(dm_read_en),
        .dm_write_en(dm_write_en),
        .state(state)
    );

    // Operand-B MUX: opcode[2] = 0 memory data (0x0-0x3), 1 immediate (0x4-0x7)
    nto1mux #(
        .N(2),
        .WIDTH(8)
    ) u_mux_b (
        .in({operand, dm_rdata}),               // in1, in0
        .sel(opcode[2]),
        .out(alu_b)
    );

    // ALU: A = accumulator, B = operand-B MUX
    alu #(
        .OPCODE_WIDTH(4),
        .DATA_WIDTH(8),
        .FLAG_WIDTH(2)
    ) u_alu (
        .opcode(opcode),
        .A(acc),
        .B(alu_b),
        .out(alu_out),
        .flags_out(alu_flags)
    );

    // Accumulator MUX: AWS 00 hold, 01 immediate, 10 memory data, 11 ALU result
    nto1mux #(
        .N(4),
        .WIDTH(8)
    ) u_mux_acc (
        .in({alu_out, dm_rdata, operand, acc}), // in3, in2, in1, in0
        .sel(aws),
        .out(acc_in)
    );

    // Accumulator
    accumulator #(
        .WIDTH(8)
    ) u_acc (
        .clk(clk),
        .rst_n(rst_n),
        .load_en(acc_load_en),
        .clear_en(acc_clear_en),
        .data_in(acc_in),
        .data_out(acc)
    );

    // Flag Register: [1] C, [0] Z
    flag_register #(
        .FLAG_WIDTH(2)
    ) u_flags (
        .clk(clk),
        .rst_n(rst_n),
        .load_en(flag_load_en),
        .clear_en(flag_clear_en),
        .data_in(alu_flags),
        .data_out(flags)
    );

    // Data Bus: RAM and the I/O block at 0x80-0x8F (GPIO ports, OUT); operand is the address, accumulator is the write data
    data_bus #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(8)
    ) u_dm (
        .clk(clk),
        .rst_n(rst_n),
        .read_en(dm_read_en),
        .write_en(dm_write_en),
        .addr(operand),
        .wdata(acc),
        .input_device(input_device),
        .pin_b(pin_b),
        .pin_c(pin_c),
        .rdata(dm_rdata),
        .output_device(output_device),
        .port_a(port_a),
        .ddr_a(ddr_a),
        .port_b(port_b),
        .ddr_b(ddr_b),
        .port_c(port_c),
        .ddr_c(ddr_c)
    );

endmodule