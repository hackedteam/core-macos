//
//  RESTNetworkProtocolTest.m
//  RCSMac
//
//  Created by revenge on 1/19/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GHUnit/GHUnit.h>

#import "RESTNetworkProtocol.h"


@interface RESTNetworkProtocolTest : GHTestCase

@end

@implementation RESTNetworkProtocolTest

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
  RESTNetworkProtocol *protocol = [[RESTNetworkProtocol alloc] initWithHost: @"192.168.1.153"
                                                                     onPort: 8080];
  
  // Assert protocol is not NULL, with no custom error description
  GHAssertNotNULL(protocol, nil, @"Error on allocation");
  
  [protocol release];
}

- (void)testInitParameters
{
  RESTNetworkProtocol *protocol = [[RESTNetworkProtocol alloc] initWithHost: @""
                                                                     onPort: 8080];
  GHAssertNULL(protocol, @"Allocation should fail with wrong parameters (host)");
  [protocol release];
  
  protocol = [[RESTNetworkProtocol alloc] initWithHost: @"192.168.1.153"
                                                onPort: -1];
  GHAssertNULL(protocol, @"Allocation should fail with wrong parameters (port)");
  [protocol release];
}

- (void)testPerform
{
  RESTNetworkProtocol *protocol = [[RESTNetworkProtocol alloc] initWithHost: @"192.168.1.153"
                                                                     onPort: 8080];
  
  GHAssertNotNULL(protocol, @"Allocation failed");
  
  BOOL success = [protocol perform];
  
  GHAssertTrue(success, @"Something went wrong during perform operation");
  
  [protocol release];
}

@end