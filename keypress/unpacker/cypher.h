//
//  cypher.h
//  keypress
//
//  Created by armored on 21/03/14.
//  Copyright (c) 2014 -. All rights reserved.
//

#ifndef keypress_cypher_h
#define keypress_cypher_h

void crypt_text(char* exec_ptr_in, char* exec_ptr_out, int __exec_len)
{
  for (int i=0; i<__exec_len; i+=4)
  {
    int in_p  = *(int*)exec_ptr_in;
    int out_p = in_p ^ 0x12345678;
    *(int*)exec_ptr_out = out_p;
    exec_ptr_in   +=4;
    exec_ptr_out  +=4;
  }
}

#endif
