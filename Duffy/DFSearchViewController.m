//
//  DFSearchViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/14/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSearchViewController.h"
#import "DFUser.h"

@interface DFSearchViewController ()

@property (nonatomic, retain) UIActivityIndicatorView *loadingIndicator;

@end

@implementation DFSearchViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.navigationItem.title = @"Search";
        self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        self.loadingIndicator.hidesWhenStopped = YES;
        [self.loadingIndicator startAnimating];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                  initWithCustomView:self.loadingIndicator];
        
        
        self.tabBarItem.title = @"Search";
        self.tabBarItem.image = [UIImage imageNamed:@"Search"];
    }
    return self;
}




- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.webView loadRequest:[NSURLRequest requestWithURL:[self searchViewURL]]];
    [self.webView setDelegate:self];

}

- (NSURL *)searchViewURL
{
    NSString *urlString = [NSString stringWithFormat:@"http://photos.derektest1.com/search.php?userId=%@", [DFUser deviceID]];
    return [NSURL URLWithString:urlString];
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
