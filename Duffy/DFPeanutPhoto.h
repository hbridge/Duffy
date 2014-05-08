//
//  DFPeanutPhoto.h
//  Duffy
//
//  Created by Henry Bridge on 5/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RKObjectMapping;
@class DFPhoto;

@interface DFPeanutPhoto : NSObject

@property (nonatomic, retain) NSNumber *user; //unsigned long long
@property (nonatomic, retain) NSNumber *id; //unsigned long long
@property (nonatomic, retain) NSString *time_taken;
@property (nonatomic, retain) NSDictionary *metadata;
@property (nonatomic, retain) NSString *hash;
@property (nonatomic, retain) NSURL *file_key;
@property (nonatomic, retain) NSString *thumb_filename;
@property (nonatomic, retain) NSString *full_filename;
@property (nonatomic, retain) NSSet *iphone_faceboxes_topleft; //array of DFPeanutFaceFeatures

/* Not Sync'ed with server */
@property (readonly, nonatomic, retain) NSString *filename;

+ (RKObjectMapping *)objectMapping;
- (id)initWithDFPhoto:(DFPhoto *)photo;
- (DFPhoto *)photoInContext:(NSManagedObjectContext *)context;

- (NSDictionary *)dictionary;
- (NSString *)JSONString;
- (NSUInteger)metadataSizeBytes;
- (NSString *)photoUploadJSONString;

@end
