/*
 * RCSMac - Events
 *
 *  Provides all the events which should trigger an action
 *
 * Created by Alfredo 'revenge' Pesoli on 26/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>

#ifndef __RCSMEvents_h__
#define __RCSMEvents_h__

#import "RCSMEvents.h"
#import "RCSMCommon.h"

#define EVENT_PROCESS_NAME      0
#define EVENT_PROCESS_WIN_TITLE 1


@interface RCSMEvents : NSObject

+ (RCSMEvents *)sharedEvents;
+ (id)allocWithZone: (NSZone *)aZone;
- (id)copyWithZone: (NSZone *)aZone;
- (id)retain;
- (unsigned)retainCount;
- (void)release;
- (id)autorelease;

- (void)eventTimer: (NSDictionary *)configuration;
- (void)eventProcess: (NSDictionary *)configuration;
- (void)eventConnection: (NSDictionary *)configuration;
- (void)eventScreensaver: (NSDictionary *)configuration;
- (void)eventQuota: (NSDictionary *)configuration;

@end

#endif