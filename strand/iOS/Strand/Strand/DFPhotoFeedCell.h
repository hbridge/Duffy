//
//  DFPhotoFeedCell.h
//  Strand
//
//  Created by Henry Bridge on 7/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol DFPhotoFeedCellDelegate <NSObject>
@required

- (void)favoriteButtonPressedForObject:(id)object;
- (void)moreOptionsButtonPressedForObject:(id)object;

@end


@interface DFPhotoFeedCell : UITableViewCell <UICollectionViewDelegate, UICollectionViewDataSource>

// Views
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UIButton *favoritersButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingActivityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *favoriteButton;
@property (weak, nonatomic) IBOutlet UIButton *moreOptionsButton;
@property (weak, nonatomic) IBOutlet UIImageView *photoImageView;
@property (strong, nonatomic) IBOutlet UICollectionView *collectionView;

// Delegate
@property (nonatomic, weak) NSObject <DFPhotoFeedCellDelegate> *delegate;

// Objects that the cell represents
@property (strong, nonatomic) NSArray *objects;
- (void)setImage:(UIImage *)image forObject:(id)clusterObject;

- (void)setFavoritersListHidden:(BOOL)hidden;
- (void)setClusterViewHidden:(BOOL)hidden;



@end
