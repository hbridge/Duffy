//
//  DFGalleryWebViewController.h
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFGalleryWebViewController : UIViewController <UIWebViewDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (strong, nonatomic) UIBarButtonItem *backButtonItem;
@property (strong, nonatomic) UIBarButtonItem *forwardButtonItem;
@property (strong, nonatomic) UIBarButtonItem *refreshButtonItem;
@property (weak, nonatomic) IBOutlet UIButton *cameraButton;

- (IBAction)cameraButtonPressed:(UIButton *)sender;

@end
