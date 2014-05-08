//
//  DFFaceFeature.m
//  Duffy
//
//  Created by Henry Bridge on 5/7/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFFaceFeature.h"
#import "DFPhoto.h"


@implementation DFFaceFeature

@dynamic boundsString;
@dynamic hasSmile;
@dynamic hasBlink;
@dynamic photo;


- (NSString *)description
{
  return [NSString stringWithFormat:@"DFFaceFeature hasSmile:%@ hasBlink:%@ bounds:%@",
          @(self.hasSmile), @(self.hasBlink), self.boundsString];
}

@end
