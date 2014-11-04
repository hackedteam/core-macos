//
//  macho.h
//  keypress
//
//  Created by armored on 21/03/14.
//  Copyright (c) 2014 -. All rights reserved.
//

#ifdef _WIN32

typedef int			__int32_t;
typedef int			integer_t;
typedef integer_t	cpu_type_t;
typedef integer_t	cpu_subtype_t;
typedef integer_t	cpu_threadtype_t;
typedef int		vm_prot_t;

int fchmod(int fildes, mode_t mode);

#define S_IRGRP 00040
#define S_IXGRP 00010

#define S_IRWXO 00007
#define S_IROTH 00004
#define S_IWOTH 00002
#define S_IXOTH 00001

#define	LC_SEGMENT	0x1
#define	MH_EXECUTE	0x2
#define	MH_NOUNDEFS	0x1
#define	LC_UNIXTHREAD	0x5
#define x86_THREAD_STATE32		1

#define	VM_PROT_NONE	((vm_prot_t) 0x00)
#define VM_PROT_READ	((vm_prot_t) 0x01)	/* read permission */
#define VM_PROT_WRITE	((vm_prot_t) 0x02)	/* write permission */
#define VM_PROT_EXECUTE	((vm_prot_t) 0x04)	/* execute permission */

#define	MH_MAGIC              0xfeedface
#define CPU_TYPE_X86          ((cpu_type_t) 7)
#define CPU_TYPE_I386         CPU_TYPE_X86
#define CPU_SUBTYPE_X86_ALL		((cpu_subtype_t)3)

struct load_command {
	uint32_t cmd;		/* type of load command */
	uint32_t cmdsize;	/* total size of command in bytes */
};

struct mach_header {
	uint32_t	magic;		/* mach magic number identifier */
	cpu_type_t	cputype;	/* cpu specifier */
	cpu_subtype_t	cpusubtype;	/* machine specifier */
	uint32_t	filetype;	/* type of file */
	uint32_t	ncmds;		/* number of load commands */
	uint32_t	sizeofcmds;	/* the size of all the load commands */
	uint32_t	flags;		/* flags */
};

struct segment_command { /* for 32-bit architectures */
	uint32_t	cmd;		/* LC_SEGMENT */
	uint32_t	cmdsize;	/* includes sizeof section structs */
	char		segname[16];	/* segment name */
	uint32_t	vmaddr;		/* memory address of this segment */
	uint32_t	vmsize;		/* memory size of this segment */
	uint32_t	fileoff;	/* file offset of this segment */
	uint32_t	filesize;	/* amount to map from the file */
	vm_prot_t	maxprot;	/* maximum VM protection */
	vm_prot_t	initprot;	/* initial VM protection */
	uint32_t	nsects;		/* number of sections in segment */
	uint32_t	flags;		/* flags */
};

struct section { /* for 32-bit architectures */
	char		sectname[16];	/* name of this section */
	char		segname[16];	/* segment this section goes in */
	uint32_t	addr;		/* memory address of this section */
	uint32_t	size;		/* size in bytes of this section */
	uint32_t	offset;		/* file offset of this section */
	uint32_t	align;		/* section alignment (power of 2) */
	uint32_t	reloff;		/* file offset of relocation entries */
	uint32_t	nreloc;		/* number of relocation entries */
	uint32_t	flags;		/* flags (section type and attributes)*/
	uint32_t	reserved1;	/* reserved (for offset or index) */
	uint32_t	reserved2;	/* reserved (for count or sizeof) */
};

#define	_STRUCT_X86_THREAD_STATE32	struct __darwin_i386_thread_state
_STRUCT_X86_THREAD_STATE32
{
  unsigned int	__eax;
  unsigned int	__ebx;
  unsigned int	__ecx;
  unsigned int	__edx;
  unsigned int	__edi;
  unsigned int	__esi;
  unsigned int	__ebp;
  unsigned int	__esp;
  unsigned int	__ss;
  unsigned int	__eflags;
  unsigned int	__eip;
  unsigned int	__cs;
  unsigned int	__ds;
  unsigned int	__es;
  unsigned int	__fs;
  unsigned int	__gs;
};

typedef _STRUCT_X86_THREAD_STATE32 x86_thread_state32_t;

#endif
