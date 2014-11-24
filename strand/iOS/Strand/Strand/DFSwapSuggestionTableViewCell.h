//
//  DFSwapSuggestionTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 11/21/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwapTableViewCell.h"
#import <SAMGradientView/SAMGradientView.h>

@interface DFSwapSuggestionTableViewCell : DFSwapTableViewCell

@property (weak, nonatomic) IBOutlet DFProfileStackView *profilePhotoStackView;
@property (weak, nonatomic) IBOutlet UILabel *topLabel;
@property (weak, nonatomic) IBOutlet UILabel *subTitleLabel;
@property (weak, nonatomic) IBOutlet UIImageView *previewImageView;
@property (weak, nonatomic) IBOutlet UIImageView *profileReplacementImageView;
@property (weak, nonatomic) IBOutlet UIView *buttonBar;
@property (weak, nonatomic) IBOutlet UIButton *requestButton;
@property (weak, nonatomic) IBOutlet UIButton *skipButton;
@property (weak, nonatomic) IBOutlet SAMGradientView *gradientView;
@property (weak, nonatomic) IBOutlet UILabel *explanationLabel;

@property (nonatomic, copy) DFVoidBlock requestButtonHandler;
@property (nonatomic, copy) DFVoidBlock skipButtonHandler;

- (IBAction)requestButtonPressed:(id)sender;
- (IBAction)skipButtonPressed:(id)sender;


@end
