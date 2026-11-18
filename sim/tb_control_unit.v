`timescale 1ns/1ps

module tb_control_unit #(
    parameter OPCODE_WIDTH = 4,
              FLAG_WIDTH = 2
);
    reg clk;
    reg rst_n;
    reg [OPCODE_WIDTH-1:0] opcode;
    reg [1:0] option;
    reg [FLAG_WIDTH-1:0] flags;            // [1] C, [0] Z
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
    wire [1:0] state;

    // Instantiate DUT
    control_unit #(
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .FLAG_WIDTH(FLAG_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .opcode(opcode),
        .option(option),
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

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // States
    localparam FETCH     = 2'd0,
               EXECUTE   = 2'd1,
               WRITEBACK = 2'd2,
               HALT      = 2'd3;

    // All control outputs packed in signal-table order:
    // IRWE | PCIE | PCLE | AWS[1:0] | ACC load_en | acc_clear | FLE | flag_clear | DMRE | DMWE
    wire [10:0] signals = {ir_load_en, pc_inc_en, pc_load_en, aws, acc_load_en, acc_clear_en,
                           flag_load_en, flag_clear_en, dm_read_en, dm_write_en};

    // Expected signal patterns (one per row type of the signal table)
    localparam S_NONE    = 11'b0_0_0_00_0_0_0_0_0_0,
               S_FETCH   = 11'b1_1_0_00_0_0_0_0_0_0,   // IRWE, PCIE
               S_MEMRD   = 11'b0_0_0_00_0_0_0_0_1_0,   // DMRE
               S_ALU     = 11'b0_0_0_11_1_0_1_0_0_0,   // AWS = ALU, ACC load, FLE
               S_LD_WB   = 11'b0_0_0_10_1_0_0_0_0_0,   // AWS = memory, ACC load
               S_STE     = 11'b0_0_0_00_0_0_0_0_0_1,   // DMWE
               S_LDI     = 11'b0_0_0_01_1_0_0_0_0_0,   // AWS = immediate, ACC load
               S_GOTO    = 11'b0_0_1_00_0_0_0_0_0_0,   // PCLE
               S_SKIP    = 11'b0_1_0_00_0_0_0_0_0_0,   // PCIE (extra increment)
               S_CLR_ACC = 11'b0_0_0_00_0_1_0_0_0_0,   // acc_clear
               S_CLR_FLG = 11'b0_0_0_00_0_0_0_1_0_0;   // flag_clear

    integer errors;

    // Compare the current state and all control outputs
    task check;
        input [1:0]  exp_state;  // expected state
        input [10:0] exp_sig;    // expected control signals
        input [3:0]  t_op;       // opcode under test (for the message)
        input [8*9:1] stage;     // label for the message
        begin
            if (state !== exp_state || signals !== exp_sig) begin
                $display("FAIL %0s op=%h option=%b flags=%b | got state=%0d sig=%b | expected state=%0d sig=%b",
                         stage, t_op, option, flags, state, signals, exp_state, exp_sig);
                errors = errors + 1;
            end
        end
    endtask

    // Run one instruction and check every state it passes through.
    // Called while the FSM is in FETCH (just after reset release or after the previous instruction).
    task run_instr;
        input [3:0]  t_op;       // task opcode
        input [1:0]  t_option;   // task operand[1:0]
        input [1:0]  t_flags;    // task flags ([1] C, [0] Z)
        input [10:0] exp_exec;   // expected signals in EXECUTE
        input [1:0]  exp_next;   // expected state after EXECUTE
        input [10:0] exp_wb;     // expected signals in WRITEBACK (if used)
        begin
            opcode = t_op;
            option = t_option;
            flags  = t_flags;
            #1;
            check(FETCH, S_FETCH, t_op, "FETCH");          // FETCH ignores the opcode

            @(posedge clk); #1;
            check(EXECUTE, exp_exec, t_op, "EXECUTE");

            @(posedge clk); #1;
            if (exp_next == WRITEBACK) begin
                check(WRITEBACK, exp_wb, t_op, "WRITEBACK");
                @(posedge clk); #1;
                check(FETCH, S_FETCH, t_op, "NEXT");        // back to FETCH
            end
            else if (state !== exp_next) begin
                $display("FAIL NEXT op=%h | got state=%0d | expected state=%0d", t_op, state, exp_next);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_control_unit.vcd");
        $dumpvars(0, tb_control_unit);
        errors = 0;

        // Inputs idle, reset held
        rst_n  = 0;
        opcode = 0;
        option = 0;
        flags  = 0;

        // Reset: hold for 2 clocks, FSM must sit in FETCH, then release
        repeat (2) @(posedge clk);
        #1;
        check(FETCH, S_FETCH, opcode, "RESET");           // reset state is FETCH
        @(negedge clk);
        rst_n = 1;

        // Memory-operand ALU instructions: read in EXECUTE, store in WRITEBACK
        run_instr(4'h0, 2'b00, 2'b00, S_MEMRD, WRITEBACK, S_ALU);    // ADD
        run_instr(4'h1, 2'b00, 2'b00, S_MEMRD, WRITEBACK, S_ALU);    // SUB
        run_instr(4'h2, 2'b00, 2'b00, S_MEMRD, WRITEBACK, S_ALU);    // AND
        run_instr(4'h3, 2'b00, 2'b00, S_MEMRD, WRITEBACK, S_ALU);    // OR

        // Immediate-operand ALU instructions and NOT: store in EXECUTE
        run_instr(4'h4, 2'b00, 2'b00, S_ALU, FETCH, S_NONE);         // ADDI
        run_instr(4'h5, 2'b00, 2'b00, S_ALU, FETCH, S_NONE);         // SUBI
        run_instr(4'h6, 2'b00, 2'b00, S_ALU, FETCH, S_NONE);         // ANDI
        run_instr(4'h7, 2'b00, 2'b00, S_ALU, FETCH, S_NONE);         // ORI
        run_instr(4'hD, 2'b00, 2'b00, S_ALU, FETCH, S_NONE);         // NOT

        // Data transfer
        run_instr(4'h8, 2'b00, 2'b00, S_MEMRD, WRITEBACK, S_LD_WB);  // LD
        run_instr(4'h9, 2'b00, 2'b00, S_STE, FETCH, S_NONE);         // STE
        run_instr(4'hA, 2'b00, 2'b00, S_LDI, FETCH, S_NONE);         // LDI

        // Control
        run_instr(4'hB, 2'b00, 2'b00, S_GOTO, FETCH, S_NONE);        // GOTO

        // SKIP: option[0] picks the flag (0 = Z, 1 = C), option[1] is the value that skips
        run_instr(4'hC, 2'b10, 2'b01, S_SKIP, FETCH, S_NONE);        // skip if Z = 1, Z = 1: skip
        run_instr(4'hC, 2'b10, 2'b00, S_NONE, FETCH, S_NONE);        // skip if Z = 1, Z = 0: no skip
        run_instr(4'hC, 2'b00, 2'b00, S_SKIP, FETCH, S_NONE);        // skip if Z = 0, Z = 0: skip
        run_instr(4'hC, 2'b00, 2'b01, S_NONE, FETCH, S_NONE);        // skip if Z = 0, Z = 1: no skip
        run_instr(4'hC, 2'b11, 2'b10, S_SKIP, FETCH, S_NONE);        // skip if C = 1, C = 1: skip
        run_instr(4'hC, 2'b11, 2'b01, S_NONE, FETCH, S_NONE);        // skip if C = 1, C = 0 (Z = 1): no skip
        run_instr(4'hC, 2'b01, 2'b01, S_SKIP, FETCH, S_NONE);        // skip if C = 0, C = 0 (Z = 1): skip
        run_instr(4'hC, 2'b01, 2'b10, S_NONE, FETCH, S_NONE);        // skip if C = 0, C = 1: no skip

        // Special
        run_instr(4'hF, 2'b00, 2'b00, S_CLR_ACC, FETCH, S_NONE);     // CLR 0: clear ACC
        run_instr(4'hF, 2'b01, 2'b00, S_CLR_FLG, FETCH, S_NONE);     // CLR 1: clear flags
        run_instr(4'hE, 2'b00, 2'b00, S_NONE, FETCH, S_NONE);        // CTL 0: NOP
        run_instr(4'hE, 2'b01, 2'b00, S_NONE, HALT, S_NONE);         // CTL 1: HALT

        // HALT: stays halted with every control signal off
        repeat (3) begin
            @(posedge clk); #1;
            check(HALT, S_NONE, opcode, "HALT");
        end

        // Reset leaves HALT and returns to FETCH
        @(negedge clk);
        rst_n = 0;
        @(posedge clk); #1;
        check(FETCH, S_FETCH, opcode, "RESET");
        @(negedge clk);
        rst_n = 1;

        // CPU runs again after reset
        run_instr(4'hA, 2'b00, 2'b00, S_LDI, FETCH, S_NONE);         // LDI after HALT and reset

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule