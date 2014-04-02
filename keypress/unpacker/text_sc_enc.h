//
//  text_sc_enc.h
//  keypress
//
//  Created by armored on 28/03/14.
//  Copyright (c) 2014 -. All rights reserved.
//

#ifndef keypress_text_sc_enc_h
#define keypress_text_sc_enc_h

static inline __attribute__((always_inline))
void enc_unpacker_text_section(char* buff_in, int nbyte)
{
  for (int i = 0; i<nbyte; i++)
  {
    buff_in[i] ^= 0xf4;
  }
}

#endif
