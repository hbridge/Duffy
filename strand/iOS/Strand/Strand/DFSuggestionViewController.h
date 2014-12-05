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

@interface DFSuggestionViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *topLabel;
@property (weak, nonatomic) IBOutlet UILabel *bottomLabel;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet GBFlatButton *yesButton;
@property (weak, nonatomic) IBOutlet SAMGradientView *footerView;
@property (nonatomic) CGRect frame;
@property (nonatomic, copy) DFVoidBlock yesButtonHandler;
@property (nonatomic, copy) DFVoidBlock noButtonHandler;
@property (nonatomic, copy) DFVoidBlock suggestionsOutHandler;

@property (nonatomic, retain) DFPeanutFeedObject *suggestionFeedObject;
@property (nonatomic, retain) DFPeanutFeedObject *photoFeedObject;

- (void)configureWithSuggestion:(DFPeanutFeedObject *)suggestion withPhoto:(DFPeanutFeedObject *)photo;

- (IBAction)yesButtonPressed:(id)sender;
- (IBAction)noButtonPressed:(id)sender;


@end
