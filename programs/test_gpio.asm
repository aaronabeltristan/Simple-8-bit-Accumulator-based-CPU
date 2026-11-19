; GPIO test: copies the port A pins to port B and port C, then shows the port B pins on the LEDs
; Port B pins 7..4 are outputs, pins 3..0 are inputs (pulled up on the board); port C is all outputs
; With port A pins = 0x0A: PORTB = PORTC = 0x0A, so port B pins 7..4 drive 0000 and pins 3..0 float high
; Expected: port C pins = 0x0A, PINB = 0x0F, OUT = 0x0F

        LDI  0xF0       ; port B pins 7..4 outputs, 3..0 inputs
        STE  0x86       ; DDRB = 0xF0
        LDI  0xFF       ; port C all outputs
        STE  0x89       ; DDRC = 0xFF
loop:   LD   0x80       ; ACC = PINA (port A pin levels)
        STE  0x85       ; PORTB = ACC (only the output pins drive it)
        STE  0x88       ; PORTC = ACC
        LD   0x84       ; ACC = PINB (port B pin levels)
        STE  0x81       ; OUT = ACC (onboard LEDs)
        GOTO loop       ; keep copying
