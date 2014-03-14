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

@end

@implementation DFSearchViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.navigationController.navigationItem.title = @"Search";
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



@end
