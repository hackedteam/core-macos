//
//  common.h
//  keypress
//
//  Created by armored on 28/03/14.
//  Copyright (c) 2014 -. All rights reserved.
//
#include <stdio.h>
#include <stdint.h>

#ifndef keypress_common_h
#define keypress_common_h

#define ENDCALL_LEN 5

#define __END_ENC_TEXT_FUNC int __END_ENC_TEXT(char *string) \
{ \
int i=0; \
while (string[i] !=0) { \
i++; \
} \
return i; \
}

#define __BEGIN_ENC_TEXT_FUNC int __BEGIN_ENC_TEXT(char *string) \
{ \
int i=0; \
while (string[i] !=0) { \
i++; \
} \
return i; \
}

/*
 * Used Function
 */
typedef void  (*____endcall_t)();
typedef int   (*strlen_t)(char *);
typedef void  (*check_integrity_t)(int);
typedef void  (*crypt_macho_t)(char*, char*, int);
typedef void* (*open_and_resolve_dyld_t)(void);
typedef void* (*mh_mmap_t)(void *, size_t, int, int, int, int);

typedef struct _in_param {
  uint32_t    hash;
  uint32_t    check_integrity_offset;
  uint32_t    strlen_offset;
  uint32_t    mh_mmap_offset;
  uint32_t    crypt_macho_offset;
  uint32_t    open_and_resolve_dyld_offset;
  uint32_t    BEGIN_ENC_TEXT_offset;
  uint32_t    END_ENC_TEXT_offset;
  uint32_t    macho_len;
  unsigned char   macho[1];
} in_param;

#endif
