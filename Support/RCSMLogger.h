/*
 *  RCSMLogger.h
 *  RCSMac
 *
 *
 *  Created by revenge on 2/2/11.
 *  Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>
#import "RCSMDebug.h"


#ifdef ENABLE_LOGGING

#define RCSMLoggerInfoLevel   1
#define RCSMLoggerWarnLevel   2
#define RCSMLoggerErrorLevel  3

enum
{
  kInfoLevel,
  kWarnLevel,
  kErrLevel,
  kVerboseLevel,
};

#define infoLog(format,...) [[RCSMLogger sharedInstance] log: __func__ \
                             line: __LINE__ level: kInfoLevel string: (format), ##__VA_ARGS__]

#define warnLog(format,...) [[RCSMLogger sharedInstance] log: __func__ \
                             line: __LINE__ level: kWarnLevel string: (format), ##__VA_ARGS__]

#define errorLog(format,...) [[RCSMLogger sharedInstance] log: __func__ \
                              line: __LINE__ level: kErrLevel string: (format), ##__VA_ARGS__]

#define verboseLog(format,...) [[RCSMLogger sharedInstance] log: __func__ \
                                line: __LINE__ level: kVerboseLevel string: (format), ##__VA_ARGS__]

@interface RCSMLogger : NSObject
{
@private
  NSFileHandle *mLogHandle;
  NSString *mLogName;
  int mLevel;
}

+ (RCSMLogger *)sharedInstance;
+ (id)allocWithZone: (NSZone *)aZone;

- (id)copyWithZone:  (NSZone *)aZone;
- (id)init;
- (id)retain;
- (unsigned)retainCount;
- (void)release;
- (id)autorelease;

- (void)log: (const char *)aCaller
       line: (int)aLineNumber
      level: (int)aLogLevel
     string: (NSString *)aFormat, ...;

@end

#endif