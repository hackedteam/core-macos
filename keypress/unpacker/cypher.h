//
//  cypher.h
//  keypress
//
//  Created by armored on 21/03/14.
//  Copyright (c) 2014 -. All rights reserved.
//

#ifndef keypress_cypher_h
#define keypress_cypher_h

// payload, dynamic_enc version 1
#define CRYPT_V2

uint32_t  gKey_len = 32;
uint8_t   gKey[] = { 1,  2,  3,  4,  5,  6,  7,  8,
                    21, 22, 23, 24, 25, 26, 27, 28,
                    31, 32, 33, 34, 35, 36, 37, 38,
                    41, 42, 43, 44, 45, 46, 47, 48
                    };

#define SWAPC(X, Y) do { char p; p = *(uint8_t*)X; *(uint8_t*)X = *(uint8_t*)Y; *(uint8_t*)Y = p; } while(0)

#ifdef CRYPT_V1

void crypt_payload_v1(uint8_t* exec_ptr_in, uint8_t* exec_ptr_out, int __exec_len, uint8_t* tKey);

#define CRYPT_PAYLOAD crypt_payload_v1

#elif defined(CRYPT_V2)

void crypt_payload_v2(uint8_t* exec_ptr_in, uint8_t* exec_ptr_out, int __exec_len, uint8_t* tKey);

#define CRYPT_PAYLOAD crypt_payload_v2

#endif

#ifndef KEYPRESS /* decrypt [used by unpacker] */

#ifdef  CRYPT_V1

void crypt_payload_v1(uint8_t* exec_ptr_in, uint8_t* exec_ptr_out, int __exec_len, uint8_t* tKey)
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

#elif defined(CRYPT_V2)

void crypt_payload_v2(uint8_t *data, uint8_t *data_out, int32_t len, uint8_t* tKey)
{
	int32_t i = 0;
	uint8_t j = 0;
  uint8_t *keytable = NULL;
  uint8_t state;
	uint8_t counter;
	uint8_t sum;
  uint8_t *key = tKey;
  int32_t key_len = 32;
  
  // Anti checkguard: make room for key table on stack
  __asm __volatile__
  (
   "subl  $0x100, %%esp\n"
   "movl  %%esp , %0\n"
   : "=r" (keytable)
   : 
   : "eax"
  );
  
	for (i = 0; i < 256; i++)
		keytable[i] = i;
  
	for (i = 0; i < 256; i++)
  {
		j += key[i % key_len] + keytable[i];
		SWAPC(&keytable[i], &keytable[j]);
	}
  
	state = *key;
	counter = 0;
	sum = 0;

	uint8_t z;
  
	for (i = 0; i < len; i++)
  {
		counter++;
		sum += keytable[counter];
		SWAPC(&keytable[counter], &keytable[sum]);
		z = data[i];
		data_out[i] = z ^ keytable[(keytable[counter]
                                   + keytable[sum]) & 0xff];
		data_out[i] ^= state;
		
    z = data_out[i];
		
    state = state ^ z;
	}
  
  __asm __volatile__
  (
   "addl  $0x100, %%esp\n"
   :
   :
   : "eax"
   );
}
#endif

#else /* encrypt [used by kpress] */

void crypt_payload_v1(uint8_t* exec_ptr_in, uint8_t* exec_ptr_out, int __exec_len, uint8_t* tKey)
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

void crypt_payload_v2(uint8_t *data, uint8_t *data_out, int32_t len, uint8_t* tKey)
{
	int32_t   i = 0;
	uint8_t   j = 0;
  uint8_t   keytable[256];
  uint8_t   state;
	uint8_t   counter;
	uint8_t   sum;
  uint8_t*  key = tKey;
  int32_t   key_len = 32;

	for (i = 0; i < 256; i++)
		keytable[i] = i;
  
	for (i = 0; i < 256; i++)
  {
		j += key[i % key_len] + keytable[i];
		SWAPC(&keytable[i], &keytable[j]);
	}
  
	state = *key;
	counter = 0;
	sum = 0;
  
	uint8_t z;
  
	for (i = 0; i < len; i++)
  {
		counter++;
		sum += keytable[counter];
		SWAPC(&keytable[counter], &keytable[sum]);
		z = data[i];
		data[i] = z ^ keytable[(keytable[counter]
                            + keytable[sum]) & 0xff];
		data[i] ^= state;
		
    state = state ^ z;
	}
}
#endif

#endif
