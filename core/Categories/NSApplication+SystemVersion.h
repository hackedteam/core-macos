//
//  NSApplication+SystemVersion.h
//  RCSMac
//
//  Created by revenge on 6/21/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSApplication (SystemVersion)

- (void)getSystemVersionMajor: (u_int *)major
                        minor: (u_int *)minor
                       bugFix: (u_int *)bugFix;

@end
