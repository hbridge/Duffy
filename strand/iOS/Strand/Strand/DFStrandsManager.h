//
//  DFBackgroundRefreshController.h
//  Strand
//
//  Created by Henry Bridge on 6/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CLLocationManagerDelegate.h>

@interface DFStrandsManager : NSObject <CLLocationManagerDelegate>

@property (nonatomic, retain) NSDate *lastFetchAttemptDate;

+ (DFStrandsManager *)sharedStrandsManager;

- (UIBackgroundFetchResult)performFetch:(NSNotification *)note;

- (void)updateJoinableStrands;
- (void)updateNewPhotos;

- (int)numUnseenPhotos;

@end
