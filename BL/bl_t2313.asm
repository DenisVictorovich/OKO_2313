
; ----------------------------------------------------------------------------------------------------------------- bl_t2313.inc

; Стереть страницу в {PAGESIZE x 2} байтов с номером p
erase_flash2: ; (ui8 p { page_l })
              rcall  t2313_page_to_Z_position
              ; Стирание страницы: SPMCSR := PGERS | SPMEN
              out_i  SPMCSR, (1<<PGERS)|(1<<SPMEN)
              spm ; Инструкция SPM
              ret

; -----------------------------------------------------------------------------------------------------------------------------

; Записать страницу в {PAGESIZE x 2} байтов с номером p
write_flash2: ; (ui16* b { r_buffer+1 }, ui8 p { page_l })
              rcall  erase_flash2
              rcall  t2313_page_to_Z_position
              ldi    cap_l, PAGESIZE
            ; Запись в буфер страницы, копировать из `r_buffer+1`
            write_flash2_loop:
              ld     r0, Y+ ; hi
              ld     r1, Y+ ; lo
              ; Запись в буфер страницы: SPMCSR := SPMEN
              out_i  SPMCSR, (1<<SPMEN) ; Загрузить постоянную (SPMEN) в регистр SPMCSR
              spm ; Инструкция SPM
              adiw   ZH:ZL, 2
              dec    cap_l
              brne   write_flash2_loop
              subi   ZL, low (PAGESIZE<<1) ; restore pointer
              sbci   ZH, high(PAGESIZE<<1) ; обязательно!
              ; Запись страницы: SPMCSR := (PGWRT | SPMEN)
              out_i  SPMCSR, (1<<PGWRT)|(1<<SPMEN) ; Загрузить постоянную (PGWRT | SPMEN) в регистр SPMCSR
              spm ; Инструкция SPM
              ret

; -----------------------------------------------------------------------------------------------------------------------------

