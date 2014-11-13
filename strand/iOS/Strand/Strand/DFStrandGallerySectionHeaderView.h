//
//  DFStrandGallerySectionHeaderView.h
//  Strand
//
//  Created by Henry Bridge on 9/26/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFProfileStackView.h"

@interface DFStrandGallerySectionHeaderView : UICollectionReusableView
@property (weak, nonatomic) IBOutlet DFProfileStackView *profilePhotoView;
@property (weak, nonatomic) IBOutlet UILabel *actorLabel;
@property (weak, nonatomic) IBOutlet UILabel *actionLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;

@end
