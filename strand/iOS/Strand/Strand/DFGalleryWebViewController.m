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
#import "DFStrandConstants.h"
#import "DFMultiPhotoViewController.h"
#import "DFPhotoViewController.h"

@interface DFGalleryWebViewController ()

@property (nonatomic, retain) NSURL *currentPhotoURL;
@property (nonatomic, retain) NSArray *currentPhotoArrayURLStrings;

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
  self.navigationController.navigationBar.tintColor =
  [UIColor orangeColor];

  // setup webview
  self.webView.delegate = self;
  
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
  [(RootViewController *)self.view.window.rootViewController setHideStatusBar:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
  [[NSUserDefaults standardUserDefaults] setObject:@(0) forKey:DFStrandUnseenCountDefaultsKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [[NSNotificationCenter defaultCenter] postNotificationName:DFStrandUnseenPhotosUpdatedNotificationName
                                                      object:nil
                                                    userInfo:@{DFStrandUnseenPhotosUpdatedCountKey: @(0)}];
  [(RootViewController *)self.view.window.rootViewController setSwipingEnabled:YES];
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
    
    self.navigationItem.leftBarButtonItems = @[self.backButtonItem, self.refreshButtonItem];
    self.navigationItem.rightBarButtonItems = @[cameraButton];
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

- (BOOL)webView:(UIWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{
  NSString *requestURLString = request.URL.absoluteString;
  if ([requestURLString rangeOfString:@"user_data"].location != NSNotFound) {
    [webView stopLoading];
    DDLogVerbose(@"Search result clicked for photo with URL: %@", requestURLString);
    
    [self fullPhotoRequestedWithURL:requestURLString];
    return NO;
  }
  return YES;
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


#pragma mark - Show full photo methods

- (void)fullPhotoRequestedWithURL:(NSString *)requestURLString
{
  NSRange rangeOfQmark = [requestURLString rangeOfCharacterFromSet:
                           [NSCharacterSet characterSetWithCharactersInString:@"?"]];
  NSString *singlePhotoURLString = [requestURLString substringToIndex:rangeOfQmark.location];
  NSURL *singlePhotoURL = [NSURL URLWithString:singlePhotoURLString];
  
  DDLogVerbose(@"photoURL:%@", singlePhotoURL.description);
  
  NSRange photoIDArrayRange = [requestURLString rangeOfString:@"?photoList="];
  NSString *searchResultURLs = [requestURLString
                               substringFromIndex:photoIDArrayRange.location+photoIDArrayRange.length];
  DDLogVerbose(@"searchResultURLs:%@", searchResultURLs);
  NSMutableArray *photoURLStrings = [[NSMutableArray alloc] init];
  for (NSString *idString in [searchResultURLs componentsSeparatedByString:@","]) {
    NSURL *url = [[[[DFUser currentUser] serverURL]
                   URLByAppendingPathComponent:@"user_data"]
                   URLByAppendingPathComponent:idString];
    [photoURLStrings addObject:url.absoluteString];
  }
 
  [self pushPhotoDetailViewForURL:singlePhotoURL inPhotos:photoURLStrings];
}

- (void)pushPhotoDetailViewForURL:(NSURL *)photoURL inPhotos:(NSArray *)otherPhotoURLs
{
  self.currentPhotoArrayURLStrings = otherPhotoURLs;
  self.currentPhotoURL = photoURL;
  
  DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
  pvc.photoURL = photoURL;
  DFMultiPhotoViewController *mpvc = [[DFMultiPhotoViewController alloc] init];
  [mpvc setViewControllers:@[pvc]
                 direction:UIPageViewControllerNavigationDirectionForward
                  animated:NO
                completion:nil];
  mpvc.dataSource = self;
  
  [self.navigationController pushViewController:mpvc animated:YES];
  [(RootViewController *)self.view.window.rootViewController setSwipingEnabled:NO];
}


- (UIViewController*)pageViewController:(UIPageViewController *)pageViewController
     viewControllerBeforeViewController:(UIViewController *)viewController
{
  NSUInteger currentPhotoIDIndex = [self
                                    indexOfPhotoController:(DFPhotoViewController*)viewController];
  NSUInteger newPhotoIDIndex;
  if (currentPhotoIDIndex > 0) {
    newPhotoIDIndex = currentPhotoIDIndex - 1;
  } else {
    newPhotoIDIndex = self.currentPhotoArrayURLStrings.count - 1;
  }

  return [self viewControllerRequestedForIndex:newPhotoIDIndex];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  NSUInteger currentPhotoIDIndex =
  [self indexOfPhotoController:(DFPhotoViewController *)viewController];

  NSUInteger newPhotoIDIndex;
  if (currentPhotoIDIndex < self.currentPhotoArrayURLStrings.count - 1) {
    newPhotoIDIndex = currentPhotoIDIndex + 1;
  } else {
    newPhotoIDIndex = 0;
  }

  return [self viewControllerRequestedForIndex:newPhotoIDIndex];
}

- (UIViewController *)viewControllerRequestedForIndex:(NSUInteger)index
{
  if (index >= self.currentPhotoArrayURLStrings.count) return nil;
  
  NSURL *newPhotoURL = [NSURL URLWithString:[self.currentPhotoArrayURLStrings objectAtIndex:index]];
  DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
  pvc.photoURL = newPhotoURL;
  return pvc;
}


- (NSUInteger)indexOfPhotoController:(DFPhotoViewController *)pvc
{
  NSString *currentURLString = pvc.photoURL.absoluteString;
  return [self.currentPhotoArrayURLStrings indexOfObject:currentURLString];
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
