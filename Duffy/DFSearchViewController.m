//
//  DFSearchViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/14/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSearchViewController.h"
#import "DFUser.h"
#import "DFSearchDisplayController.h"

@interface DFSearchViewController ()

@property (nonatomic, retain) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, retain) UIBarButtonItem *loadingIndicatorItem;
@property (nonatomic, retain) UIBarButtonItem *refreshBarButtonItem;
@property (nonatomic, retain) DFSearchDisplayController *sdc;

@end

static NSString *SearchBaseURL = @"http://asood123.no-ip.biz:7000/viz/search/";
static NSString *PhoneIDURLParameter = @"phone_id";
static NSString *QueryURLParameter = @"q";


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
        self.sdc = [[DFSearchDisplayController alloc] initWithSearchBar:[[UISearchBar alloc] init]
                                                     contentsController:self];
        
        
        self.tabBarItem.title = @"Search";
        self.tabBarItem.image = [UIImage imageNamed:@"Search"];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.webView setDelegate:self];
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
    [self.webView reload];
}


- (void)executeSearchForQuery:(NSString *)query
{
   
    NSString *queryURLString = [NSString stringWithFormat:@"%@?%@=%@&%@=%@",
                                SearchBaseURL,
                                PhoneIDURLParameter, [[DFUser currentUser] deviceID],
                                QueryURLParameter, [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSURL *queryURL = [NSURL URLWithString:queryURLString];
    
    NSLog(@"Executing search for URL: %@", queryURL.absoluteString);
    [self.webView loadRequest:[NSURLRequest requestWithURL:queryURL]];
}


@end
