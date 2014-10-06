//
//  NSIndexPath+DFHelpers.m
//  Strand
//
//  Created by Henry Bridge on 10/6/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "NSIndexPath+DFHelpers.h"

@implementation NSIndexPath (DFHelpers)

- (id)dictKey
{
  if ([self class] == [NSIndexPath class]) {
    return self;
  }
  
  return [NSIndexPath indexPathForRow:self.row inSection:self.section];
}

@end
