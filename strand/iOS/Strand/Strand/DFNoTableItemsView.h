//
//  DFNoTableItemsLabel.h
//  Strand
//
//  Created by Henry Bridge on 10/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFNoTableItemsView : UIView

- (instancetype)initWithSuperView:(UIView *)superview;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UIButton *button;
@property (nonatomic, copy) DFVoidBlock buttonHandler;

- (void)setSuperView:(UIView *)superView;
- (IBAction)buttonPressed:(id)sender;

@end
