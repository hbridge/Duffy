//
//  DFSearchNoResultsView.m
//  Duffy
//
//  Created by Henry Bridge on 6/5/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSearchNoResultsView.h"

@implementation DFSearchNoResultsView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib
{
  for (id view in self.subviews) {
    UIFont *font = [UIFont fontWithName:@"ProximaNova-Regular" size:20.0];
    if ([view respondsToSelector:@selector(setFont:)]){
      [view setFont:font];
    }
  }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
