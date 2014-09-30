//
//  DFStrandGalleryViewController.h
//  Strand
//
//  Created by Henry Bridge on 9/26/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutFeedObject.h"

@interface DFStrandGalleryViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (weak, nonatomic) IBOutlet UILabel *peopleLabel;
@property (weak, nonatomic) IBOutlet UIImageView *invitedPeopleIcon;
@property (weak, nonatomic) IBOutlet UILabel *invitedPeopleLabel;
@property (weak, nonatomic) IBOutlet UILabel *peopleBackgroundView;
@property (nonatomic, retain) DFPeanutFeedObject *strandPosts;

@property (nonatomic, retain) UIRefreshControl *refreshControl;

@end
