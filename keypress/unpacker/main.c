//
//  main.c
//  unpacker
//
//  Created by armored on 20/03/14.
//  Copyright (c) 2014 -. All rights reserved.
//
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/uio.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach/i386/_structs.h>
#include <mach/i386/thread_status.h>

void  ____endcall();
int   ___main(int argc, const char * argv[], const char *env[]);

int main(int argc, const char * argv[], const char *env[])
{
  int retval;
  void *__mainp = (void*)___main;
  
  __asm __volatile__
  (
   "movl  %%ebp, %%edx\n"
   "leal  (%%edx), %%eax\n"
   "addl  $0x10, %%eax\n"
   "push  %%eax\n"
   
   "subl  $0x8, %%eax\n"
   "push  %%eax\n"
   
   "subl  $0x4, %%eax\n"
   "movl  (%%eax), %%edx\n"
   "push  %%edx\n"
   
   "movl  %1, %%eax\n"
   "call  %%eax\n"
   : "=r" (retval)
   : "m" (__mainp)
   : "eax", "edx"
   );
  
  return retval;
}

int __strlen(char *string)
{
  int i=0;
  while (string[i] !=0) {
    i++;
  }
  return i;
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

ssize_t mh_read(int fildes, void *buf, size_t nbyte, int offset)
{
  mh_lseek(fildes, offset, SEEK_SET);
  return __mh_read(fildes, buf, nbyte);
}

void* resolve_dyld_start(int fd, void *mheader_ptr)
{
  int   mh_offset;
  int   mh_arch_num;
  int   mh_cpu_type;
  int   mh_lc_num;
  char* curr_lc_cmd;
  char* mh_buffer = (char*)mh_mmap(NULL, 0x1000, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0);
  void* ret_address       = NULL;
  void* mh_vmaddress      = NULL;
  
  struct fat_arch*        ft_arch;
  struct fat_header*      ft_header;
  struct mach_header*     mh_header;
  struct load_command*    mh_lcomm;
  struct segment_command* mh_segm;
  
  ft_header = (struct fat_header*)mheader_ptr;
  ft_arch   = (struct fat_arch*)(mheader_ptr + sizeof(struct fat_header));
  
  if (ft_header->magic != MH_MAGIC)
  {
    if (ft_header->magic != FAT_CIGAM)
      mh_exit(0);
    
    mh_arch_num = ft_header->nfat_arch;
    mh_arch_num >>= 24;
    
    for(;mh_arch_num > 0; mh_arch_num--)
    {
      mh_cpu_type = ft_arch->cputype;
      if (mh_cpu_type == 0x7000000)
        break;
      ft_arch++;
    }
    
    if (mh_arch_num == 0)
      mh_exit(0);
    
    mh_offset = ntohl(ft_arch->offset);
    
    mh_read(fd, mh_buffer, 0x1000, mh_offset);
    
    mh_header = (struct mach_header*)mh_buffer;
    
    mh_lc_num = mh_header->ncmds;
    
    curr_lc_cmd = (char*)(mh_buffer + sizeof(struct mach_header));
    
    for(; mh_lc_num>0; mh_lc_num--)
    {
      mh_lcomm  = (struct load_command*)curr_lc_cmd;
      
      if (mh_lcomm->cmd == LC_SEGMENT)
      {
        mh_segm = (struct segment_command*)curr_lc_cmd;
        mh_vmaddress = (void*)mh_segm->vmaddr;
        
        if (mh_vmaddress)
        {
          void* _loadaddress = 0;
          int _offset      = mh_offset + mh_segm->fileoff;
          
          _loadaddress = mh_mmap(mh_vmaddress,
                                 mh_segm->filesize,
                                 3,                 //PROT_READ|PROT_WRITE,
                                 0x12,              //MAP_FIXED|MAP_PRIVATE,
                                 fd,
                                 _offset);
          
          mh_mprotect(_loadaddress, mh_segm->filesize, mh_segm->initprot);
          
          //if ( !((unsigned int)(v17_command_base_ptr - (_DWORD)&v22_loadaddress) >> 9) )
          //  v17_command_base_ptr = v17_command_base_ptr - (_DWORD)&v22_loadaddress - 8 + v22_loadaddress;
          
          int _last_page_align = (mh_segm->filesize + 0xFFF) & 0xFFFFF000;
          int _last_bytes      = mh_segm->vmsize - _last_page_align;
          
          if (_last_bytes)
          {
            _loadaddress = mh_mmap((void*)_loadaddress + _last_page_align,
                                   _last_bytes,
                                   3,               //PROT_READ|PROT_WRITE,
                                   0x1012,          //MAP_ANON|MAP_NOEXTEND|MAP_FIXED|MAP_PRIVATE,
                                   -1,
                                   0);
          }
          
        }
      }
      else if (mh_lcomm->cmd == LC_UNIXTHREAD)
      {
        struct x86_thread_state* thcmd = (struct x86_thread_state*)mh_lcomm;
        ret_address = (void*)thcmd->uts.ts32.__ds;
        break;
      }
      
      curr_lc_cmd += mh_lcomm->cmdsize;
    }
  }
  
  return ret_address;
}

void *open_and_resolve_dyld()
{
  int  fd;
  void *addr = NULL;
  char *mh_buffer = (char*)mh_mmap(NULL, 0x400, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0);
  int d = 'd';
  int c = 'lyd/';
  int b = 'bil/';
  int a = 'rsu/';
  fd = mh_open((char*)&a, O_RDONLY);
  
  if(fd != 0)
  {
    __mh_read(fd, mh_buffer, 0x400);
    addr = resolve_dyld_start(fd, mh_buffer);
  }
  
  return addr;
}

#include "cypher.h"

int ___main(int argc, const char * argv[], const char *env[])
{
  int ret_val=0;
  void (*_Dyld_start)(void*, int, void*);
  
  char *endpcall = (char*) ____endcall;
  endpcall += 5;
  
  int   __exec_len = *((int*)endpcall);
  char* __exec     = endpcall + sizeof(int);
  
  const char* name = argv[0];
  
  int  name_len    = __strlen((char*)name) + 1;
  
  char* exec_buff   =  (char*)mh_mmap((void*)0x1000, __exec_len, 7, 0x1012, -1, 0);
  
  char *exec_ptr_in  = __exec;
  char *exec_ptr_out = (char*)exec_buff;

  _xcrypt(exec_ptr_in, exec_ptr_out, __exec_len);
  
  void *addr = open_and_resolve_dyld();
  
  if(addr)
    _Dyld_start = addr;
  else
    _Dyld_start = (void*)0x8fe01030;
  
  __asm __volatile__
  (
   // copy argv[0] on stack
   "cld\n"
   "mov   %1, %%ecx\n"
   "sub   %1, %%esp\n"
   "mov   %%esp, %%edi\n"
   "push  %%esi\n"
   "mov   %2, %%esi\n"
   "rep   movsb\n"
   
   "pop   %%esi\n"
   "push  $0x0\n"
   "push  %2\n" // stackguard
   "push  %2\n" // stackguard
   "push  %2\n" // stackguard
   "push  %2\n" // argv[0]
   "movl  %3, %%eax\n"
   "mov   $0x1, %%ecx\n"
   
   // env var count
   "env_enum_in:"
   "mov   (%%eax), %%edx\n"
   "test  %%edx, %%edx\n"
   "jz    env_stack_in\n"
   "addl  $0x4, %%eax\n"
   "inc   %%ecx\n"
   "jnz   env_enum_in\n"
   
   // copy env vars on stack
   "env_stack_in:"
   "mov   (%%eax), %%edx\n"
   "push  %%edx\n"
   "sub   $0x4, %%eax\n"
   "sub   $0x1, %%ecx\n"
   "test  %%ecx, %%ecx\n"
   "jnz   env_stack_in\n"
   
   // invoking dyld
   "env_stack_out:"
   "push  $0x0\n"
   "push  %2\n"
   "push  $0x1\n"
   "push  %4\n"
   "mov   %5, %%eax\n"
   "jmp   %%eax\n"
   : "=r" (ret_val)
   : "r" (name_len), "r" (name), "m" (env), "m" (exec_buff), "m" (_Dyld_start)
   : "eax", "ecx", "esp"
   );
  
  //_Dyld_start(exec_buff, argc, argv);
  
  return ret_val;
}

void ____endcall()
{
  return;
}

