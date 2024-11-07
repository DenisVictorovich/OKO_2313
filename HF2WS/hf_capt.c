
/* hf_capt.c */

#ifndef  HF_CAPTURE_C
#define  HF_CAPTURE_C

// -----------------------------------------------------------------------------------------------------------------------------

u8 d2s(u8 v) { v &= 15; v += '0'; if(v > '9') return v + 7; return v; }
u8 s2d(u8 v) { v -= '0'; if(v > 41) return v - 39; if(v > 9) return v - 7; return v; }

// -----------------------------------------------------------------------------------------------------------------------------

struct { u8 bn, fc, cs; u32 sp; } file_line;

u8   begin_output  = 0;
u16  failed_lines  = 0;
u32  byte_position = 0,
     file_volume   = 0;

/* операции */
#define  DATA_WRITE     0
#define  VOL_SELECT     2 /* «том» составляет 64 килобайта */
#define  VOLUME_SELECT  4 /* «том» составляет 64 килобайта */

#define  CS_CHECK  250

// -----------------------------------------------------------------------------------------------------------------------------

void HF2BF_reset()
{
    begin_output  = 0;
    failed_lines  = 0;
    byte_position = 0;
    file_volume   = 0;
}

// -----------------------------------------------------------------------------------------------------------------------------

void HF2BF_capture(u8 b)
{
    static u8 bb, i;
    if(b == ':')
    {
        file_line.sp = file_volume & 0xFFFF0000L;
        file_line.bn = file_line.cs = i = 0;
        file_line.fc = 255;
    }
    else if(b == 13) /* ignore */;
    else if(b == 10)
    {
        /* строка завершена */
        #ifdef  COMPILE_FOR_THE_uC
            hf_line_indicate(failed_lines);
        #endif
    }
    else
    {
        if(i & 1) bb |= s2d(b);      /* lo nibble */
        else      bb  = s2d(b) << 4; /* hi nibble */
        if(i & 1)
        {   /* прочитан байт */
            u8 bp = i >> 1;
            file_line.cs += bb;
            /**/ if(bp == 0) file_line.bn  = bb;
            else if(bp == 1) file_line.sp |= (u16)bb << 8; /* hi byte */
            else if(bp == 2) file_line.sp |= (u16)bb << 0; /* lo byte */
            else if(bp == 3)
            {
                file_line.fc = bb;
                if(file_line.fc == DATA_WRITE)
                {
                    if(byte_position < file_line.sp)
                    {
                        /* printf("next volume 0x%08" "lX" " \n", file_line.sp); getch() */
                        while(byte_position < file_line.sp) HF2BF_process_byte(255);
                    }
                }
                #ifdef  COMPILE_FOR_THE_uC
                    hf_line_set_op_code(file_line.fc);
                #endif
            }
            else if(file_line.fc == VOL_SELECT)
            {
                if(bp == 4) file_volume = (u32)bb << 12;
                file_line.bn--;
            }
            else if(file_line.fc == VOLUME_SELECT)
            {
                if(bp == 4/* hi byte */) { file_volume  = (u32)bb << 24; }
                if(bp == 5/* lo byte */) { file_volume |= (u32)bb << 16;
                                           file_volume &= 0xFFFF0000L;
                                           if(byte_position == 0) byte_position = file_volume;
                                           /* \___ СПЕЦИАЛЬНО ДЛЯ «ARM-CORTEX» ___/ */ }
                file_line.bn--;
            }
            else if(file_line.fc == DATA_WRITE)
            {
                if(file_line.bn)
                {
                    begin_output = 1;
                    HF2BF_process_byte(bb);
                    file_line.bn--;
                }
            }
            /* остальные операции <...> */
            else if(file_line.bn) file_line.bn--;
            if(file_line.bn == 0)
            {
                file_line.fc = CS_CHECK;
                file_line.bn = CS_CHECK;
            }
            else if(file_line.fc == CS_CHECK)
            {
                if(file_line.cs) failed_lines++;
                file_line.fc = 255;
            }
        }
        i++;
    }
}

// -----------------------------------------------------------------------------------------------------------------------------

#endif /* HF_CAPTURE_C */

