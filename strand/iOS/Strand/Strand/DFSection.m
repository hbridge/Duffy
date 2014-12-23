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

@end
