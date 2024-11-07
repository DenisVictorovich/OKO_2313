
; ----------------------------------------------------------------------------------------------------------------------------------
; `BL.ASM` (program boot-loader)
; устройство на базе "крохи-2313":
;  _____   ----   ----
;  RESET @|1   \_/  20|= питание (2,8 .. 3,2) вольт {LCD.1}
; Rx PD0 =|2        19|@ PB7 `SCK`<--_-_-_-_
; Tx PD1 =|3  tiny  18|@ PB6 `DO`(`MISO`)-->
; К.Р.-- =|4  2313  17|@ PB5 `DI`(`MOSI`)<--
; К.Р.-- =|5        16|= PB4
; I0 PD2 =|6        15|= PB3           |   {LCD.5}---------|
; I1 PD3 =|7        14|= PB2 {LCD.3}   |   {LCD.6}---------|
; T0 PD4 =|8        13|= PB1 {LCD.4}   |             ||    |
; T1 PD5 =|9        12|= PB0 {LCD.8}   |   {LCD.7}---||----|
;  ЗЕМЛЯ @|10       11|= PD6                         ||  ЗЕМЛЯ
;          -----------                              1 uФ
; @ - выводы для подключения программатора
; ----------------------------------------------------------------------------------------------------------------------------------

.include "tn2313.asm"
.include "macro.asm"

; ----------------------------------------------------------------------------------------------------------------------------------

; -----------------
.def  temp    = r16 ; temporary
; -----------------
.def  par_l   = r17 ; temporary
.def  par_h   = r18 ; temporary
; -----------------
.def  lrc     = r19
; -----------------
.def  page_l  = r20
; -----------------
.def  action  = r22
.def  nibble  = r23
; -----------------
.def  cap_l   = r24
.def  cap_h   = r25
; -----------------

.equ  r_buffer = SRAM_START ; начало приемного буфера порта в оперативной памяти контроллера

.ORG 0x000 ; область загрузчика:

; interrupts links

rjmp   RESET        ; 00) reset handler
rjmp   INT_0        ; 01) external interrupt0 handler
rjmp   INT_1        ; 02) external interrupt1 handler
rjmp   TIM1_CAPT    ; 03) timer1 capture handler
rjmp   TIM1_COMPA   ; 04) timer1 comparea handler
rjmp   TIM1_OVF     ; 05) timer1 overflow handler
rjmp   TIM0_OVF     ; 06) timer0 overflow handler
rjmp   USART0_RXC   ; 07) usart0 rx complete handler
rjmp   USART0_DRE   ; 08) usart0,udr empty handler
rjmp   USART0_TXC   ; 09) usart0 tx complete handler
rjmp   ANA_COMP     ; 10) analog comparator handler
rjmp   PCINT        ; 11) pin change interrupt
rjmp   TIMER1_COMPB ; 12) timer1 compare b handler
rjmp   TIMER0_COMPA ; 13) timer0 compare a handler
rjmp   TIMER0_COMPB ; 14) timer0 compare b handler
rjmp   USI_START    ; 15) usi start handler
rjmp   USI_OVERFLOW ; 16) usi overflow handler
rjmp   EE_READY     ; 17) eeprom ready handler
rjmp   WDT_OVERFLOW ; 18) wdt overflow handler

RESET:

  cli

  ; hw init
  out_i  SPL, low (RAMEND) ; set stack pointer to top of ram
  out_i  ACSR, (1<<ACD) ; analog comparator disable

  out_i  WDTCR, 24
  out_i  WDTCR, 15
  wdr

  rcall  t2313_io_ports_init
  rcall  port_configure

  ; sw init
  ; r_buffer  := 00|00|00 ...
  ; стираем SRAM_SIZE байтов с r_buffer байта
  rcall  r_buffer_init
  clr    temp
  ldi    cap_l, SRAM_SIZE
  clear_memory_loop:
     wdr
     st    Y+, temp
     dec   cap_l
     brne  clear_memory_loop
  clr    temp
  clr    par_l
  clr    par_h
  clr    lrc
  clr    page_l
  rcall  r_buffer_init
  clr    action
  clr    nibble
  clr    cap_l
  clr    cap_h

 LOOP: ; основной цикл
    wdr
    clr    cap_l
    clr    cap_h
    SBIS   PIND, 6
    rjmp   END ; если вывод PD6 замкнут на "землю", то - выход в основное приложение.
    rcall  check_receive
    brts   LOOP

       ; селектор захвата принятого байта, находящегося в ячейке `temp`

          ; начать прием данных
          cpi   temp, 'w'
            breq  action_set
          cpi   temp, 'r'
           breq  action_set

          ; завершить прием данных
          cpi   temp, 13 ; CR
            breq  LOOP ; игнорируем
          cpi   temp, 10 ; LF
            breq  action_do

          ; принимать данные
          rjmp  byte_capture

       ; записать действие (писать{w}, читать{r}, стирать{e})
       action_set:
             mov    action, temp
             rcall   r_buffer_init
             clr    nibble
             clr    lrc
             rjmp   LOOP

       ; захват принятого байта (HI,LO)
       byte_capture:
             sbrc   nibble, 0
             rjmp   byte_receive ; nibble.0 = 1 (LO)
             mov    par_l, temp
             rcall   s2d
             swap   par_l ; move to the HI nibble
             mov    par_h, par_l ; capture the HI nibble
             inc    nibble
             rjmp   LOOP

       ; захват принятого байта (LO)
       byte_receive:
             mov    par_l, temp ; capture the LO nibble
             rcall   s2d
             inc    nibble
             or     par_h, par_l
             ; байт принят в символьной форме и находится в `par_h`
             add    lrc, par_h
             st     Y+,  par_h ; store byte
             rjmp   LOOP

       action_do:
             mov   cap_l, YL
             mov   cap_h, YH
             rcall  r_buffer_init
             tst   lrc ; проверка lrc
               brne  LOOP ; lrc не совпадает

             ; номер обрабатываемой страницы
             ld    page_l, Y+

             ; проверка номера страницы FLASH [256/16=16 .. 1024/16=64]
             cpi   page_l, 16
             brlo  END ; jump if (page_l < 16)
             cpi   page_l, 64
             brsh  END ; jump if (page_l >= 64)

       action_do_1:
             ; количество принятых байтов должно равняться (2 и 64 и 1){w}, либо (2 и 1){r,e}
             cpi   action, 'w'
               breq  write_do
             cpi   action, 'r'
               breq  read_do
             rjmp   LOOP

       write_do:
             rcall  write_flash2
             rcall  SEND_PAGE
             rjmp   LOOP

       read_do:
             rcall  SEND_PAGE
             rjmp   LOOP

; -----------------------------------------------------------------------------------------------------------------------------

END:  JMP  MAIN_APP

; -----------------------------------------------------------------------------------------------------------------------------

; посылка данных страницы
SEND_PAGE: ; (ui8 p { page_l })
          rcall  r_buffer_init

          ; send 'w' для похожести
          ldi    par_l, 'w'
            rcall   send

          ; clear LRC
          clr    lrc

          ; send page number
          mov    par_h, page_l
            rcall   send2

          rcall  t2313_page_to_Z_position
          ldi    cap_l, (PAGESIZE<<1)
        send_loop:
          lpm    par_h, Z+
            rcall   send2
          dec    cap_l
          brne   send_loop

          ; send2(-(signed char)LRC)
          neg    lrc
          mov    par_h, lrc
            rcall   send2

          ; send(CR), send(LF)
          ldi    par_l, 13
            rcall   send
          ldi    par_l, 10
            rcall   send
          rcall  wait_end_of_sending
          ret

; -----------------------------------------------------------------------------------------------------------------------------

r_buffer_init:
          ldi    YL, r_buffer
          ldi    YH, 0
          ret

; -----------------------------------------------------------------------------------------------------------------------------

t2313_io_ports_init:

          ser   temp
          out   PORTB, temp
          out   PORTD, temp

          clr   temp
          out   DDRB, temp
          out   DDRD, temp

          ret

; -----------------------------------------------------------------------------------------------------------------------------

t2313_page_to_Z_position:
          ; --- ПОЗИЦИОНИРОВАНИЕ Z-УКАЗАТЕЛЯ ---
          ; ВНИМАНИЕ! ТОЛЬКО ДЛЯ PAGESIZE == 16 x 2 байтов:
          ; 256 / (16 x 2) = 8 pages
          ; ZL := (page_l % 8) x 32 = (page_l << 5)
          ; ZH := (page_l / 8)      = (page_l >> 3)
          mov    temp, page_l
          andi   temp, 7
          swap   temp
          lsl    temp
          mov    ZL, temp
          mov    temp, page_l
          lsr    temp
          lsr    temp
          lsr    temp
          mov    ZH, temp
          ; -----------------------------------------------
          ret

; -----------------------------------------------------------------------------------------------------------------------------

.include "sp_0.asm"     ; serial port # 0
.include "bl_t2313.asm" ; boot load functions

; -----------------------------------------------------------------------------------------------------------------------------

.def  A_COND  = r23
.def  B_COND  = r24
.def  C_COND  = r25

.equ  COND_D  = DDRB
.equ  COND_P  = PORTB

; -----------------------------------------------------------------------------------------------------------------------------

.ORG 0x100 ; область приложения:

MAIN_APP:     rjmp BEGIN ; 00) `program reset the device`
INT_0:        reti       ; 01) external interrupt0 handler
INT_1:        reti       ; 02) external interrupt1 handler
TIM1_CAPT:    reti       ; 03) timer1 capture handler
TIM1_COMPA:   reti       ; 04) timer1 comparea handler
TIM1_OVF:     reti       ; 05) timer1 overflow handler
TIM0_OVF:     reti       ; 06) timer0 overflow handler
USART0_RXC:   reti       ; 07) usart0 rx complete handler
USART0_DRE:   reti       ; 08) usart0,udr empty handler
USART0_TXC:   reti       ; 09) usart0 tx complete handler
ANA_COMP:     reti       ; 10) analog comparator handler
PCINT:        reti       ; 11) pin change interrupt
TIMER1_COMPB: reti       ; 12) timer1 compare b handler
TIMER0_COMPA: reti       ; 13) timer0 compare a handler
TIMER0_COMPB: reti       ; 14) timer0 compare b handler
USI_START:    reti       ; 15) usi start handler
USI_OVERFLOW: reti       ; 16) usi overflow handler
EE_READY:     reti       ; 17) eeprom ready handler
WDT_OVERFLOW: rjmp BEGIN ; 18) wdt overflow handler
BEGIN:        ; ОСНОВНОЕ ПРИЛОЖЕНИЕ {ПОДЛЕЖИТ ОБНОВЛЕНИЮ}
              ldi temp,   0b11111111
              ldi A_COND, 0b11110000
              ldi B_COND, 0b00001111
              ldi C_COND, 0b00000000
              OUT COND_D, temp
           main_loop:
              wdr
              rcall  check_receive
              brts   main_loop
              ; селектор захвата принятого байта, находящегося в ячейке `temp`
              cpi    temp, 'A'
                 breq  _A_
              cpi    temp, 'B'
                 breq  _B_
              cpi    temp, 'C'
                 breq  _C_
              ; <...>
              cpi    temp, 'Z'
                 breq  GO_TO_RESET
              rjmp   main_loop
        _A_:  OUT COND_P, A_COND
              rjmp   main_loop
        _B_:  OUT COND_P, B_COND
              rjmp   main_loop
        _C_:  OUT COND_P, C_COND
              rjmp   main_loop
              ; <...>

        GO_TO_RESET:  JMP  RESET

; -----------------------------------------------------------------------------------------------------------------------------

