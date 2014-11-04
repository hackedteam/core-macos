/*
 * RCSMac - RESTTransport
 *  Transport implementation for REST Protocol.
 *
 *
 * Created by revenge on 13/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>
#import "Transport.h"


@interface RESTTransport : Transport <Transport>
{
@private
  NSURL *mURL;
  int32_t mPort;
  NSString *mCookie;
}

- (id)initWithURL: (NSURL *)aURL
           onPort: (int32_t)aPort;

- (void)dealloc;

- (NSData *)sendData: (NSData *)aPacketData
   returningResponse: (NSURLResponse *)aResponse;

@end
