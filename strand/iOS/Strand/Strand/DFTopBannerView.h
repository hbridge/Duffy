//
//  DFTopBannerView.h
//  Strand
//
//  Created by Henry Bridge on 12/2/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFTopBannerView : UIView
@property (weak, nonatomic) IBOutlet UIImageView *leftImageView;
@property (weak, nonatomic) IBOutlet UILabel *textLabel;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;

@property (nonatomic, copy) DFVoidBlock actionButtonHandler;

- (IBAction)actionButtonPressed:(id)sender;

@end
