//
//  DFAcceptInviteViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/6/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFAcceptInviteViewController.h"
#import "DFImageDataSource.h"

@interface DFAcceptInviteViewController ()

@property (nonatomic, retain) DFPeanutFeedObject *inviteObject;
@property (nonatomic, retain) DFPeanutFeedObject *invitedStrandPosts;
@property (nonatomic, retain) DFPeanutFeedObject *suggestedPhotosPosts;

@property (nonatomic, retain) DFImageDataSource *invitedPhotosDatasource;
@property (nonatomic, retain) DFImageDataSource *suggestedPhotosDatasource;

@end

@implementation DFAcceptInviteViewController

- (instancetype)initWithInviteObject:(DFPeanutFeedObject *)inviteObject
{
  self = [super init];
  if (self) {
    _inviteObject = inviteObject;
    _invitedStrandPosts = [[inviteObject subobjectsOfType:DFFeedObjectStrandPosts]
                               firstObject];
    _suggestedPhotosPosts = [[inviteObject subobjectsOfType:DFFeedObjectSuggestedPhotos]
                            firstObject];
    self.navigationItem.title = @"Swap Photos";
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  [self configureInviteArea];
  [self configureMatchedArea];
}

- (BOOL)hidesBottomBarWhenPushed
{
  return YES;
}

- (void)configureInviteArea
{
  // aesthetics
  self.inviteWrapper.layer.cornerRadius = 4.0;
  self.inviteWrapper.clipsToBounds = YES;
  
  //name and title
  self.actorLabel.text = self.inviteObject.actorsString;
  self.titleLabel.text = self.invitedStrandPosts.title;
  
  //collection view
  NSMutableArray *allPhotos = [NSMutableArray new];
  for (DFPeanutFeedObject *post in self.invitedStrandPosts.objects) {
    [allPhotos addObjectsFromArray:post.objects];
  }
  self.invitedPhotosDatasource = [[DFImageDataSource alloc]
                                  initWithFeedPhotos:allPhotos
                                  collectionView:self.invitedCollectionView
                                  sourceMode:DFImageDataSourceModeRemote
                                  imageType:DFImageThumbnail];
}

- (void)configureMatchedArea
{
  NSMutableArray *suggestedPhotos = [NSMutableArray new];
  for (DFPeanutFeedObject *suggestedPhotosSection in self.suggestedPhotosPosts.objects) {
    [suggestedPhotos addObjectsFromArray:suggestedPhotosSection.objects];
  }
  self.suggestedPhotosDatasource = [[DFImageDataSource alloc]
                                    initWithFeedPhotos:suggestedPhotos
                                    collectionView:self.matchedCollectionView sourceMode:DFImageDataSourceModeLocal
                                    imageType:DFImageFull];
}


- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

- (IBAction)matchButtonPressed:(UIButton *)sender {
  [self.matchButtonWrapper removeFromSuperview];
  self.matchingActivityWrapper.hidden = NO;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    self.matchingActivityWrapper.hidden = YES;
    self.matchedCollectionView.hidden = NO;
  });
  
  [self setMatchedAreaAttributes];
}

- (void)setMatchedAreaAttributes
{
  // configure flow layout cell size
  static int itemsPerRow = 2;
  static CGFloat interItemSpacing = 0.5;
  static CGFloat interItemSpacingPerRow = 0.5 * (2 - 1);
  CGFloat size1d = (self.matchedCollectionView.frame.size.width - interItemSpacingPerRow)
  / (CGFloat)itemsPerRow;
  size1d = floor(size1d);
  self.matchedFlowLayout.itemSize = CGSizeMake(size1d, size1d);
  self.matchedFlowLayout.minimumInteritemSpacing = interItemSpacing;
  self.matchedFlowLayout.minimumLineSpacing = interItemSpacing;
}
@end
