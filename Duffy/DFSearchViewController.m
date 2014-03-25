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
@property (nonatomic, retain) UIBarButtonItem *loadingIndicatorItem;
@property (nonatomic, retain) UIBarButtonItem *refreshBarButtonItem;

@end

@implementation DFSearchViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.navigationItem.title = @"Search";
        
        // create loading indicator
        self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        self.loadingIndicator.hidesWhenStopped = YES;
        [self.loadingIndicator startAnimating];
        self.loadingIndicatorItem = [[UIBarButtonItem alloc]
                                     initWithCustomView:self.loadingIndicator];
        self.navigationItem.rightBarButtonItem = self.loadingIndicatorItem;
        
        // create reload button
        self.refreshBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                  target:self
                                                                                  action:@selector(refreshWebView)];
        
        
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
    self.navigationItem.rightBarButtonItem = self.loadingIndicatorItem;
    [self.loadingIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self.loadingIndicator stopAnimating];
    self.navigationItem.rightBarButtonItem = self.refreshBarButtonItem;
}

- (void)refreshWebView
{
    [self.webView loadRequest:[NSURLRequest requestWithURL:[self searchViewURL]]];
}



@end
