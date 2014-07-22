//
//  DFSettings.h
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFSettings : NSObject

+ (DFSettings *)sharedSettings;

@property (nonatomic, retain) NSString *displayName;
@property (readonly, nonatomic, retain) NSString *version;
@property (nonatomic, retain) NSString *phoneNumber;
@property (nonatomic) BOOL autosaveToCameraRoll;
@property (nonatomic, retain) NSString *serverURL;
@property (nonatomic, retain) NSString *serverPort;

// dummy properties that are required to map the settings form
@property (readonly, nonatomic, retain) NSDictionary *helpInfo;
@property (readonly, nonatomic, retain) NSData *reportIssue;
@property (readonly, nonatomic, retain) NSData *sendFeedback;
@property (readonly, nonatomic, retain) NSString *terms;
@property (readonly, nonatomic, retain) NSString *privacyPolicy;
@property (readonly, nonatomic, retain) NSString *locationMap;
@property (nonatomic, retain) NSString *inviteUser;
@property (nonatomic, retain) NSString *clearImageCache;

@end
