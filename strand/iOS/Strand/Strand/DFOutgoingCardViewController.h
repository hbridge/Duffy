//
//  DFSwipableSuggestionViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSuggestionViewController.h"
#import "DFSwipableButtonView.h"
#import "DFPeoplePickerViewController.h"
#import "DFOutgoingCardContentView.h"

@interface DFOutgoingCardViewController : DFCardViewController <DFSwipableButtonViewDelegate, DFPeoplePickerDelegate, DFProfileStackViewDelegate>

typedef void(^DFSuggestionYesHandler)(DFPeanutFeedObject *suggestion, NSArray *contacts, NSString *caption);
typedef void(^DFSuggestionNoHandler)(DFPeanutFeedObject *suggestedPhoto);


@property (weak, nonatomic) IBOutlet DFSwipableButtonView *swipableButtonView;
@property (nonatomic, strong) DFOutgoingCardContentView *suggestionContentView;

@property (nonatomic, retain) DFPeanutFeedObject *suggestionFeedObject;
@property (nonatomic, retain) DFPeanutFeedObject *photoFeedObject;
@property (nonatomic, retain) NSArray *selectedPeanutContacts;

@property (nonatomic, copy) DFSuggestionYesHandler yesButtonHandler;
@property (nonatomic, copy) DFSuggestionNoHandler noButtonHandler;

- (instancetype)initWithNuxStep:(NSUInteger)step;

- (void)configureWithSuggestion:(DFPeanutFeedObject *)suggestion withPhoto:(DFPeanutFeedObject *)photo;


@end
