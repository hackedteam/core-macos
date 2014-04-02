//
//  main.c
//  keypress
//
//  Created by armored on 20/03/14.
//  Copyright (c) 2014 -. All rights reserved.
//
#include "unpacker.h"
#include "unpacker_addr.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifndef _WIN32
#include <dlfcn.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach/i386/_structs.h>
#include <mach/i386/thread_status.h>
#else
#include "macho.h"
#endif

#define LC_SEG_TYPE_TEXT  1
#define LC_SEG_TYPE_DATA  2
#define LC_CMDS_NUM       2
#define LC_TEXT_VMADDR    0x1800000
#define UNPACKER_IMAGE_BASE 0x12000

void usage()
{
  printf("usage:\n\tkpress <input file> <output file>\n");
  exit(0);
}

struct mach_header* setup_macho_header()
{
  static struct mach_header mh_header;
  
  mh_header.magic       = MH_MAGIC;
  mh_header.cputype     = CPU_TYPE_I386;
  mh_header.cpusubtype  = CPU_SUBTYPE_X86_ALL;
  mh_header.filetype    = MH_EXECUTE;
  mh_header.ncmds       = LC_CMDS_NUM;
  mh_header.sizeofcmds  = 0;  // to adjust
  mh_header.flags       = MH_NOUNDEFS;
  
  return &mh_header;
}

struct segment_command* setup_lc_seg_header(int type)
{
  static struct segment_command mh_segm;
  
  mh_segm.cmd       = LC_SEGMENT;
  mh_segm.cmdsize   = sizeof(struct segment_command);
  strcpy(mh_segm.segname, "___TEXT");
  mh_segm.vmaddr    = LC_TEXT_VMADDR;
  mh_segm.vmsize    = 0;  // to adjust
  mh_segm.fileoff   = 0;
  mh_segm.filesize  = 0;  // to adjust
  mh_segm.maxprot   = VM_PROT_READ|VM_PROT_WRITE|VM_PROT_EXECUTE;
  mh_segm.initprot  = VM_PROT_READ|VM_PROT_WRITE|VM_PROT_EXECUTE;
  mh_segm.nsects    = 0;
  mh_segm.flags     = 0;
  
  return &mh_segm;
}

x86_thread_state32_t *
setup_lc_xthd_header(__int32_t addr)
{
  static x86_thread_state32_t thcmd;
  
  memset(&thcmd, 0, sizeof(thcmd));

  thcmd.__eip = addr;
  
  return &thcmd;
}

int _xencrypt(char *buff, int size)
{
  int i = 0;
  char *ptr = buff;
  
  for (i=0; i<size; i+=4)
  {
    int *iptr = (int*)ptr;
    *iptr ^= 0x12345678;
    ptr += 4;
  }
  
  return i;
}

int calc_integrity(char* buff, int len)
{
  char  tmp_hash = 0xFF;
  char* begpcall = buff;
  
  for (int i=0; i<len; i++, begpcall++)
  {
    tmp_hash ^= *begpcall;
  }
  
  return tmp_hash;
}

#define DF_FRAME_OFFSET 0xc

int _ddencrypt(char *end, char *begin)
{
  int i = 0;
  
  begin += DF_FRAME_OFFSET;
  
  int len = end - begin;
  
  for (i=0; i<len; i++) {
    *begin++ ^= 0xE1;
  }
  
  return 1;
}

void enc_unpacker_text_section(char* buff_in, int nbyte)
{
  for (int i = 0; i<nbyte; i++)
  {
    buff_in[i] ^= 0xf4;
  }
}

typedef struct _in_param {
  uint32_t    hash;
  uint32_t    check_integrity_offset;
  uint32_t    strlen_offset;
  uint32_t    mh_mmap_offset;
  uint32_t    xcrypt_offset;
  uint32_t    open_and_resolve_dyld_offset;
  uint32_t    BEGIN_ENC_TEXT_offset;
  uint32_t    END_ENC_TEXT_offset;
  uint32_t    macho_len;
  unsigned char   macho[1];
} in_param;

int main(int argc, const char * argv[])
{
  in_param  out_param;
  char *_unpacker_buff = (char*)_tmp_unpacker_buff;
  int   _unpacker_len  = _tmp_unpacker_buff_len;

  if(argc < 3)
    usage();
  
  char* file_in  = (char*)argv[1];
  char* file_out = (char*)argv[2];
  
	FILE *fd_in   = fopen(file_in,  "rb");  
  FILE *fd_out  = fopen(file_out, "wb");
  
  if (fd_in == 0 | fd_out == 0)
  {
    printf("\tfile opening error\n");
    return -1;
  }
  
  printf("\tinput file is %s output file is %s\n", file_in, file_out);
  
  struct stat stat_in;
  
  stat(file_in, &stat_in);
  
  char *buff_in = (char*)malloc((size_t)stat_in.st_size);
  
  int nbyte = 0;
  
  while(nbyte < stat_in.st_size)
  {
    int rbyte = fread(buff_in + nbyte, 1,(size_t)stat_in.st_size - nbyte, fd_in );
    nbyte += rbyte;
    if (rbyte == 0)
      break;
  }
  
  fclose(fd_in);
  
  if (nbyte != stat_in.st_size)
  {
    printf("\treading error\n");
    return -2;
  }
  
  printf("\treading %d bytes from %s\n\ttry to encrypt payload...\n", nbyte, file_in);
  
  nbyte = _xencrypt(buff_in, nbyte);
  
  if (nbyte != stat_in.st_size)
  {
    printf("\tencrypting error\n");
    return -3;
  }
  
#ifndef _WIN32
  sleep(1);
#endif
  
  printf("\tpacking...\n");
  
  // _text section len = unpacker code + in_param + macho paylod len
  int __text_len = _unpacker_len + sizeof(in_param) + nbyte;
  
  printf("\t_text_sect len %d, (unpacker %d, param %d, payload %d\n",
         __text_len, _unpacker_len, (int)sizeof(in_param), nbyte);
  
  struct mach_header*     mh = setup_macho_header();
  struct segment_command* sg = setup_lc_seg_header(LC_SEGMENT);
  x86_thread_state32_t*   th = setup_lc_xthd_header(LC_TEXT_VMADDR);
  struct load_command     lc;
  struct entry_point_command ep;
  
  lc.cmd      = LC_UNIXTHREAD;
  lc.cmdsize  = sizeof(x86_thread_state32_t) + sizeof(int) + sizeof(int) + sizeof(lc);
  int flavor  = x86_THREAD_STATE32;
  int count   = 16;

  
  // adjust param
  
  mh->sizeofcmds = sizeof(struct segment_command) +
                   sizeof(lc) +
                   sizeof(flavor) +
                   sizeof(count) +
                   //sizeof(x86_thread_state32_t) +
                   sizeof(struct entry_point_command);
  th->__eip = LC_TEXT_VMADDR + mh->sizeofcmds + sizeof(struct mach_header);
  sg->vmsize = sg->filesize = __text_len + mh->sizeofcmds;
  
  ep.cmd = LC_MAIN;
  ep.cmdsize = sizeof(struct entry_point_command);
  ep.entryoff = mh->sizeofcmds + sizeof(struct mach_header);
  ep.stacksize = 0;
  
  fwrite(mh, 1, sizeof(struct mach_header), fd_out);
  fwrite(sg, 1, sizeof(struct segment_command), fd_out);
  fwrite(&ep, 1, sizeof(struct entry_point_command), fd_out);
  //fwrite(&lc, 1, sizeof(lc), fd_out);
  //fwrite(&flavor, 1, sizeof(int), fd_out);
  //fwrite(&count, 1, sizeof(int), fd_out);
  //fwrite(th, 1, sizeof(x86_thread_state32_t), fd_out);
  
  
  /////////////////////////////////////////////
  // __TEXT section of unpacker macho

  uint32_t d_enc_begin = _DMH_MMAP_ENC_X1 - _MAIN_ADDR;
  uint32_t d_enc_end   = _DMH_MMAP_END    - _MAIN_ADDR;
  _ddencrypt(_unpacker_buff + d_enc_end, _unpacker_buff + d_enc_begin);
  
  int begin_enc_off = _BEGIN_ENC_TEXT - _MAIN_ADDR;
  int enc_len       = _END_ENC_TEXT   - _BEGIN_ENC_TEXT;
  enc_unpacker_text_section(_unpacker_buff + begin_enc_off, enc_len);
  
  fwrite(_unpacker_buff, 1, _unpacker_len, fd_out);
  /////////////////////////////////////////////
  
  out_param.hash = calc_integrity(_unpacker_buff, _unpacker_len);
  out_param.check_integrity_offset  = _ENDCALL_ADDR - _CHECK_INTEGRITY_ADDR;
  out_param.strlen_offset           = _ENDCALL_ADDR - _STRLEN_ADDR;
  //out_param.mh_mmap_offset          = _ENDCALL_ADDR - _MH_MMAP_ADDR;
  out_param.mh_mmap_offset          = _ENDCALL_ADDR - _DMH_MMAP;
  out_param.xcrypt_offset           = _ENDCALL_ADDR - _XCRPYT_ADDR;
  out_param.open_and_resolve_dyld_offset  = _ENDCALL_ADDR - _OPEN_AND_RESOLVE_ADDR;
  out_param.BEGIN_ENC_TEXT_offset         = _ENDCALL_ADDR - _BEGIN_ENC_TEXT;
  out_param.END_ENC_TEXT_offset           = _ENDCALL_ADDR - _END_ENC_TEXT;
  out_param.macho_len                     = nbyte;
  
  fwrite(&out_param,  1, sizeof(in_param) - sizeof(uint32_t), fd_out);
  
  fwrite(buff_in, 1, nbyte, fd_out);

  fclose(fd_out);

  chmod(file_out, (S_IRWXU|S_IRGRP|S_IXGRP|S_IROTH|S_IXOTH));
  
  printf("\tdone.\n");
  
  return 0;
}

