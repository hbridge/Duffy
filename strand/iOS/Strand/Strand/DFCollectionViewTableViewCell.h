//
//  DFCollectionViewTableViewCell.h
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFCollectionViewTableViewCell : UITableViewCell <UICollectionViewDataSource>
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

// Objects that the cell represents
@property (nonatomic, retain) NSArray *objects;
- (void)setImage:(UIImage *)image forObject:(id)object;
- (UIImage *)imageForObject:(id)object;

@end
