//
//  DFGalleryWebViewController.m
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFGalleryWebViewController.h"
#import "DFNetworkingConstants.h"
#import "DFUser.h"
#import "RootViewController.h"

@interface DFGalleryWebViewController ()

@end

@implementation DFGalleryWebViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    self.navigationItem.title = @"Gallery";
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self setNavigationButtons];

  // setup webview
  self.webView.delegate = self;
  self.navigationController.navigationBar.tintColor =
  [UIColor orangeColor];
  
  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *urlString = [NSString stringWithFormat:@"%@/strand/viz/neighbors?user_id=%llu",
                           DFServerBaseURL, [[DFUser currentUser] userID]];
    NSURL *urlToLoad = [NSURL URLWithString:urlString];
    [self.webView loadRequest:[NSURLRequest requestWithURL:urlToLoad]];
  });
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  if (![self.webView isLoading]) {
    [self.webView reload];
  }
  
  [(RootViewController *)self.view.window.rootViewController setHideStatusBar:NO];
}

- (void)setNavigationButtons
{
  if (!(self.navigationItem.leftBarButtonItems.count > 0)) {
    self.backButtonItem = [[UIBarButtonItem alloc]
                           initWithImage:[UIImage imageNamed:@"Assets/Icons/BackBarButtonIcon.png"]
                           style:UIBarButtonItemStylePlain
                           target:self.webView
                           action:@selector(goBack)];
    
    self.forwardButtonItem = [[UIBarButtonItem alloc]
                              initWithImage:[UIImage imageNamed:@"Assets/Icons/ForwardBarButtonIcon.png"]
                              style:UIBarButtonItemStylePlain
                              target:self.webView
                              action:@selector(goForward)];
    self.refreshButtonItem = [[UIBarButtonItem alloc]
                              initWithImage:[UIImage imageNamed:@"Assets/Icons/RefreshBarButtonIcon.png"]
                              style:UIBarButtonItemStylePlain
                              target:self.webView
                              action:@selector(reload)];
    UIBarButtonItem *cameraButton = [[UIBarButtonItem alloc]
                                     initWithImage:[[UIImage imageNamed:@"Assets/Icons/CameraBarButton.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                     style:UIBarButtonItemStylePlain
                                     target:self
                                     action:@selector(cameraButtonPressed:)];
    
    self.navigationItem.leftBarButtonItems = @[self.backButtonItem, self.forwardButtonItem];
    self.navigationItem.rightBarButtonItems = @[cameraButton, self.refreshButtonItem];
  }
      
  self.backButtonItem.enabled = self.webView.canGoBack;
  self.forwardButtonItem.enabled = self.webView.canGoForward;
  self.refreshButtonItem.enabled = YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
  DDLogInfo(@"Fetching url:%@", webView.request.URL.absoluteString);
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  [self setNavigationButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  [self setNavigationButtons];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  [self setNavigationButtons];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (IBAction)cameraButtonPressed:(UIButton *)sender {
  [(RootViewController *)self.view.window.rootViewController showCamera];
}
@end
