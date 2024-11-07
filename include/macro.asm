
  ; `macro.asm`

  ; --------------------------------------------------------------------------------------------------------------------------------

  .MACRO out_i
            ldi  t_0, @1
            out  @0, t_0
  .ENDMACRO

  .MACRO ldi_Z
            ldi  ZH, high(@0<<1)
            ldi  ZL, low (@0<<1)
  .ENDMACRO

  .MACRO ldi_Y
            ldi  YH, high(@0)
            ldi  YL, low (@0)
  .ENDMACRO

  .MACRO ldi_X
            ldi  XH, high(@0)
            ldi  XL, low (@0)
  .ENDMACRO

  .MACRO ldi_W
            ldi  W_hi, high(@0)
            ldi  W_lo, low (@0)
  .ENDMACRO

  .MACRO var_delay_3_clc
            ldi   delay_c, @0
         var_delay_lbl:
            dec   delay_c
            brne  var_delay_lbl
  .ENDMACRO

  ; --------------------------------------------------------------------------------------------------------------------------------

