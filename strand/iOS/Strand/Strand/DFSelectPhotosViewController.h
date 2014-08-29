//
//  DFSelectPhotosViewController.h
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutSearchObject.h"

@interface DFSelectPhotosViewController : UICollectionViewController

@property (nonatomic, retain) DFPeanutSearchObject *sectionObject;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;

@end
