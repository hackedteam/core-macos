//
//  main.c
//  keypress
//
//  Created by armored on 20/03/14.
//  Copyright (c) 2014 -. All rights reserved.
//
#include "unpacker.h"

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
#define LC_TEXT_VMADDR    0x1800000
#define LC_CMDS_NUM       2

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

int main(int argc, const char * argv[])
{
  char *_unpack_buff = (char*)_tmp_unpacker_buff;
  int   _unpack_len  = _tmp_unpacker_buff_len;

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
  
  int __text_len = _unpack_len + sizeof(int) + nbyte;
  
  struct mach_header*     mh = setup_macho_header();
  struct segment_command* sg = setup_lc_seg_header(LC_SEGMENT);
  x86_thread_state32_t*   th = setup_lc_xthd_header(LC_TEXT_VMADDR);
  struct load_command     lc;
  
  lc.cmd      = LC_UNIXTHREAD;
  lc.cmdsize  = sizeof(x86_thread_state32_t) +sizeof(int) + sizeof(int) + sizeof(lc);
  int flavor  = x86_THREAD_STATE32;
  int count   = 16;
  
  // adjust param
  sg->vmsize = sg->filesize = __text_len;
  mh->sizeofcmds = sizeof(struct segment_command) +
                   sizeof(lc) +
                   sizeof(flavor) +
                   sizeof(count) +
                   sizeof(x86_thread_state32_t);
  th->__eip = LC_TEXT_VMADDR + mh->sizeofcmds + sizeof(struct mach_header);
  
  fwrite(mh, 1, sizeof(struct mach_header), fd_out);
  
  fwrite(sg, 1, sizeof(struct segment_command), fd_out);
  
  fwrite(&lc, 1, sizeof(lc), fd_out);
  fwrite(&flavor, 1, sizeof(int), fd_out);
  fwrite(&count, 1, sizeof(int), fd_out);
  fwrite(th, 1, sizeof(x86_thread_state32_t), fd_out);

  fwrite(_unpack_buff, 1, _unpack_len, fd_out);
  fwrite(&nbyte, 1, 4, fd_out);
  
  fwrite(buff_in, 1, nbyte, fd_out);

  fclose(fd_out);
  chmod(file_out, (S_IRWXU|S_IRGRP|S_IXGRP|S_IROTH|S_IXOTH));
  
  printf("\tdone.\n");
  
  return 0;
}

