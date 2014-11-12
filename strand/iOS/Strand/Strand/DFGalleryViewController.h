//
//  DFGalleryViewController.h
//  Strand
//
//  Created by Henry Bridge on 11/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFImageDataSource.h"

@interface DFGalleryViewController : UIViewController <DFImageDataSourceDelegate, UICollectionViewDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (nonatomic) NSUInteger numPhotosPerRow;

@end
