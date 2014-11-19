//
//  DFPeanutPhoto.h
//  Duffy
//
//  Created by Henry Bridge on 5/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

@class RKObjectMapping;
@class DFPhoto;

@interface DFPeanutPhoto : NSObject <DFPeanutObject>

@property (nonatomic, retain) NSNumber *user; //unsigned long long
@property (nonatomic, retain) NSNumber *id; //unsigned long long
@property (nonatomic, retain) NSString *time_taken;
@property (nonatomic, retain) NSString *metadata;
@property (nonatomic, retain) NSString *iphone_hash;
@property (nonatomic, retain) NSURL *file_key;
@property (nonatomic, retain) NSString *thumb_filename;
@property (nonatomic, retain) NSString *full_filename;
@property (nonatomic, retain) NSNumber *full_width;
@property (nonatomic, retain) NSNumber *full_height;
@property (nonatomic, retain) NSString *iphone_faceboxes_topleft; //array of DFPeanutFaceFeatures
@property (nonatomic, retain) NSString *full_image_path;
@property (nonatomic, retain) NSString *thumbnail_image_path;
@property (nonatomic, retain) NSNumber *install_num;
@property (nonatomic, retain) NSNumber *saved_with_swap;

/* Not Sync'ed with server */
@property (readonly, nonatomic, retain) NSString *filename;
- (NSDictionary *)metadataDictionary;

+ (RKObjectMapping *)objectMapping;
- (id)initWithDFPhoto:(DFPhoto *)photo;
- (DFPhoto *)photoInContext:(NSManagedObjectContext *)context;

- (NSDictionary *)dictionary;
- (NSString *)JSONString;
- (NSUInteger)metadataSizeBytes;
- (NSString *)photoUploadJSONString;

- (void)setIPhoneFaceboxesWithDFPeanutFaceFeatures:(NSArray *)faceFeatures;

@end
