//
//  DFSpringAttachmentBehavior.m
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSpringAttachmentBehavior.h"

@implementation DFSpringAttachmentBehavior

-(instancetype)initWithAnchorPoint:(CGPoint)anchorPoint attachedView:(UIView *)attachedView
{
  if(self=[super init])
  {
    
    UIAttachmentBehavior *item1AttachmentBehavior = [[UIAttachmentBehavior alloc]
                                                     initWithItem:attachedView
                                                     attachedToAnchor:anchorPoint];
    item1AttachmentBehavior.length = 0.0;
    [item1AttachmentBehavior setFrequency:3];
    [item1AttachmentBehavior setDamping:2];
    
    [self addChildBehavior:item1AttachmentBehavior];
  }
  
  return self;
}

@end
