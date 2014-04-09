//
//  dynamic_enc.h
//  keypress
//
//  Created by armored on 07/04/14.
//  Copyright (c) 2014 -. All rights reserved.
//

#ifndef keypress_dynamic_enc_h
#define keypress_dynamic_enc_h

#define DF_FRAME_OFFSET 0x0C

__attribute__((__stdcall__)) int _dynamic_enc(char *end, char *begin)
{
  int i = 0;
  
  begin += DF_FRAME_OFFSET;
  
  int len = end - begin;
  
  for (i=0; i<len; i++) {
    *begin++ ^= 0xE1;
  }
  
  return 1;
}

#endif
