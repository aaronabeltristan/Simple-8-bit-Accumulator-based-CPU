; Press counter: every press of button 0 (pin 38) adds 1, shown on the onboard LEDs
; Runs at 27 MHz. Each press and each release is followed by a ~15 ms wait,
; so contact bounce is not counted as extra presses.
;
; RAM use:  0x10 = count, 0x11 = delay counter
; Delay:    256 x (6 x 256 + 11) clocks = about 396,000 clocks = 14.7 ms at 27 MHz

start:  CLRA                ; count = 0
        STE  0x10
        STE  0x81           ; show 0

; ---- wait until button 0 is pressed (pin reads 0) ----
press:  LD   0x80           ; ACC = PINA
        ANDI 0x01           ; keep button 0 only: Z = 1 when pressed
        SKIP Z=1            ; pressed: skip the jump back
        GOTO press

        LD   0x10           ; count = count + 1
        ADDI 0x01
        STE  0x10
        STE  0x81           ; show the new count

; ---- debounce the press: wait ~15 ms ----
        LDI  0x00           ; 256 outer passes
        STE  0x11
p_out:  LDI  0x00           ; 256 inner passes, counted in the ACC
p_in:   SUBI 0x01
        SKIP Z=1
        GOTO p_in
        LD   0x11
        SUBI 0x01
        STE  0x11
        SKIP Z=1
        GOTO p_out

; ---- wait until button 0 is released (pin reads 1) ----
release: LD  0x80           ; ACC = PINA
        ANDI 0x01           ; Z = 0 when released
        SKIP Z=0            ; released: skip the jump back
        GOTO release

; ---- debounce the release: wait ~15 ms ----
        LDI  0x00
        STE  0x11
r_out:  LDI  0x00
r_in:   SUBI 0x01
        SKIP Z=1
        GOTO r_in
        LD   0x11
        SUBI 0x01
        STE  0x11
        SKIP Z=1
        GOTO r_out

        GOTO press          ; wait for the next press