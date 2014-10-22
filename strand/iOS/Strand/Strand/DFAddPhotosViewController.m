//
//  DFAddPhotosViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFAddPhotosViewController.h"
#import "DFPeanutStrandAdapter.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "DFPhotoStore.h"
#import "SVProgressHUD.h"
#import "DFStrandConstants.h"
#import "DFFeedViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFAnalytics.h"

@interface DFAddPhotosViewController ()

@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (copy)void (^swapSuccessful)(void);

@end

@implementation DFAddPhotosViewController

@synthesize strandAdapter = _strandAdapter;
@synthesize inviteAdapter = _inviteAdapter;

- (instancetype)initWithSuggestions:(NSArray *)suggestedSections invite:(DFPeanutFeedObject *)invite swapSuccessful:(void(^)(void))swapSuccessful
{
  self = [self initWithSuggestions:suggestedSections];
  if (self) {
    _inviteObject = invite;
    self.allowsNilSelection = YES;
    self.swapSuccessful = swapSuccessful;
  }
  return self;
}

- (instancetype)initWithSuggestions:(NSArray *)suggestions
{
  self = [super initWithSuggestions:suggestions];
  if (self) {
    [self configureNavBar];
  }
  return self;
}

- (void)configureNavBar
{
  self.navigationItem.title = @"Select Photos";
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.swapButton addTarget:self action:@selector(swapPressed:)
            forControlEvents:UIControlEventTouchUpInside];
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


#pragma mark - Actions

- (void)swapPressed:(id)sender {
  if (self.inviteObject) {
    [self acceptInvite];
  }
}

- (void)acceptInvite
{
  [[DFPeanutFeedDataManager sharedManager]
   acceptInvite:self.inviteObject
   addPhotoIDs:self.selectPhotosController.selectedPhotoIDs
   success:^{
     if (self.swapSuccessful) self.swapSuccessful();
     [self dismissViewControllerAnimated:YES completion:^{
       [SVProgressHUD showSuccessWithStatus:@"Swapped!"];
     }];
  } failure:^(NSError *error) {
    [SVProgressHUD showErrorWithStatus:@"Error."];
  }];
}

- (DFPeanutStrandInviteAdapter *)inviteAdapter
{
  if (!_inviteAdapter) _inviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
  return _inviteAdapter;
}

- (DFPeanutStrandAdapter *)strandAdapter
{
  if (!_strandAdapter) _strandAdapter = [[DFPeanutStrandAdapter alloc] init];
  return _strandAdapter;
}

@end
