//
//  NSString+PascalTest.m
//  RCSMac
//
//  Created by revenge on 1/25/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GHUnit/GHUnit.h>

#import "NSString+Pascal.h"


@interface NSString_Pascal : GHTestCase

@end

@implementation NSString_Pascal

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

- (void)testFunctionalities
{
  NSString *tmp = [[NSString alloc] initWithString: @"antani"];
  NSData *data  = [tmp pascalizeToData];
  
  GHTestLog(@"nsstring      : %@", tmp);
  GHTestLog(@"nsstring data : %@", [tmp dataUsingEncoding: NSUTF8StringEncoding]);
  GHTestLog(@"pascal data   : %@", data);
  
  [tmp release];
}

@end