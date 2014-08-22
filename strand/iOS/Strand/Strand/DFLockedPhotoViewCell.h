//
//  DFLockedPhotoViewCell.h
//  Strand
//
//  Created by Henry Bridge on 8/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoViewCell.h"
#import "LFGlassView.h"

@interface DFLockedPhotoViewCell : UICollectionViewCell


@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic, retain) LFGlassView *glassView;

@end
