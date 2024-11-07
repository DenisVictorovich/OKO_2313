
; -------------------------------------------------------------------------------------------------------------------- sp_0.inc

port_configure: ; (void)
    ; flush the buffer
     sbis  UCSRA, RXC
     rjmp  port_configure_1
     in    temp,  UDR
     rjmp  port_configure
  port_configure_1:
     out_i  UBRRL, 51 ; <- 8 MHz ; 9.6 k {(8000000 / 9600 / 16) - 1 = 51,08333...}
     out_i  UBRRH, 0
     out_i  UCSRB, (1<<RXEN)|(1<<TXEN)
     out_i  UCSRC, (3<<UCSZ0)
     ret

; -----------------------------------------------------------------------------------------------------------------------------

check_receive: ; (void), return: if SREG.T=0, then received, result in `temp`
     set
     sbis  UCSRA, RXC
     ret
     in    temp,  UDR
     in    par_l, UCSRA
     bst   par_l, DOR
     ret

; -----------------------------------------------------------------------------------------------------------------------------

send: ; (char b{ par_l })
      in      temp, UCSRA
      bst     temp, UDRE ; проверка готовности к передаче следующего байта
      brtc    send
      out     UDR, par_l
      ret

; -----------------------------------------------------------------------------------------------------------------------------

wait_end_of_sending: ; (void)
                     in    temp, UCSRA
                     sbr   temp, (1<<TXC)
                     out   UCSRA, temp
                  wait_end_of_sending_1:
                     in    temp, UCSRA
                     sbrs  temp, TXC
                     rjmp  wait_end_of_sending_1
                     ret

; -----------------------------------------------------------------------------------------------------------------------------

; Преобразовать число 0..15 в символ `0`..`9` `A`..`F`
d2s: ; (char v{ par_l })
     subi    par_l, 208 ; par_l+='0'
     cpi     par_l, 58  ; if(par_l>'9'), carry set if ('9'+1)>par_l
     brcs    d2s_1      ; branch if carry set
     subi    par_l, 249 ; par_l+=7
  d2s_1:
     ret

; -----------------------------------------------------------------------------------------------------------------------------

; Преобразовать символ `0`..`9` `A`..`F`..`N` в число 0..15..23
s2d: ; (char v{ par_l })
     subi    par_l, 48 ; par_l-='0'
     cpi     par_l, 10 ; if(par_l>9), carry set if (9+1)>par_l
     brcs    s2d_1     ; branch if carry set
     subi    par_l, 7  ; par_l-=7
  s2d_1:
     ret

; -----------------------------------------------------------------------------------------------------------------------------

send2: ; (char b{ par_h })
       add   lrc, par_h ; -> LRC
       mov   par_l, par_h
       ; hi digit send
       swap  par_l ; меняем местами "нибблы"
       andi  par_l, 15
       rcall d2s
       rcall send
       ; lo digit send
       mov   par_l, par_h
       andi  par_l, 15
       rcall d2s
       rcall send
       ret

; -----------------------------------------------------------------------------------------------------------------------------

