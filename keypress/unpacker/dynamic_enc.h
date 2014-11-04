//
//  dynamic_enc.h
//  keypress
//
//  Created by armored on 07/04/14.
//  Copyright (c) 2014 -. All rights reserved.
//

#ifndef keypress_dynamic_enc_h
#define keypress_dynamic_enc_h

#define DF_FRAME_OFFSET_IN  0x0C
#define DF_FRAME_OFFSET_OUT 0x2A
#define DYNAMIC_ENC         _dynamic_enc_v1

typedef int (*dynamic_enc_t)(char*, char*);

__attribute__((__stdcall__)) int _dynamic_enc_v1(char *end, char *begin)
{
  int i = 0;
  
  begin += DF_FRAME_OFFSET_IN;
  end -= DF_FRAME_OFFSET_OUT;
  
  int len = end - begin;
  
  for (i=0; i<len; i++) {
    *begin++ ^= 0xE1;
  }
  
  return 1;
}

#endif
