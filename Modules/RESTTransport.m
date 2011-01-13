//
//  RESTTransport.m
//  RCSMac
//
//  Created by revenge on 1/13/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RESTTransport.h"


@implementation RESTTransport

// Abstract Class Methods
- (BOOL)connectToHost: (NSString *)aHost
{
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
  NSLog(@"aPacketData: %@", aPacketData);
#endif
  
  return nil;
}

@end