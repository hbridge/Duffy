//
//  DFWebViewController.h
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFWebViewController : UIViewController <UIWebViewDelegate>

@property (nonatomic, retain) NSURL *initialURL;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *backButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *refreshButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *forwardButton;

- (id)initWithURL:(NSURL *)url;

- (IBAction)backButtonPressed:(UIBarButtonItem *)sender;
- (IBAction)refreshButtonPressed:(UIBarButtonItem *)sender;
- (IBAction)forwardButtonPressed:(UIBarButtonItem *)sender;

@end
