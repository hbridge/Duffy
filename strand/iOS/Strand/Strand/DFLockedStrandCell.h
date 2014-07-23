//
//  DFLockedStrandCell.h
//  Strand
//
//  Created by Henry Bridge on 7/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFLockedStrandCell : UITableViewCell <UICollectionViewDataSource, UICollectionViewDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

- (void)setImages:(NSArray *)images;
- (void)addImage:(UIImage *)image;
                  
@end
