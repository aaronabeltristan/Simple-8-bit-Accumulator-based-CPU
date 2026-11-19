; GPIO test: copies the port A pins to port B, then shows the port B pins on the display
; Port B pins 7..4 are outputs, pins 3..0 are inputs (pulled up on the board)
; With port A pins = 0x0A: PORTB = 0x0A, so pins 7..4 drive 0000, pins 3..0 float high (1111)
; Expected: PINB = 0x0F, DISPLAY = 0x0F (15)

        LDI  0xF0       ; pins 7..4 outputs, 3..0 inputs
        STE  0x86       ; DDRB = 0xF0
loop:   LD   0x80       ; ACC = PINA (port A pin levels)
        STE  0x85       ; PORTB = ACC (only the output pins drive it)
        LD   0x84       ; ACC = PINB (port B pin levels)
        STE  0x81       ; DISPLAY = ACC
        GOTO loop       ; keep copying
