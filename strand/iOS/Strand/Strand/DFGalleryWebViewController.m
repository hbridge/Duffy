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
#import "DFAnalytics.h"
#import "DFSettingsViewController.h"
#import "DFPeanutGalleryAdapter.h"
#import "DFPeanutSearchObject.h"

@interface DFGalleryWebViewController ()

@property (nonatomic, retain) NSURL *currentPhotoURL;
@property (nonatomic, retain) NSArray *currentPhotoArrayURLStrings;
@property (readonly, nonatomic, retain) DFPeanutGalleryAdapter *peanutGalleryAdapter;
@property (nonatomic, retain) NSMutableDictionary *photoActions;

@end

@implementation DFGalleryWebViewController\

@synthesize peanutGalleryAdapter = _peanutGalleryAdapter;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    self.navigationItem.title = @"Shared";
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
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self.webView action:@selector(reload) forControlEvents:UIControlEventValueChanged];
  [_webView.scrollView addSubview:self.refreshControl]; //<- this is point to use. Add "scrollView" property.
  
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
  [(RootViewController *)self.view.window.rootViewController setSwipingEnabled:YES];
  [(RootViewController *)self.view.window.rootViewController setHideStatusBar:NO];
  [[NSNotificationCenter defaultCenter] postNotificationName:DFStrandGalleryAppearedNotificationName
                                                      object:self
                                                    userInfo:nil];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)setNavigationButtons
{
  if (!(self.navigationItem.rightBarButtonItems.count > 0)) {
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc]
                                     initWithImage:[[UIImage imageNamed:@"Assets/Icons/SettingsBarButton.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                     style:UIBarButtonItemStylePlain
                                     target:self
                                     action:@selector(settingsButtonPressed:)];
    UIBarButtonItem *cameraButton = [[UIBarButtonItem alloc]
                                     initWithImage:[[UIImage imageNamed:@"Assets/Icons/CameraBarButton.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                     style:UIBarButtonItemStylePlain
                                     target:self
                                     action:@selector(cameraButtonPressed:)];
    
    self.navigationItem.leftBarButtonItems = @[settingsButton];
    self.navigationItem.rightBarButtonItems = @[cameraButton];
  }
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
  DDLogInfo(@"Fetching url:%@", webView.request.URL.absoluteString);
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  [self setNavigationButtons];
  [self updateGalleryActions];
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
  [self.refreshControl endRefreshing];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  [self setNavigationButtons];
}


- (void)updateGalleryActions
{
  [self.peanutGalleryAdapter fetchGalleryWithCompletionBlock:^(DFPeanutSearchResponse *response) {
    if (response.result) {
      self.photoActions = [[NSMutableDictionary alloc] init];
      for (DFPeanutSearchObject *object in response.objects) {
        [DFGalleryWebViewController addObjectActionsForObject:object toDictionary:self.photoActions];
      }
    }
  }];
}

+ (void)addObjectActionsForObject:(DFPeanutSearchObject *)searchObject
                     toDictionary:(NSMutableDictionary *)dict
{
  for (DFPeanutAction *action in searchObject.actions) {
    NSMutableArray *actionsForPhoto = dict[@(action.photo)];
    if (!actionsForPhoto) {
      actionsForPhoto = [[NSMutableArray alloc] init];
      dict[@(action.photo)] = actionsForPhoto;
    }
    [actionsForPhoto addObject:action];
  }
  
  for (DFPeanutSearchObject *subObject in searchObject.objects) {
    [DFGalleryWebViewController addObjectActionsForObject:subObject toDictionary:dict];
  }
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
  pvc.photoActions = self.photoActions[@(pvc.photoID)];
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
  pvc.photoActions = self.photoActions[@(pvc.photoID)];
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

#pragma mark - User Actions

- (void)cameraButtonPressed:(UIButton *)sender
{
  [(RootViewController *)self.view.window.rootViewController showCamera];
}

- (void)settingsButtonPressed:(UIButton *)sender
{
  DFSettingsViewController *settingsViewController = [[DFSettingsViewController alloc] init];
  [self presentViewController:[[UINavigationController alloc]
                               initWithRootViewController:settingsViewController]
                     animated:YES
                   completion:nil];
}

#pragma mark - Adapters

- (DFPeanutGalleryAdapter *)peanutGalleryAdapter
{
  if (!_peanutGalleryAdapter) {
    _peanutGalleryAdapter = [[DFPeanutGalleryAdapter alloc] init];
  }
  
  return _peanutGalleryAdapter;
}


@end
