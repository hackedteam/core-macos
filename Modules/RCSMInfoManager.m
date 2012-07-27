/*
 *  RCSMInfoManager.m
 *  RCSMac
 *
 * Created by Alfredo 'revenge' Pesoli on 5/26/11.
 * Copyright 2011 HT srl. All rights reserved.
 */

#import "RCSMInfoManager.h"
#import "RCSMLogManager.h"
#import "RCSMTaskManager.h"
#import "RCSMCommon.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"


@implementation __m_MInfoManager

- (BOOL)logActionWithDescription: (NSString *)description
{
  int a = 0;
  a++;
  if (description == nil)
    {
#ifdef DEBUG_INFO_MANAGER
      errorLog(@"description is nil");
#endif
      return NO;
    }

  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];

#ifdef DEBUG_INFO_MANAGER
  infoLog(@"description: %@", description);
#endif

  __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
  
  BOOL success = [logManager createLog: LOG_INFO
                           agentHeader: nil
                             withLogID: 0];

  a--;
  
  if (success == TRUE)
    {
      NSMutableData *logData = [[NSMutableData alloc] init];
      [logData appendData: [description dataUsingEncoding:
        NSUTF16LittleEndianStringEncoding]];

      [logManager writeDataToLog: logData
                        forAgent: LOG_INFO
                       withLogID: 0];

      [logManager closeActiveLog: LOG_INFO
                       withLogID: 0];

      [logData release];
    }
  else
    {
#ifdef DEBUG_INFO_MANAGER
      errorLog(@"Error while creating log");
#endif
      return NO;
    }
  
  a++;
  
  [outerPool release];
  return YES;
}

@end
