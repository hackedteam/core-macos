//
//  main.c
//  unpacker
//
//  Created by armored on 20/03/14.
//  Copyright (c) 2014 -. All rights reserved.
//
#include "common.h"

#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/uio.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach/i386/_structs.h>
#include <mach/i386/thread_status.h>

void  ____endcall();
int   entry_point(int argc, const char * argv[], const char *env[]);

/*
 *  macho loader entry point:
 *    - repush param on stack
 *    - call real entrypoint
 */

int main(int argc, const char * argv[], const char *env[])
{
  int retval;
  void *__mainp = (void*)entry_point;
  
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

/*  text section encryption low limit marker */
///////////////////////////////////////////
__BEGIN_ENC_TEXT_FUNC
///////////////////////////////////////////

int __strlen(char *string)
{
  int i=0;
  while (string[i] !=0) {
    i++;
  }
  return i;
}

/*
 *  WEAK IMPLEMENTATION:
 *
 *    Assembly sycall implementation
 */
///////////////////////////////////////////
#include "syscall.h"
///////////////////////////////////////////

ssize_t mh_read(int fildes, void *buf, size_t nbyte, int offset)
{
  mh_lseek(fildes, offset, SEEK_SET);
  return __mh_read(fildes, buf, nbyte);
}

#define VMADDR_OFFSET 0x11100000

/*
 *  resolve_dyld_start(int fd, void *mheader_ptr)
 *    
 *    - parse macho header to map section in mem
 *    - resolve entrypoint
 */
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
        mh_vmaddress = (void*)mh_segm->vmaddr - VMADDR_OFFSET;
        
        if (mh_vmaddress >  NULL)
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
        ret_address = (void*)thcmd->uts.ts32.__ds - VMADDR_OFFSET;
        break;
      }
      
      curr_lc_cmd += mh_lcomm->cmdsize;
    }
  }
  
  return ret_address;
}

/* Load dyld macho and resolve its entrypoint */
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


int launch_dyld(int name_len, const char* name, const char *env[], char* exec_buff, void *_Dyld_start)
{
  int ret_val=0;
  
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
  
  return ret_val;
}

/*
 *  WEAK IMPLEMENTATION:
 *
 *    encryption/decryption algorithm
 */
///////////////////////////////////////////
#include "cypher.h"
///////////////////////////////////////////

/*
 *  WEAK IMPLEMENTATION:
 *
 *    Checking text section integrity
 */
///////////////////////////////////////////
#include "integrity.h"
///////////////////////////////////////////

/* text section encryption high limit marker */
///////////////////////////////////////////
__END_ENC_TEXT_FUNC
///////////////////////////////////////////

/*
 *  WEAK IMPLEMENTATION:
 *
 *    text section encryption/decryption
 */
///////////////////////////////////////////
#include "text_sc_enc.h"
///////////////////////////////////////////

/*
 *  entry_point(int argc, const char * argv[], const char *env[])
 *
 *    Real entry point:
 *      - load patched param
 *      - unpack text section
 *      - check integrity of the opcodes
 *      - decrypt payload
 *      - load and resolve macho imageloader
 *      - run payload
 */

int entry_point(int argc, const char * argv[], const char *env[])
{
  int ret_val=0;

  mh_mmap_t   _mh_mmap      = NULL;
  strlen_t    _strlen       = (void*)0xFF3000;
  in_param**  patch_param   = (void*)0x2000;
  in_param*   patched_param = (void*)0x12000;
  check_integrity_t _check_integrity = (void*)'1de ';
  crypt_macho_t     _crypt_macho     = (void*)0x34;
  patch_param = &patched_param;
  
  open_and_resolve_dyld_t _open_and_resolve_dyld = (void*)'dffe';
    
  void (*_Dyld_start)(void*, int, void*) = (void*)512;
  
  char *endpcall = (char*)____endcall;
  endpcall += ENDCALL_LEN;
 
  patched_param = (in_param*)endpcall;
  
  _strlen           = (strlen_t)     endpcall - (*patch_param)->strlen_offset         - ENDCALL_LEN;
  _crypt_macho      = (crypt_macho_t)endpcall - (*patch_param)->crypt_macho_offset    - ENDCALL_LEN;
  _mh_mmap          = (mh_mmap_t)    endpcall - (*patch_param)->mh_mmap_offset        - ENDCALL_LEN;
  
  _check_integrity       = (check_integrity_t)      endpcall - patched_param->check_integrity_offset       - ENDCALL_LEN;
  _open_and_resolve_dyld = (open_and_resolve_dyld_t)endpcall - patched_param->open_and_resolve_dyld_offset - ENDCALL_LEN;
  
  char* enc_begin_block_addr = endpcall - patched_param->BEGIN_ENC_TEXT_offset - ENDCALL_LEN;
  char* enc_end_block_addr   = endpcall - patched_param->END_ENC_TEXT_offset   - ENDCALL_LEN;
  int   enc_block_len        = enc_end_block_addr - enc_begin_block_addr;

  // decrypt text section
  enc_unpacker_text_section(enc_begin_block_addr, enc_block_len);

  _check_integrity((*patch_param)->hash);
  
  //mh_bsdthread_create(_check_integrity, &(patched_param->hash), 0x80000, 0, 0);
  
  const char* name = argv[0];
  
  int  name_len      = _strlen((char*)name) + 1;
  char* exec_buff    =  (char*)_mh_mmap((void*)0x1000, patched_param->macho_len, 7, 0x1012, -1, 0);
  char *exec_ptr_in  = (char*)patched_param->macho;
  char *exec_ptr_out = (char*)exec_buff;
  
  // decrypt macho payload
  _crypt_macho(exec_ptr_in, exec_ptr_out, (*patch_param)->macho_len);
  
  // load dyld macho loader
  void *addr = _open_and_resolve_dyld();
  
  if(addr)
    _Dyld_start = addr;
  else
    return 0;
  
  // launch macho payload
  launch_dyld(name_len, name, env, exec_buff, _Dyld_start);
  
  return ret_val;
}

// End of text section marker
void ____endcall()
{
  return;
}

