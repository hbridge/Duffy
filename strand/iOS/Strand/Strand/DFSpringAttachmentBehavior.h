//
//  DFSpringAttachmentBehavior.h
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface DFSpringAttachmentBehavior : UIDynamicBehavior

-(instancetype)initWithAnchorPoint:(CGPoint)anchorPoint attachedView:(UIView *)attachedView;

@end
