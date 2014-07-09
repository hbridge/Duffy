//
//  DFWebViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFWebViewController.h"

@interface DFWebViewController ()

@end

@implementation DFWebViewController

- (instancetype)initWithURL:(NSURL *)url
{
  self = [super init];
  if (self) {
    self.initialURL = url;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.webView.delegate = self;
  if (self.navigationController.viewControllers.firstObject == self) {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                             target:self
                                             action:@selector(doneButtonPressed:)];
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  [self.webView loadRequest:[NSURLRequest requestWithURL:self.initialURL]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
  [self updateButtons];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
  [self updateButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
  [self updateButtons];
}

- (void)updateButtons
{
  self.backButton.enabled = self.webView.canGoBack;
  self.forwardButton.enabled = self.webView.canGoForward;
}

- (IBAction)backButtonPressed:(UIBarButtonItem *)sender {
  [self.webView goBack];
}

- (IBAction)refreshButtonPressed:(UIBarButtonItem *)sender {
  [self.webView reload];
}

- (IBAction)forwardButtonPressed:(UIBarButtonItem *)sender {
  [self.webView goForward];
}

- (void)doneButtonPressed:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

@end
