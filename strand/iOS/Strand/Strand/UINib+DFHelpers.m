//
//  UINib+DFHelpers.m
//  Strand
//
//  Created by Henry Bridge on 9/30/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "UINib+DFHelpers.h"

@implementation UINib (DFHelpers)

+ (id)instantiateViewWithClass:(Class)class
{
  return [[[UINib nibWithNibName:NSStringFromClass(class) bundle:nil] instantiateWithOwner:nil options:nil] firstObject];
}

@end
