; Countdown at 27 MHz: shows 5, 4, 3, 2, 1, 0 on the LEDs, one count per second, forever
;
; RAM use:  0x10 = count, 0x11 = middle loop counter, 0x12 = outer loop counter
; Timing:   every count lasts exactly 27,000,000 clocks = 1.000 s at 27 MHz
;           period = OUTER * (MIDDLE * (6*INNER + 11) + 13) + 20
;                  = 245   * (101    * (6*180   + 11) + 13) + 20 = 27,000,000

start:  LDI  0b00111111 ; count = 5
        STE  0x10
show:   LD   0x10       ; LEDs show count
        STE  0x81

; ---- 1 second delay: three nested loops ----
        LDI  0xF5       ; outer loop: 245 passes
        STE  0x12
outer:  LDI  0x65       ; middle loop: 101 passes
        STE  0x11
middle: LDI  0xB4       ; inner loop: 180 passes, counted in the ACC (6 clocks each)
inner:  SUBI 0x01
        SKIP Z=1
        GOTO inner
        LD   0x11       ; middle counter - 1
        SUBI 0x01
        STE  0x11
        SKIP Z=1
        GOTO middle
        LD   0x12       ; outer counter - 1
        SUBI 0x01
        STE  0x12
        SKIP Z=1
        GOTO outer
; ---- end of delay ----

        LD   0x10       ; LD does not set flags, so ORI 0 sets Z from count
        ORI  0x00
        SKIP Z=0        ; count is not 0: skip the restart
        GOTO start      ; count was 0: start again from 5
        SUBI 0x01       ; count = count - 1
        STE  0x10
        GOTO show