`timescale 1ns/1ps

module control_unit #(
    parameter OPCODE_WIDTH = 4,
              FLAG_WIDTH = 2
) (
    input wire clk,
    input wire rst_n,
    input wire [OPCODE_WIDTH-1:0] opcode,
    input wire [1:0] option,   // operand[1:0]: SKIP flag select/value, CTL and CLR select
    input wire [FLAG_WIDTH-1:0] flags,
    output reg ir_load_en,
    output reg pc_inc_en,
    output reg pc_load_en,
    output reg [1:0] aws,
    output reg acc_load_en,
    output reg acc_clear_en,
    output reg flag_load_en,
    output reg flag_clear_en,
    output reg dm_read_en,
    output reg dm_write_en,
    output reg [1:0] state
);

    // States
    localparam FETCH     = 2'd0,
               EXECUTE   = 2'd1,
               WRITEBACK = 2'd2,
               HALT      = 2'd3;

    // Arithmetic and Logic Instructions
    localparam ADD  = 4'h0, 
               SUB  = 4'h1, 
               AND  = 4'h2, 
               OR   = 4'h3, 
               ADDI = 4'h4, 
               SUBI = 4'h5, 
               ANDI = 4'h6, 
               ORI  = 4'h7, 
               NOT  = 4'hD;

    // Data Transfer Instructions
    localparam LD  = 4'h8,
               STE = 4'h9,
               LDI = 4'hA;

    // Control Instructions
    localparam GOTO = 4'hB,
               SKIP = 4'hC;
    
    // Special Instructions
    localparam CTL = 4'hE,
               CLR = 4'hF;

    // Accumulator Write Select
    localparam AWS_IMM = 2'b01,
               AWS_MEM = 2'b10,
               AWS_ALU = 2'b11;
    
    reg [1:0] next_state;

    // SKIP fires when the flag selected by option[0] (0 = Z, 1 = C) equals option[1]
    wire skip = (flags[option[0]] == option[1]);
    
    // State register
    always @(posedge clk) begin
        if (!rst_n) state <= FETCH;
        else state <= next_state;
    end

    // Control signals and next state
    always @(*) begin
        // Defaults: every control signal off, stay in the current state
        ir_load_en    = 1'b0;
        pc_inc_en     = 1'b0;
        pc_load_en    = 1'b0;
        aws           = 2'b00;
        acc_load_en   = 1'b0;
        acc_clear_en  = 1'b0;
        flag_load_en  = 1'b0;
        flag_clear_en = 1'b0;
        dm_read_en    = 1'b0;
        dm_write_en   = 1'b0;
        next_state    = state;

        case (state)
            FETCH: begin
                ir_load_en = 1'b1;          // IR <- ROM[PC]
                pc_inc_en  = 1'b1;          // PC <- PC + 1
                next_state = EXECUTE;
            end

            EXECUTE: begin
                case (opcode)
                    ADD, SUB, AND, OR: begin
                        dm_read_en = 1'b1;              // read operand B from memory
                        next_state = WRITEBACK;
                    end

                    ADDI, SUBI, ANDI, ORI, NOT: begin
                        aws          = AWS_ALU;
                        acc_load_en  = 1'b1;
                        flag_load_en = 1'b1;
                        next_state   = FETCH;
                    end

                    LD: begin
                        dm_read_en = 1'b1;              // read MEM[addr]
                        next_state = WRITEBACK;
                    end

                    STE: begin
                        dm_write_en = 1'b1;             // MEM[addr] <- ACC
                        next_state  = FETCH;
                    end

                    LDI: begin
                        aws         = AWS_IMM;
                        acc_load_en = 1'b1;
                        next_state  = FETCH;
                    end

                    GOTO: begin
                        pc_load_en = 1'b1;              // PC <- operand
                        next_state = FETCH;
                    end

                    SKIP: begin
                        pc_inc_en  = skip;              // extra increment skips the next instruction
                        next_state = FETCH;
                    end

                    CTL: begin
                        next_state = option[0] ? HALT : FETCH;   // 1 = HALT, 0 = NOP
                    end

                    CLR: begin
                        if (option[0]) flag_clear_en = 1'b1;     // 1 = clear flags
                        else           acc_clear_en  = 1'b1;     // 0 = clear ACC
                        next_state = FETCH;
                    end

                    default: next_state = FETCH;
                endcase
            end

            WRITEBACK: begin
                case (opcode)
                    ADD, SUB, AND, OR: begin
                        aws          = AWS_ALU;         // memory data is now on operand B
                        acc_load_en  = 1'b1;
                        flag_load_en = 1'b1;
                    end

                    LD: begin
                        aws         = AWS_MEM;
                        acc_load_en = 1'b1;
                    end

                    default: ;
                endcase
                next_state = FETCH;
            end

            HALT: next_state = HALT;

            default: next_state = FETCH;
        endcase
    end

endmodule