//
//  Transport.h
//  RCSMac
//
//  Created by revenge on 1/13/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol Transport

@required
- (BOOL)connectToHost: (NSString *)aHost;
- (BOOL)disconnect;

@end