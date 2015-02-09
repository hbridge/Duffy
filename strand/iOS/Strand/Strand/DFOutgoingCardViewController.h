//
//  DFSwipableSuggestionViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSuggestionViewController.h"
#import "DFRecipientPickerViewController.h"
#import "DFOutgoingCardContentView.h"

@interface DFOutgoingCardViewController : DFCardViewController <DFPeoplePickerDelegate, DFProfileStackViewDelegate>

typedef void(^DFSuggestionYesHandler)(DFPeanutFeedObject *suggestion, NSArray *contacts, NSString *caption);
typedef void(^DFSuggestionNoHandler)(DFPeanutFeedObject *suggestedPhoto);

@property (nonatomic, strong) IBOutlet DFOutgoingCardContentView *suggestionContentView;

@property (nonatomic, retain) DFPeanutFeedObject *suggestionFeedObject;
@property (nonatomic, retain) DFPeanutFeedObject *photoFeedObject;
@property (nonatomic, retain) NSArray *selectedPeanutContacts;

@property (nonatomic, copy) DFSuggestionYesHandler yesButtonHandler;
@property (nonatomic, copy) DFSuggestionNoHandler noButtonHandler;
@property (weak, nonatomic) IBOutlet UIButton *noButton;
@property (weak, nonatomic) IBOutlet UIButton *yesButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cardBottomConstraint;

- (void)configureWithSuggestion:(DFPeanutFeedObject *)suggestion withPhoto:(DFPeanutFeedObject *)photo;


@end
