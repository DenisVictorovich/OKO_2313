
; ov7670.asm
; источник:
; {
;    Source code for application to transmit image from ov7670 to PC via USB
;    Example for Arduino Uno/Nano
;    By Siarhei Charkes in 2015
;    http://privateblog.info
; }

; НЕОБХОДИМО:
;    cam_wr_cell(t_2{cell}, t_3{data})
;    delay_100_ms()
;    CAM_DDR, CAM_PORT, CAM_PIN, CAM_VSYNC {кадровая синхронизация}, CAM_PCLK {пиксельная синхронизация}
;    CAM_DATA_DDR, CAM_DATA_PIN

.MACRO wait_for_high
          wait_for_high_lbl: sbis CAM_PIN, @0
                             rjmp wait_for_high_lbl
.ENDMACRO

.MACRO wait_for_low
          wait_for_low_lbl: sbic CAM_PIN, @0
                            rjmp wait_for_low_lbl
.ENDMACRO

.equ   vga        = 0
.equ   qvga       = 1
.equ   qqvga      = 2
.equ   yuv422     = 0
.equ   rgb565     = 1
.equ   bayerRGB   = 2

.equ   camAddr_WR = 0x42
.equ   camAddr_RD = camAddr_WR | 1

; Registers
.equ  REG_GAIN               = 0x00    ; Gain lower 8 bits (rest in vref)
.equ  REG_BLUE               = 0x01    ; blue gain
.equ  REG_RED                = 0x02    ; red gain
.equ  REG_VREF               = 0x03    ; Pieces of GAIN, VSTART, VSTOP
.equ  REG_COM1               = 0x04    ; Control 1
.equ  COM1_CCIR656           = 0x40    ; CCIR656 enable

.equ  REG_BAVE               = 0x05    ; U/B Average level
.equ  REG_GbAVE              = 0x06    ; Y/Gb Average level
.equ  REG_AECHH              = 0x07    ; AEC MS 5 bits
.equ  REG_RAVE               = 0x08    ; V/R Average level
.equ  REG_COM2               = 0x09    ; Control 2
.equ  COM2_SSLEEP            = 0x10    ; Soft sleep mode
.equ  REG_PID                = 0x0a    ; Product ID MSB
.equ  REG_VER                = 0x0b    ; Product ID LSB
.equ  REG_COM3               = 0x0c    ; Control 3
.equ  COM3_SWAP              = 0x40    ; Byte swap
.equ  COM3_SCALEEN           = 0x08    ; Enable scaling
.equ  COM3_DCWEN             = 0x04    ; Enable downsamp/crop/window
.equ  REG_COM4               = 0x0d    ; Control 4
.equ  REG_COM5               = 0x0e    ; All "reserved"
.equ  REG_COM6               = 0x0f    ; Control 6
.equ  REG_AECH               = 0x10    ; More bits of AEC value
.equ  REG_CLKRC              = 0x11    ; Clock control
.equ  CLK_EXT                = 0x40    ; Use external clock directly
.equ  CLK_SCALE              = 0x3f    ; Mask for internal clock scale
.equ  REG_COM7               = 0x12    ; Control 7  //REG mean address.
.equ  COM7_RESET             = 0x80    ; Register reset
.equ  COM7_FMT_MASK          = 0x38
.equ  COM7_FMT_VGA           = 0x00
.equ  COM7_FMT_CIF           = 0x20    ; CIF format
.equ  COM7_FMT_QVGA          = 0x10    ; QVGA format
.equ  COM7_FMT_QCIF          = 0x08    ; QCIF format
.equ  COM7_RGB               = 0x04    ; bits 0 and 2 - RGB format
.equ  COM7_YUV               = 0x00    ; YUV
.equ  COM7_BAYER             = 0x01    ; Bayer format
.equ  COM7_PBAYER            = 0x05    ; "Processed bayer"
.equ  REG_COM8               = 0x13    ; Control 8
.equ  COM8_FASTAEC           = 0x80    ; Enable fast AGC/AEC
.equ  COM8_AECSTEP           = 0x40    ; Unlimited AEC step size
.equ  COM8_BFILT             = 0x20    ; Band filter enable
.equ  COM8_AGC               = 0x04    ; Auto gain enable
.equ  COM8_AWB               = 0x02    ; White balance enable
.equ  COM8_AEC               = 0x01    ; Auto exposure enable
.equ  REG_COM9               = 0x14    ; Control 9- gain ceiling
.equ  REG_COM10              = 0x15    ; Control 10
.equ  COM10_HSYNC            = 0x40    ; HSYNC instead of HREF
.equ  COM10_PCLK_HB          = 0x20    ; Suppress PCLK on horiz blank
.equ  COM10_HREF_REV         = 0x08    ; Reverse HREF
.equ  COM10_VS_LEAD          = 0x04    ; VSYNC on clock leading edge
.equ  COM10_VS_NEG           = 0x02    ; VSYNC negative
.equ  COM10_HS_NEG           = 0x01    ; HSYNC negative
.equ  REG_HSTART             = 0x17    ; Horiz start high bits
.equ  REG_HSTOP              = 0x18    ; Horiz stop high bits
.equ  REG_VSTART             = 0x19    ; Vert start high bits
.equ  REG_VSTOP              = 0x1a    ; Vert stop high bits
.equ  REG_PSHFT              = 0x1b    ; Pixel delay after HREF
.equ  REG_MIDH               = 0x1c    ; Manuf. ID high
.equ  REG_MIDL               = 0x1d    ; Manuf. ID low
.equ  REG_MVFP               = 0x1e    ; Mirror / vflip
.equ  MVFP_MIRROR            = 0x20    ; Mirror image
.equ  MVFP_FLIP              = 0x10    ; Vertical flip

.equ  REG_AEW                = 0x24    ; AGC upper limit
.equ  REG_AEB                = 0x25    ; AGC lower limit
.equ  REG_VPT                = 0x26    ; AGC/AEC fast mode op region
.equ  REG_HSYST              = 0x30    ; HSYNC rising edge delay
.equ  REG_HSYEN              = 0x31    ; HSYNC falling edge delay
.equ  REG_HREF               = 0x32    ; HREF pieces
.equ  REG_TSLB               = 0x3a    ; lots of stuff
.equ  TSLB_YLAST             = 0x04    ; UYVY or VYUY - see com13
.equ  REG_COM11              = 0x3b    ; Control 11
.equ  COM11_NIGHT            = 0x80    ; NIght mode enable
.equ  COM11_NMFR             = 0x60    ; Two bit NM frame rate
.equ  COM11_HZAUTO           = 0x10    ; Auto detect 50/60 Hz
.equ  COM11_50HZ             = 0x08    ; Manual 50Hz select
.equ  COM11_EXP              = 0x02
.equ  REG_COM12              = 0x3c    ; Control 12
.equ  COM12_HREF             = 0x80    ; HREF always
.equ  REG_COM13              = 0x3d    ; Control 13
.equ  COM13_GAMMA            = 0x80    ; Gamma enable
.equ  COM13_UVSAT            = 0x40    ; UV saturation auto adjustment
.equ  COM13_UVSWAP           = 0x01    ; V before U - w/TSLB
.equ  REG_COM14              = 0x3e    ; Control 14
.equ  COM14_DCWEN            = 0x10    ; DCW/PCLK-scale enable
.equ  REG_EDGE               = 0x3f    ; Edge enhancement factor
.equ  REG_COM15              = 0x40    ; Control 15
.equ  COM15_R10F0            = 0x00    ; Data range 10 to F0
.equ  COM15_R01FE            = 0x80    ;            01 to FE
.equ  COM15_R00FF            = 0xc0    ;            00 to FF
.equ  COM15_RGB565           = 0x10    ; RGB565 output
.equ  COM15_RGB555           = 0x30    ; RGB555 output
.equ  REG_COM16              = 0x41    ; Control 16
.equ  COM16_AWBGAIN          = 0x08    ; AWB gain enable
.equ  REG_COM17              = 0x42    ; Control 17
.equ  COM17_AECWIN           = 0xc0    ; AEC window - must match COM4
.equ  COM17_CBAR             = 0x08    ; DSP Color bar

; This matrix defines how the colors are generated, must be
; tweaked to adjust hue and saturation.

; Order: v-red, v-green, v-blue, u-red, u-green, u-blue
; They are nine-bit signed quantities, with the sign bit
; stored in 0x58. Sign for v-red is bit 0, and up from there.

.equ  REG_CMATRIX_BASE       = 0x4f
.equ  CMATRIX_LEN            = 6
.equ  REG_CMATRIX_SIGN       = 0x58
.equ  REG_BRIGHT             = 0x55    ; Brightness
.equ  REG_CONTRAS            = 0x56    ; Contrast control
.equ  REG_GFIX               = 0x69    ; Fix gain control
.equ  REG_REG76              = 0x76    ; OV's name
.equ  R76_BLKPCOR            = 0x80    ; Black pixel correction enable
.equ  R76_WHTPCOR            = 0x40    ; White pixel correction enable
.equ  REG_RGB444             = 0x8c    ; RGB 444 control
.equ  R444_ENABLE            = 0x02    ; Turn on RGB444, overrides 5x5
.equ  R444_RGBX              = 0x01    ; Empty nibble at end
.equ  REG_HAECC1             = 0x9f    ; Hist AEC/AGC control 1
.equ  REG_HAECC2             = 0xa0    ; Hist AEC/AGC control 2
.equ  REG_HAECC3             = 0xa6    ; Hist AEC/AGC control 3
.equ  REG_HAECC4             = 0xa7    ; Hist AEC/AGC control 4
.equ  REG_HAECC5             = 0xa8    ; Hist AEC/AGC control 5
.equ  REG_HAECC6             = 0xa9    ; Hist AEC/AGC control 6
.equ  REG_HAECC7             = 0xaa    ; Hist AEC/AGC control 7
.equ  REG_BD50MAX            = 0xa5    ; 50hz banding step limit
.equ  REG_BD60MAX            = 0xab    ; 60hz banding step limit

.equ  MTX1                   = 0x4f    ; Matrix Coefficient 1
.equ  MTX2                   = 0x50    ; Matrix Coefficient 2
.equ  MTX3                   = 0x51    ; Matrix Coefficient 3
.equ  MTX4                   = 0x52    ; Matrix Coefficient 4
.equ  MTX5                   = 0x53    ; Matrix Coefficient 5
.equ  MTX6                   = 0x54    ; Matrix Coefficient 6
.equ  MTXS                   = 0x58    ; Matrix Coefficient Sign
.equ  AWBC7                  = 0x59    ; AWB Control 7
.equ  AWBC8                  = 0x5a    ; AWB Control 8
.equ  AWBC9                  = 0x5b    ; AWB Control 9
.equ  AWBC10                 = 0x5c    ; AWB Control 10
.equ  AWBC11                 = 0x5d    ; AWB Control 11
.equ  AWBC12                 = 0x5e    ; AWB Control 12
.equ  REG_GFI                = 0x69    ; Fix gain control
.equ  GGAIN                  = 0x6a    ; G Channel AWB Gain
.equ  DBLV                   = 0x6b
.equ  AWBCTR3                = 0x6c    ; AWB Control 3
.equ  AWBCTR2                = 0x6d    ; AWB Control 2
.equ  AWBCTR1                = 0x6e    ; AWB Control 1
.equ  AWBCTR0                = 0x6f    ; AWB Control 0

qvga_ov7670:
        .db  REG_COM14,  0x19
        .db  0x72,       0x11
        .db  0x73,       0xf1

        .db  REG_HSTART, 0x16
        .db  REG_HSTOP,  0x04
        .db  REG_HREF,   0xa4
        .db  REG_VSTART, 0x02
        .db  REG_VSTOP,  0x7a
        .db  REG_VREF,   0x0a

      ; .db  REG_HSTART, 0x16
      ; .db  REG_HSTOP,  0x04
      ; .db  REG_HREF,   0x24
      ; .db  REG_VSTART, 0x02
      ; .db  REG_VSTOP,  0x7a
      ; .db  REG_VREF,   0x0a

        .db  0xff, 0xff ; END MARKER

yuv422_ov7670:
        .db  REG_COM7,   0x0 ; Selects YUV mode
        .db  REG_RGB444, 0   ; No RGB444 please
        .db  REG_COM1,   0
        .db  REG_COM15,  COM15_R00FF
        .db  REG_COM9,   0x6A ; 128x gain ceiling; 0x8 is reserved bit
        .db  0x4f,       0x80 ; "matrix coefficient 1"
        .db  0x50,       0x80 ; "matrix coefficient 2"
        .db  0x51,       0    ; vb
        .db  0x52,       0x22 ; "matrix coefficient 4"
        .db  0x53,       0x5e ; "matrix coefficient 5"
        .db  0x54,       0x80 ; "matrix coefficient 6"
        .db  REG_COM13,  COM13_UVSAT
        .db  0xff, 0xff ; END MARKER

ov7670_default_regs:
        ; from the linux driver
        .db  REG_COM7, COM7_RESET
        .db  REG_TSLB, 0x04 ; OV
        .db  REG_COM7, 0    ; VGA

        ; Set the hardware window. These values from OV don't entirely
        ; make sense - hstop is less than hstart. But they work...

        .db  REG_HSTART, 0x13
        .db  REG_HSTOP,  0x01
        .db  REG_HREF,   0xb6
        .db  REG_VSTART, 0x02
        .db  REG_VSTOP,  0x7a
        .db  REG_VREF,   0x0a

        .db  REG_COM3,  0
        .db  REG_COM14, 0
        ; Mystery scaling numbers
        .db  0x70, 0x3a
        .db  0x71, 0x35
        .db  0x72, 0x11
        .db  0x73, 0xf0
        .db  0xa2, 1 ; 0x02 changed to 1
        .db  REG_COM10, 0x0
        ; Gamma curve values
        .db  0x7a, 0x20
        .db  0x7b, 0x10
        .db  0x7c, 0x1e
        .db  0x7d, 0x35
        .db  0x7e, 0x5a
        .db  0x7f, 0x69
        .db  0x80, 0x76
        .db  0x81, 0x80
        .db  0x82, 0x88
        .db  0x83, 0x8f
        .db  0x84, 0x96
        .db  0x85, 0xa3
        .db  0x86, 0xaf
        .db  0x87, 0xc4
        .db  0x88, 0xd7
        .db  0x89, 0xe8
        ; AGC and AEC parameters.  Note we start by disabling those features,
        ; then turn them only after tweaking the values.
        .db  REG_COM8, COM8_FASTAEC | COM8_AECSTEP
        .db  REG_GAIN, 0
        .db  REG_AECH, 0
        .db  REG_COM4, 0x40 ; reserved bit
        .db  REG_COM9, 0x18 ; 4x gain + rsvd bit
        .db  REG_BD50MAX, 0x05
        .db  REG_BD60MAX, 0x07
        .db  REG_AEW, 0x95
        .db  REG_AEB, 0x33
        .db  REG_VPT, 0xe3
        .db  REG_HAECC1, 0x78
        .db  REG_HAECC2, 0x68
        .db  0xa1, 0x03
        .db  REG_HAECC3, 0xd8
        .db  REG_HAECC4, 0xd8
        .db  REG_HAECC5, 0xf0
        .db  REG_HAECC6, 0x90
        .db  REG_HAECC7, 0x94
        .db  REG_COM8, COM8_FASTAEC | COM8_AECSTEP | COM8_AGC | COM8_AEC
        .db  0x30, 0
        .db  0x31, 0 ; disable some delays
        ; Almost all of these are "reserved" values.
        .db  REG_COM5, 0x61
        .db  REG_COM6, 0x4b
        .db  0x16, 0x02
        .db  REG_MVFP, 0x07
        .db  0x21, 0x02
        .db  0x22, 0x91
        .db  0x29, 0x07
        .db  0x33, 0x0b
        .db  0x35, 0x0b
        .db  0x37, 0x1d
        .db  0x38, 0x71
        .db  0x39, 0x2a
        .db  REG_COM12, 0x78
        .db  0x4d, 0x40
        .db  0x4e, 0x20
        .db  REG_GFIX, 0
      ; .db  0x6b, 0x4a
        .db  0x74, 0x10
        .db  0x8d, 0x4f
        .db  0x8e, 0
        .db  0x8f, 0
        .db  0x90, 0
        .db  0x91, 0
        .db  0x96, 0
        .db  0x9a, 0
        .db  0xb0, 0x84
        .db  0xb1, 0x0c
        .db  0xb2, 0x0e
        .db  0xb3, 0x82
        .db  0xb8, 0x0a

        ; More reserved, some of which tweaks white balance
        .db  0x43, 0x0a
        .db  0x44, 0xf0
        .db  0x45, 0x34
        .db  0x46, 0x58
        .db  0x47, 0x28
        .db  0x48, 0x3a
        .db  0x59, 0x88
        .db  0x5a, 0x88
        .db  0x5b, 0x44
        .db  0x5c, 0x67
        .db  0x5d, 0x49
        .db  0x5e, 0x0e
        .db  0x6c, 0x0a
        .db  0x6d, 0x55
        .db  0x6e, 0x11
        .db  0x6f, 0x9e ; it was 0x9F "9e for advance AWB"
        .db  0x6a, 0x40
        .db  REG_BLUE, 0x40
        .db  REG_RED,  0x60
        .db  REG_COM8, COM8_FASTAEC | COM8_AECSTEP | COM8_AGC | COM8_AEC | COM8_AWB

        ; Matrix coefficients
        .db  0x4f, 0x80
        .db  0x50, 0x80
        .db  0x51, 0
        .db  0x52, 0x22
        .db  0x53, 0x5e
        .db  0x54, 0x80
        .db  0x58, 0x9e

        .db  REG_COM16, COM16_AWBGAIN
        .db  REG_EDGE, 0
        .db  0x75, 0x05
        .db  REG_REG76, 0xe1
        .db  0x4c, 0
        .db  0x77, 0x01
        .db  REG_COM13, 0x48 ; 0xc3
        .db  0x4b, 0x09
        .db  0xc9, 0x60
      ; .db  REG_COM16, 0x38
        .db  0x56, 0x40

        .db  0x34, 0x11
        .db  REG_COM11, COM11_EXP | COM11_HZAUTO
        .db  0xa4, 0x82 ; was `0x88`
        .db  0x96, 0
        .db  0x97, 0x30
        .db  0x98, 0x20
        .db  0x99, 0x30
        .db  0x9a, 0x84
        .db  0x9b, 0x29
        .db  0x9c, 0x03
        .db  0x9d, 0x4c
        .db  0x9e, 0x3f
        .db  0x78, 0x04

        ; Extra-weird stuff. Some sort of multiplexor register
        .db  0x79, 0x01
        .db  0xc8, 0xf0
        .db  0x79, 0x0f
        .db  0xc8, 0x00
        .db  0x79, 0x10
        .db  0xc8, 0x7e
        .db  0x79, 0x0a
        .db  0xc8, 0x80
        .db  0x79, 0x0b
        .db  0xc8, 0x01
        .db  0x79, 0x0c
        .db  0xc8, 0x0f
        .db  0x79, 0x0d
        .db  0xc8, 0x20
        .db  0x79, 0x09
        .db  0xc8, 0x80
        .db  0x79, 0x02
        .db  0xc8, 0xc0
        .db  0x79, 0x03
        .db  0xc8, 0x40
        .db  0x79, 0x05
        .db  0xc8, 0x30
        .db  0x79, 0x26
        .db  0xff, 0xff ; END MARKER

wait_for_high_VSYNC: wait_for_high CAM_VSYNC
                     ret
wait_for_low_VSYNC:  wait_for_low  CAM_VSYNC
                     ret

wait_for_high_PCLK:  wait_for_high CAM_PCLK
                     ret
wait_for_low_PCLK:   wait_for_low  CAM_PCLK
                     ret

cam_wr_sensor_regs_8_8: ; (Z)
        LPM    t_2, Z+
        LPM    t_3, Z+
        cpi    t_2, 0xff
        breq   cam_wr_sensor_regs_8_8_end
        rcall  cam_wr_cell
        rjmp   cam_wr_sensor_regs_8_8
     cam_wr_sensor_regs_8_8_end:
        ret

cam_init:
        ldi    t_2, 0x12
        ldi    t_3, 0x80
        rcall  cam_wr_cell
        rcall  delay_100_ms
        ldi_Z  ov7670_default_regs
        rcall  cam_wr_sensor_regs_8_8
        ; PCLK does not toggle on HBLANK
        ldi    t_2, REG_COM10
        ldi    t_3, 32
        rcall  cam_wr_cell
        ret

cam_set_color:
        ldi_Z  yuv422_ov7670
        rcall  cam_wr_sensor_regs_8_8
        ret

cam_set_res:
        ldi    t_2, REG_COM3
        ldi    t_3, 4 ; REG_COM3 enable scaling
        rcall  cam_wr_cell
        ldi_Z  qvga_ov7670
        rcall  cam_wr_sensor_regs_8_8
        ret

