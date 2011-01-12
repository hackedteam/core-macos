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

//
// Only used if there's no other name to use
//
#define DEFAULT_CONF_NAME    @"PWR84nQ0C54WR.Y8n"

@interface RCSMConfManager : NSObject
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
  RCSMEncryption *mEncryption;
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

- (RCSMEncryption *)encryption;

@end

#endif