/*
 * NSApplication category - Method for systemVersion
 *
 *  http://www.cocoadev.com/index.pl?DeterminingOSVersion
 *   # Cocoa Code for Gestalt
 *
 * Created by Alfredo 'revenge' Pesoli on 21/06/2010
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import "NSApplication+SystemVersion.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"


@implementation NSApplication (SystemVersion)

- (void)getSystemVersionMajor: (u_int *)major
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
#ifdef DEBUG_APP_SYSVERSION
      errorLog(@"Unable to obtain system version: %ld", (long)err);
#endif
      
      if (major)
        *major = 10;
      if (minor)
        *minor = 0;
      if (bugFix)
        *bugFix = 0;
    }
}

@end