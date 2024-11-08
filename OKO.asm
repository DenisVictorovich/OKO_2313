
; Александру Григорьевичу Столетову (1839) посвящается ...

; Цель разработки:
;    изучить взаимодествие с однокристальными фото-кино-камерами
;    на примере простейшего образца `ov7670`, научиться конвертировать сигналы
;    с камеры в асинхронный последовательный поток данных и обрабатывать эти данные
;    на ЭВМ в реальном времени.

; Высокая цель будущего:
;    если станет известно: как с помощью электрических сигналов
;    передавать визуальную информацию в головной мозг, воздействуя на ионные каналы
;    нервных клеток; то можно будет посредством подобного устройства частично вернуть
;    зрение незрячему человеку или животному.

; Преимущества перед прототипом:
;    габариты контроллера `tiny-2313` до 3 x 3 мм;
;    ПО на ассемблере, что существенно способствует оптимизации кода и бесплатности
;    среды разработки, а также трансляцию можно провести, используя приложение `DOS-box`

; `ov76_m8.asm` : `ov7670` connection first step, NDV
; Прототип:
;    Source code for application to transmit image from ov7670 to PC via USB
;    Example for Arduino Uno/Nano
;    By Siarhei Charkes in 2015
;    http://privateblog.info

.include "include/tn2313.asm"
.include "include/macro.asm"

.def  t_0     = r16
.def  t_1     = r17
.def  t_2     = r18
.def  t_3     = r19
.def  delay_c = r20
.def  cnt_2   = r21

; регистровая пара «W»{NDV} для 16-разрядных операций
.def  W_lo    = R24
.def  W_hi    = R25

; `OV7670` connection
.equ   CAM_DDR       = DDRD
.equ   CAM_PORT      = PORTD
.equ   CAM_PIN       = PIND
.equ   CAM_XCLK      = 2 ; тактовый сигнал 8 МГц (CKOUT необходимо настроить).
.equ   CAM_VSYNC     = 3 ; кадровая синхронизация.
.equ   CAM_PCLK      = 4 ; пиксельная синхронизация.
.equ   CAM_DATA_DDR  = DDRB
.equ   CAM_DATA_PORT = PORTB
.equ   CAM_DATA_PIN  = PINB

; ВМЕСТО КВАРЦЕВОГО РЕЗОНАТОРА ЗДЕСЬ <<I2C>>
.equ   i2c_DDR       = DDRA
.equ   i2c_PORT      = PORTA
.equ   i2c_PIN       = PINA
.equ   i2c_SDA       = 1
.equ   i2c_SCL       = 0

; `asynchronous transmitter`
.equ   AT_DDR  = DDRD
.equ   AT_PORT = PORTD
.equ   AT_PIN  = 5

.ORG 0x100 ; ЗАПИСЫВАЕМ ПОВЕРХ ЗАГРУЗЧИКА ЕГО СРЕДСТВАМИ

; interrupts links
RESET:      rjmp    BEGIN          ; 00   reset handler
            reti                   ; 01   external interrupt0 handler
            reti                   ; 02   external interrupt1 handler
            reti                   ; 03   timer1 capture handler
            reti                   ; 04   timer1 compare a handler
            reti                   ; 05   timer1 overflow handler
            reti                   ; 06   timer0 overflow handler
            reti                   ; 07   usart0 rx complete handler
            reti                   ; 08   usart0,udr empty handler
            reti                   ; 09   usart0 tx complete handler
            reti                   ; 0a   analog comparator handler
            reti                   ; 0b   pin change interrupt
            reti                   ; 0c   timer1 compare b handler
            reti                   ; 0d   timer0 compare a handler
            reti                   ; 0e   timer0 compare b handler
            reti                   ; 0f   usi start handler
            reti                   ; 10   usi overflow handler
            reti                   ; 11   eeprom ready handler
            rjmp    RESET          ; 12   wdt overflow handler

; ЗАДЕРЖКИ СРЕДСТВАМИ ЯДРА ПРИ ТАКТОВОЙ ЧАСТОТЕ 8 МГц

delay_1_ms:
    ; Generated by delay loop calculator
    ; at http://www.bretmulvey.com/avrdelay.html
    ;
    ; Delay 8 000 cycles
    ; 1ms at 8.0 MHz
        wdr
        ldi  t_0, 11
        ldi  t_1, 99
    L1: dec  t_1
        brne L1
        dec  t_0
        brne L1
        ret

delay_100_ms:
    ; Generated by delay loop calculator
    ; at http://www.bretmulvey.com/avrdelay.html
    ;
    ; Delay 800 000 cycles
    ; 100ms at 8.0 MHz
        wdr
        ldi  t_0, 5
        ldi  t_1, 15
        ldi  t_2, 242
    L2: dec  t_2
        brne L2
        dec  t_1
        brne L2
        dec  t_0
        brne L2
        ret

delay_1_second:
    ; Generated by delay loop calculator
    ; at http://www.bretmulvey.com/avrdelay.html
    ;
    ; Delay 8 000 000 cycles
    ; 1s at 8.0 MHz
        wdr
        ldi  t_0, 41
        ldi  t_1, 150
        ldi  t_2, 128
    L3: dec  t_2
        brne L3
        dec  t_1
        brne L3
        dec  t_0
        brne L3
        ret

BEGIN:
        cli
        wdr
        out_i  SPL, low(RAMEND) ; set stack pointer to top of r.a.m.
        out_i  ACSR, 128 ; analog comparator disable
        out_i  WDTCR, 24
        out_i  WDTCR, 15
        wdr
        rcall  peripheral_init
        rcall  delay_1_second
        rcall  delay_1_second
        rcall  delay_1_second
        ldi_Z  welcome_token
        rcall  AT_send_string
        rcall  cam_init
        rcall  cam_set_res
        rcall  cam_set_color
        ldi    t_2, 0x11
        ldi    t_3, 12
        rcall  cam_wr_cell
        wdr
        ldi_Z  init_token
        rcall  AT_send_string
     LOOP:
        rcall  capture_img_320x240
        rjmp   LOOP

welcome_token: .db ">>> welcome ",13,10,0,0
init_token:    .db ">>> initialization complete ",13,10,0,0

peripheral_init:
        out_i  CAM_DATA_DDR,  0b00000000
        out_i  CAM_DATA_PORT, 0b11111111 ; ?
      ; out_i  CAM_DATA_PORT, 0b00000000 ; ?
        cbi    CAM_DDR,       CAM_VSYNC
        cbi    CAM_DDR,       CAM_PCLK
        sbi    CAM_PORT,      CAM_VSYNC  ; ?
      ; cbi    CAM_PORT,      CAM_VSYNC  ; ?
        sbi    CAM_PORT,      CAM_PCLK   ; ?
      ; cbi    CAM_PORT,      CAM_PCLK   ; ?
        rcall  i2c_init
        SBI    AT_PORT, AT_PIN
        SBI    AT_DDR,  AT_PIN
        ret

.include "include/ov7670.asm"
.include "include/I2C.asm"

cam_wr_cell: ; (t_2{cell}, t_3{data})
        mov     R14, t_2
        mov     R15, t_3
        rcall   i2c_start
        ldi     t_1, camAddr_WR
        rcall   i2c_write
        mov     t_1, R14
        rcall   i2c_write
        mov     t_1, R15
        rcall   i2c_write
        rcall   i2c_stop
        rcall   delay_1_ms
        ret

; частота передачи данных настроена как 8 / 4 = 2 МГц
.MACRO AT_send_bit
          nop                ; 1 clc - 0
          BST   t_0, @0      ; 1 clc - 1
          BLD   R15, AT_PIN  ; 1 clc - 2
          OUT   AT_PORT, R15 ; 1 clc - 3 {вывод}
.ENDMACRO

; было в пред.версии:
; << при частоте ядра 16 МГц получаем частоту передачи 1 МГц
;    {без делителя получилось бы 16 МГц / 3 = 5 1/3 МГц} >>
AT_send_byte: ; (t_0)
   IN    R15, AT_PORT
   ; start
   CBI   AT_PORT, AT_PIN ; 2 clc
   ; lo nibble
   AT_send_bit 0
   AT_send_bit 1
   AT_send_bit 2
   AT_send_bit 3
   ; hi nibble
   AT_send_bit 4
   AT_send_bit 5
   AT_send_bit 6
   AT_send_bit 7
   ; stop
   nop
   nop ; 01) ЧАСТОТА ПЕРЕДАЧИ F_clc / 4
   nop ; 02) ЧАСТОТА ПЕРЕДАЧИ F_clc / 4
   SBI   AT_PORT, AT_PIN ; 2 clc
   nop ; 01) ЧАСТОТА ПЕРЕДАЧИ F_clc / 4
   nop ; 02) ЧАСТОТА ПЕРЕДАЧИ F_clc / 4
   RET

AT_send_string: ; (ZH:ZL) ldi_Z <label>
        LPM     t_0, Z+
        cpi     t_0, 0
        breq    AT_send_string_end
        rcall   AT_send_byte
        rjmp    AT_send_string
     AT_send_string_end:
        ret

capture_one_pixel:
        rcall  wait_for_low_PCLK
        IN     t_0, CAM_DATA_PIN
        rcall  AT_send_byte
        rcall  wait_for_high_PCLK
        rcall  wait_for_low_PCLK
        rcall  wait_for_high_PCLK
        ret

frame_synchro_token: .db "*RDY*",0

capture_img_320x240: ; использованы регистры t_0, t_1, W_lo, W_hi
        ldi_Z   frame_synchro_token
        rcall   AT_send_string
        rcall   AT_send_byte
        rcall   wait_for_high_VSYNC
        rcall   wait_for_low_VSYNC
        ldi_W   (320 * 240 / 2)
     frame_loop:
        wdr
        rcall  capture_one_pixel
        rcall  capture_one_pixel
        SBIW   W_hi:W_lo, 1
        brne   frame_loop
        rcall  delay_100_ms
        ret

i2c_ack_bit_occasion:
        ldi     t_0, '.'
        rcall   AT_send_byte
        ret
