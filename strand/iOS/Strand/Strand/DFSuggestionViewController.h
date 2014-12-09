//
//  DFSuggestionViewController.h
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GBFlatButton/GBFlatButton.h>
#import <SAMGradientView.h>
#import "DFProfileWithContextView.h"
#import "DFPeanutFeedObject.h"
#import "DFHomeSubViewController.h"

typedef void(^DFSuggestionYesHandler)(DFPeanutFeedObject *suggestion, NSArray *contacts);
typedef void(^DFSuggestionNoHandler)(DFPeanutFeedObject *suggestion);


@interface DFSuggestionViewController : DFHomeSubViewController
@property (weak, nonatomic) IBOutlet UILabel *topLabel;
@property (weak, nonatomic) IBOutlet UILabel *bottomLabel;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet GBFlatButton *yesButton;
@property (weak, nonatomic) IBOutlet SAMGradientView *footerView;
@property (nonatomic) CGRect frame;
@property (nonatomic, copy) DFSuggestionYesHandler yesButtonHandler;
@property (nonatomic, copy) DFSuggestionNoHandler noButtonHandler;

@property (nonatomic, retain) DFPeanutFeedObject *suggestionFeedObject;
@property (nonatomic, retain) DFPeanutFeedObject *photoFeedObject;
@property (nonatomic, retain) NSArray *selectedPeanutContacts;


- (void)configureWithSuggestion:(DFPeanutFeedObject *)suggestion withPhoto:(DFPeanutFeedObject *)photo;

- (IBAction)yesButtonPressed:(id)sender;
- (IBAction)noButtonPressed:(id)sender;


@end
