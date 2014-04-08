//
//  integrity.h
//  keypress
//
//  Created by armored on 28/03/14.
//  Copyright (c) 2014 -. All rights reserved.
//

#ifndef keypress_integrity_h
#define keypress_integrity_h

#ifdef KEYPRESS
int calc_integrity(char* buff, int len)
{
  char  tmp_hash = 0xFF;
  char* begpcall = buff;
  
  for (int i=0; i<len; i++, begpcall++)
  {
    tmp_hash ^= *begpcall;
  }
  
  return tmp_hash;
}
#else
void check_integrity(int patched_hash)
{
  char* begpcall = (char*)main;
  char* endpcall = (char*)____endcall;
  int  tmp_hash = 0xFFFFFFFF;
   
  endpcall = endpcall + ENDCALL_LEN;
  
  for (;begpcall<endpcall; begpcall++)
  {
    tmp_hash ^= *begpcall;
  }
  
  if (tmp_hash != patched_hash)
  {
    __asm volatile
    (
     "movl $0x1c, %%eax\n"
     "movl (%%eax), %%edx\n"
     :
     :
     : "eax", "edx"
     );
  }
}
#endif

#endif
