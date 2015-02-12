//
//  DFSuggestionContentView.h
//  Strand
//
//  Created by Henry Bridge on 12/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFProfileStackView.h"
#import "UIViewController+DFKeyboardObserving.h"

@interface DFOutgoingCardContentView : UIView <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel *topLabel;
@property (weak, nonatomic) IBOutlet DFProfileStackView *profileStackView;
@property (weak, nonatomic) IBOutlet UIButton *addButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UITextField *commentTextField;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *commentTextFieldBottomConstraint;

- (IBAction)addButtonPressed:(id)sender;

@property (nonatomic, copy) DFVoidBlock addHandler;

- (void)showAddPeoplePopup;
- (void)dismissAddPeoplePopup;
- (void)showNearbyPeoplePopup;
- (void)dismissNearbyPeoplePopup;


@end
