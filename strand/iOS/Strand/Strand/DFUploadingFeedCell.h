//
//  DFUploadingFeedCell.h
//  Strand
//
//  Created by Henry Bridge on 7/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFUploadingFeedCell : UITableViewCell <UICollectionViewDataSource, UICollectionViewDelegate>
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UILabel *statusTextLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (nonatomic, retain) NSArray *images;
- (void)addImage:(UIImage *)image;

@end
