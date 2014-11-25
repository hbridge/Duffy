//
//  DFRequestNotificationView.h
//  Strand
//
//  Created by Henry Bridge on 11/24/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GBFlatButton/GBFlatButton.h>
#import "DFProfileWithContextView.h"
#import "DFPeanutFeedObject.h"
#import <SAMGradientView/SAMGradientView.h>

@interface DFRequestViewController : UIViewController
@property (weak, nonatomic) IBOutlet DFProfileWithContextView *profileWithContextView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet GBFlatButton *selectPhotosButton;
@property (weak, nonatomic) IBOutlet SAMGradientView *gradientView;
@property (nonatomic, retain) DFPeanutFeedObject *inviteFeedObject;
@property (nonatomic) CGRect frame;


@property (nonatomic, copy) DFVoidBlock selectButtonHandler;
- (IBAction)selectButtonPressed:(id)sender;

@end
