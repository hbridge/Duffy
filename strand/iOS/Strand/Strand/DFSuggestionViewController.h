//
//  DFSuggestionViewController.h
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GBFlatButton/GBFlatButton.h>
#import "DFProfileWithContextView.h"

@class DFPeanutFeedObject;

@interface DFSuggestionViewController : UIViewController
@property (weak, nonatomic) IBOutlet DFProfileWithContextView *profileWithContextView;
@property (weak, nonatomic) IBOutlet UILabel *topLabel;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet GBFlatButton *requestButton;
@property (nonatomic) CGRect frame;
@property (nonatomic, copy) DFVoidBlock requestButtonHandler;

@property (nonatomic, retain) DFPeanutFeedObject *suggestionFeedObject;
- (IBAction)requestButtonPressed:(id)sender;

@end
