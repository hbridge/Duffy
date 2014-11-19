//
//  DFCollectionViewTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFCollectionViewTableViewCell : UITableViewCell <UICollectionViewDataSource, UICollectionViewDelegate>
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;


typedef void (^DFCollectionTableViewCellObjectTappedBlock)(id tappedObject);

// Objects that the cell represents
@property (nonatomic, retain) NSArray *objects;
- (void)setImage:(UIImage *)image forObject:(id<NSCopying>)object;
- (UIImage *)imageForObject:(id<NSCopying>)object;

- (void)setObject:(id<NSCopying>)object tappedHandler:(DFCollectionTableViewCellObjectTappedBlock)handler;

@end
