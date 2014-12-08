//
//  DFSwipableSuggestionViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSuggestionViewController.h"
#import "DFSwipableButtonImageView.h"
#import "DFPeoplePickerViewController.h"

@interface DFSwipableSuggestionViewController : DFSuggestionViewController <DFSwipableButtonImageViewDelegate, DFPeoplePickerDelegate>

@property (weak, nonatomic) IBOutlet DFProfileStackView *profileStackView;
@property (weak, nonatomic) IBOutlet UILabel *topLabel;
@property (weak, nonatomic) IBOutlet UILabel *bottomLabel;
@property (weak, nonatomic) IBOutlet DFSwipableButtonImageView *swipableButtonImageView;
@property (weak, nonatomic) IBOutlet UIButton *addRecipientButton;
@property (weak, nonatomic) IBOutlet UILabel *peopleLabel;

- (instancetype)initWithNuxStep:(NSUInteger)step;

@end
