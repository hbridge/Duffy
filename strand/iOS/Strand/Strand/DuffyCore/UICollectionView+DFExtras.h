//
//  UICollectionView+DFExtras.h
//  Duffy
//
//  Created by Henry Bridge on 6/6/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UICollectionView (DFExtras)

- (NSIndexPath *)indexPathForLastCell;
- (void)scrollToBottom;

@end
