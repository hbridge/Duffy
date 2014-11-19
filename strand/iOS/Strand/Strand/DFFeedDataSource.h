//
//  DFFeedDataSource.h
//  Strand
//
//  Created by Henry Bridge on 11/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DFFeedDataSource;
@class DFPeanutFeedObject;

@protocol DFFeedDataSourceDelegate <NSObject>

- (void)feedDataSource:(DFFeedDataSource *)datasource likeButtonPressedForPhoto:(DFPeanutFeedObject *)photo;
- (void)feedDataSource:(DFFeedDataSource *)datasource commentButtonPressedForPhoto:(DFPeanutFeedObject *)photo;
- (void)feedDataSource:(DFFeedDataSource *)datasource moreButtonPressedForPhoto:(DFPeanutFeedObject *)photo;

@end


@interface DFFeedDataSource : NSObject <UITableViewDataSource, UITableViewDelegate, UICollectionViewDelegate>

@property (nonatomic, retain) NSArray *photosAndClusters;
@property (nonatomic, weak) UITableView *tableView;
@property (nonatomic, weak) id<DFFeedDataSourceDelegate> delegate;

- (NSIndexPath *)indexPathForPhotoID:(DFPhotoIDType)photoID;
- (DFPeanutFeedObject *)objectAtIndexPath:(NSIndexPath *)indexPath;
- (DFPeanutFeedObject *)photoWithID:(DFPhotoIDType)photoID;

- (void)reloadRowForPhotoID:(DFPhotoIDType)photoID;
- (void)removePhoto:(DFPeanutFeedObject *)photoObject;

@end
