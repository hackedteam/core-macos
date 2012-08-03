//
//  RCSMAVGarbage.h
//  RCSMac
//
//  Created by armored on 8/1/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#ifndef RCSMac_RCSMAVGarbage_h
#define RCSMac_RCSMAVGarbage_h

#ifdef DEBUG

/*
 * DEBUG
 */
#define AV_GARBAGE_000
#define AV_GARBAGE_001 
#define AV_GARBAGE_002 
#define AV_GARBAGE_003 
#define AV_GARBAGE_004
#define AV_GARBAGE_005
#define AV_GARBAGE_006 
#define AV_GARBAGE_007 
#define AV_GARBAGE_008 
#define AV_GARBAGE_009 
#else

/*
 * RELEASE
 */
#if defined(__i386__) 

#define AV_GARBAGE_000   __asm__ ("push  %eax\n\t"        \
                                  "push  %ebx\n\t"        \
                                  "mov   %eax, %eax\n\t"  \
                                  "mov   %ebx, %eax\n\t"  \
                                  "pop   %ebx\n\t"        \
                                  "pop   %eax");

#define AV_GARBAGE_001   __asm__ ("push  %eax\n\t"        \
                                  "push  %ebx\n\t"        \
                                  "mov   %ebx, %eax\n\t"  \
                                  "xor   %eax, %ebx\n\t"  \
                                  "xor   %eax, %eax\n\t"  \
                                  "mov   %eax, %eax\n\t"  \
                                  "pop   %ebx\n\t"        \
                                  "pop   %eax");

#define AV_GARBAGE_002   __asm__ ("push  %eax\n\t"        \
                                  "push  %ebx\n\t"        \
                                  "pop  %ebx\n\t"        \
                                  "pop  %eax");

#define AV_GARBAGE_003   __asm__ ("push  %eax\n\t"        \
                                  "push  %ebx\n\t"        \
                                  "mov   %eax, %eax\n\t"  \
                                  "mov   %ebx, %eax\n\t"  \
                                  "xor   %eax, %ebx\n\t"  \
                                  "xor   %eax, %eax\n\t"  \
                                  "pop   %ebx\n\t"        \
                                  "pop   %eax");

#define AV_GARBAGE_004   __asm__ ("push  %eax\n\t"        \
                                  "push  %ebx\n\t"        \
                                  "pop   %ebx\n\t"        \
                                  "pop   %eax");

#define AV_GARBAGE_005   __asm__ ("push  %eax\n\t"        \
                                  "push  %ebx\n\t"        \
                                  "mov   %eax, %eax\n\t"  \
                                  "xor   %eax, %ebx\n\t"  \
                                  "mov   %eax, %eax\n\t"  \
                                  "pop   %ebx\n\t"        \
                                  "pop   %eax");

#define AV_GARBAGE_006   __asm__ ("push  %eax\n\t"        \
                                  "push  %ebx\n\t"        \
                                  "mov   %eax, %eax\n\t"  \
                                  "pop   %ebx\n\t"        \
                                  "pop   %eax");

#define AV_GARBAGE_007   __asm__ ("push  %eax\n\t"        \
                                  "push  %ebx\n\t"        \
                                  "mov   %ebx, %eax\n\t"  \
                                  "xor   %eax, %eax\n\t"  \
                                  "mov   %eax, %eax\n\t"  \
                                  "pop   %ebx\n\t"        \
                                  "pop   %eax");

#define AV_GARBAGE_008   __asm__ ("push  %eax\n\t"        \
                                  "push  %ebx\n\t"        \
                                  "pop   %ebx\n\t"        \
                                  "pop   %eax");

#define AV_GARBAGE_009   __asm__ ("push  %eax\n\t"        \
                                  "push  %ebx\n\t"        \
                                  "mov   %eax, %eax\n\t"  \
                                  "pop   %ebx\n\t"        \
                                  "pop   %eax");

#elif defined(__x86_64__)

#define AV_GARBAGE_000
#define AV_GARBAGE_001 
#define AV_GARBAGE_002 
#define AV_GARBAGE_003 
#define AV_GARBAGE_004
#define AV_GARBAGE_005
#define AV_GARBAGE_006 
#define AV_GARBAGE_007 
#define AV_GARBAGE_008 
#define AV_GARBAGE_009 
#define AV_GARBAGE_001 

#endif

#endif


#endif
