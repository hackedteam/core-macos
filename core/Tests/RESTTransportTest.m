//
//  RESTTransportTest.m
//  RCSMac
//
//  Created by revenge on 1/19/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GHUnit/GHUnit.h>

#import "RESTTransport.h"


@interface RESTTransportTest : GHTestCase

@end

@implementation RESTTransportTest

- (BOOL)shouldRunOnMainThread
{
  // By default NO, but if you have a UI test or test dependent on running on the main thread return YES
  return NO;
}

- (void)setUpClass
{
  // Run at start of all tests in the class
}

- (void)tearDownClass
{
  // Run at end of all tests in the class
}

- (void)setUp
{
  // Run before each test method
}

- (void)tearDown
{
  // Run after each test method
}

- (void)testAllocation
{
  NSURL *aURL = [[NSURL alloc] initWithString: @"http://192.168.1.153"];
  RESTTransport *transport = [[RESTTransport alloc] initWithURL: aURL
                                                         onPort: 80];
  
  GHAssertNotNULL(transport, nil, @"Error on allocation");
  
  [aURL release];
  [transport release];
}

- (void)testInitParameters
{
  NSURL *aURL = [[NSURL alloc] initWithString: @"http://192.168.1.153"];
  RESTTransport *transport = [[RESTTransport alloc] initWithURL: aURL
                                                         onPort: -1];
  
  GHAssertNULL(transport, @"Allocation should fail with wrong parameters (port)");
  
  [aURL release];
  [transport release];
}

@end