; Buttons: shows which port A buttons are pressed on the onboard LEDs
; Buttons pull their pins to 0, so NOT turns "pressed" into 1

loop:   LD   0x80       ; ACC = PINA (0 = pressed)
        NOT             ; ACC = ~ACC (1 = pressed)
        STE  0x81       ; OUT = ACC: the LEDs show the pressed buttons
        GOTO loop       ; read the buttons again