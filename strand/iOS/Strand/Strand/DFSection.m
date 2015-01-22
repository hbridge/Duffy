//
//  DFSection.m
//  Strand
//
//  Created by Henry Bridge on 12/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSection.h"

@implementation DFSection

+ (DFSection *)sectionWithTitle:(NSString *)title
                         object:(id)object
                           rows:(NSArray *)rows
{
  DFSection *section = [DFSection new];
  section.title = title;
  section.object = object;
  section.rows = rows;
  return section;
}

- (id)copyWithZone:(NSZone *)zone
{
  DFSection *newSection = [[DFSection allocWithZone:zone] init];
  newSection.title = [self.title copyWithZone:zone];
  newSection.object = self.object;
  newSection.rows = [self.rows copyWithZone:zone];
  return newSection;
}

- (BOOL)isEqual:(id)object
{
  return [self.title isEqual:[object title]];
}

- (NSUInteger)hash
{
  return [self.title hash];
}

@end
