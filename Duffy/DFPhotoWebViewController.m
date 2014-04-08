//
//  DFPhotoWebViewController.m
//  Duffy
//
//  Created by Henry Bridge on 4/4/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoWebViewController.h"
#import "DFAnalytics.h"

@interface DFPhotoWebViewController ()

@property (nonatomic, retain) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, retain) UIBarButtonItem *loadingIndicatorItem;

@end

@implementation DFPhotoWebViewController

@synthesize currentPhotoURL;

- (id)initWithPhotoURL:(NSURL *)photoURL
{
    self = [super init];
    if (self) {
        self.navigationItem.title = @"Photo";
        self.currentPhotoURL = photoURL;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.webView.scalesPageToFit = YES;
    [self setupNavBar];
    
    [self loadCurrentPhotoURL];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)setupNavBar
{
    // create loading indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicatorItem = [[UIBarButtonItem alloc]
                                 initWithCustomView:self.loadingIndicator];
    self.navigationItem.rightBarButtonItem = self.loadingIndicatorItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadCurrentPhotoURL
{
    NSURLRequest *request = [NSURLRequest requestWithURL:self.currentPhotoURL];
    [self.webView loadRequest:request];
}


- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self.loadingIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self.loadingIndicator stopAnimating];
}

@end
