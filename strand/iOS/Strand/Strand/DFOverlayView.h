//
//  DFOverlayView.h
//  Strand
//
//  Created by Henry Bridge on 12/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFOverlayView : UIView

@property (nonatomic, retain) UIButton *closeButton;
@property (nonatomic, copy) DFVoidBlock closeButtonHandler;

- (void)setContentView:(UIView *)view;

@end
