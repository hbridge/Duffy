//
//  DFPhotoStore.h
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DropboxSDK/DBRestClient.h>

@class DBRestClient;


@interface DFPhotoStore : NSObject <DBRestClientDelegate>

extern NSString *const DFPhotoStoreReadyNotification;

+ (DFPhotoStore *)sharedStore;
- (NSArray *)cameraRoll;

- (NSArray *)allAlbumsByName;
- (NSArray *)allAlbumsByCount;

@end
