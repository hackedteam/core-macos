//
//  AuthNetworkOperationTest.m
//  RCSMac
//
//  Created by revenge on 1/19/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GHUnit/GHUnit.h>

#import "RESTTransport.h"
#import "AuthNetworkOperation.h"

static NSURL *mURL                = nil;
static RESTTransport *mTransport  = nil;

@interface AuthNetworkOperationTest : GHTestCase

@end

@implementation AuthNetworkOperationTest

- (BOOL)shouldRunOnMainThread
{
  // By default NO, but if you have a UI test or test dependent on running on the main thread return YES
  return NO;
}

- (void)setUpClass
{
  // Run at start of all tests in the class
  mURL = [[NSURL alloc] initWithString: @"http://192.168.1.153:8080/"];
  mTransport = [[RESTTransport alloc] initWithURL: mURL
                                           onPort: 8080];
}

- (void)tearDownClass
{
  // Run at end of all tests in the class
  GHTestLog(@"mURL: %@", mURL);
  [mURL release];
  [mTransport release];
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
  RESTTransport *transport = [[RESTTransport alloc] initWithURL: mURL
                                                         onPort: 80];
  
  AuthNetworkOperation *authOP = [[AuthNetworkOperation alloc]
                                  initWithTransport: transport];
  
  GHAssertNotNULL(authOP, nil, @"Error on allocation");
  
  [transport release];
  [authOP release];
}

- (void)testPerform
{
  AuthNetworkOperation *authOP = [[AuthNetworkOperation alloc]
                                  initWithTransport: mTransport];
  
  BOOL result = [authOP perform];
  GHAssertTrue(result, @"AUTH went wrong");
  
  [authOP release];
}

@end