// hf2ws.c

#include <stdio.h>
#include <string.h>
#include "digtyp.h"

// ===========================================================================

#define  uCONTROLLER_PAGESIZE  (16 * 2) // для tiny-2313
#define  uCONTROLLER_PAGE_CND  (page_n >= 16 && page_n < 64)

// ===========================================================================

int byte_n = 0, page_n = 0, line_cs = 0; // [22.10.2014]

FILE *in, *out;

// ===========================================================================

u8 HF2BF_process_byte(u8 bb)
{ // для mega-8, mega-48, mega-88
  extern u32 byte_position;
  if(byte_n == 0)
   {
      if(uCONTROLLER_PAGE_CND) fprintf(out, "w%02X", (u8)page_n);
      line_cs = page_n;
   }
  if(uCONTROLLER_PAGE_CND) fprintf(out, "%02X", bb); byte_n++; line_cs += bb;
  if(byte_n >= uCONTROLLER_PAGESIZE)
   {
      if(uCONTROLLER_PAGE_CND) fprintf(out, "%02X\r\n", (u8)(-(i8)(u8)line_cs));
      byte_n = 0;
      page_n++;
      /// return 0
   }
  /// return 1
  byte_position++;
  return uCONTROLLER_PAGE_CND; /// [26.01.2018]
}

// ===========================================================================

#include "hf_capt.c"

// ===========================================================================

char* last_sym_ptr(char* p, char s)
{
  i16 t = strlen(p);
  p += t;
  while(t--) if(*--p == s) break;
  return p;
}

// ===========================================================================

int main(int argc, char** argv)
{
  u8 t, b[1000];

  if(argc < 2)
   {
     printf("\nHF2WS for tn2313, version 2.00\n"
            "   Convert hexadecimal file to the `write sending` file\n"
            "   Usage: hf2ws.exe <file.ext>\n"
            "   <file.ext> is the hexadecimal input file\n\n"
            "   - press any key to continue\n");
     getch();
     return 1;
   }

  HF2BF_reset();

  strcpy(b, argv[1]);
  strcpy(last_sym_ptr(b, '.'), ".ws");

  if(!(in  = fopen(argv[1], "rt"))) return 1; // read text
  if(!(out = fopen(b,       "wb"))) return 1; // write binary

  while(!feof(in))
   {
     t = (u8)fgetc(in);
     if(!feof(in)) HF2BF_capture(t);
   }
  while(HF2BF_process_byte(0xFF));

  fclose(in);
  fclose(out);

  if(failed_lines)
   {
     printf("\n failed lines: %d \n - press any key to continue\n", failed_lines);
     getch();
     return 1;
   }

  return 0;
}

// ===========================================================================


