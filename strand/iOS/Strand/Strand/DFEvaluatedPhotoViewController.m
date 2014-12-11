//
//  DFEvaluatedPhotoViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFEvaluatedPhotoViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFImageManager.h"

@interface DFEvaluatedPhotoViewController ()

@end

@implementation DFEvaluatedPhotoViewController

- (instancetype)initWithPhotoID:(DFPhotoIDType)photoID
                       inStrand:(DFStrandIDType)strandID
{
  self = [super init];
  if (self) {
    _photoID = photoID;
    _strandID = strandID;
  }
  return self;
}


- (void)viewDidLoad {
  [super viewDidLoad];

  [self configureProfileWithContext];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)configureProfileWithContext
{
  self.profileStackView.backgroundColor = [UIColor clearColor];
  DFPeanutFeedObject *strandPosts = [[DFPeanutFeedDataManager sharedManager] strandPostsObjectWithId:self.strandID];
  
  [self.profileStackView setPeanutUsers:strandPosts.actors];
}

- (void)viewDidLayoutSubviews
{
  [[DFImageManager sharedManager]
   imageForID:self.photoID
   pointSize:self.imageView.frame.size
   contentMode:DFImageRequestContentModeAspectFill
   deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       self.imageView.image = image;
     });
   }];
  
}



@end
