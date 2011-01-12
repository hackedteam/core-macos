/*
 * NSString Category
 *  This is a category for NSString in order to provide in-place hashing
 *
 * [QUICK TODO]
 * - Globally for all the categories, change the way how they're defined and
 *   implemented. (Use a single CryptoLibrary class file)?
 * 
 * Created by Alfredo 'revenge' Pesoli on 08/04/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <CommonCrypto/CommonDigest.h>
#import <openssl/sha.h>

#import "NSString+SHA1.h"


@implementation NSString (SHA1)

- (NSData *)sha1Hash
{
  return [[self dataUsingEncoding: NSUTF8StringEncoding
             allowLossyConversion: NO] sha1Hash];
}

- (NSString *)sha1HexHash
{
  return [[self dataUsingEncoding: NSUTF8StringEncoding
             allowLossyConversion: NO] sha1HexHash];
}

@end


@implementation NSData (SHA1)

- (NSData *)sha1Hash
{
  unsigned char digest[SHA_DIGEST_LENGTH];
 	CC_SHA1([self bytes], [self length], digest);
  
 	return [NSData dataWithBytes: &digest length: SHA_DIGEST_LENGTH];
}

- (NSString *)sha1HexHash
{
  unsigned char digest[SHA_DIGEST_LENGTH];
  char finalDigest[2 * SHA_DIGEST_LENGTH];
 	int i;

 	CC_SHA1([self bytes], [self length], digest);
  
 	for (i = 0; i < SHA_DIGEST_LENGTH; i++)
    sprintf(finalDigest + i * 2, "%02x", digest[i]);
  
  //return [NSString stringWithCString: finalDigest
  //                            length: 2 * SHA_DIGEST_LENGTH];
  return [NSString stringWithCString: finalDigest
                            encoding: NSUTF8StringEncoding];
}

@end