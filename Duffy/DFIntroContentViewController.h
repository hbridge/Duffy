//
//  DFIntroPageViewController.h
//  Duffy
//
//  Created by Henry Bridge on 5/15/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFIntroPageViewController;

@interface DFIntroContentViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *contentLabel;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) DFIntroPageViewController *pageViewController;


typedef NSString *const DFIntroContentType;
extern DFIntroContentType DFIntroContentWelcome;
extern DFIntroContentType DFIntroContentUploading;
extern DFIntroContentType DFIntroContentDone;
extern DFIntroContentType  DFIntroContentErrorNoUser;
extern DFIntroContentType  DFIntroContentErrorUploading;

@property (nonatomic, retain) DFIntroContentType introContent;


@end
