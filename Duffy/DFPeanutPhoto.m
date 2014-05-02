//
//  DFPeanutPhoto.m
//  Duffy
//
//  Created by Henry Bridge on 5/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutPhoto.h"
#import "DFPhoto.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "NSDictionary+DFJSON.h"
#import <RestKit/RestKit.h>

@implementation DFPeanutPhoto

NSString const *DFPeanutPhotoImageDimensionsKey = @"DFPeanutPhotoImageDimensionsKey";
NSString const *DFPeanutPhotoImageBytesKey = @"DFPeanutPhotoImageBytesKey";

- (id)initWithDFPhoto:(DFPhoto *)photo
{
    self = [super init];
    if (self) {
        self.user = [NSNumber numberWithUnsignedLongLong:photo.userID];
        self.id = [NSNumber numberWithUnsignedLongLong:photo.photoID];
        NSDateFormatter *djangoFormatter = [NSDateFormatter DjangoDateFormatter];
        self.time_taken = [djangoFormatter stringFromDate:photo.creationDate];
        self.metadata = photo.metadataDictionary;
        self.hash = photo.creationHashString;
        self.key = photo.objectID.URIRepresentation;
    }
    return self;
}


+ (NSArray *)attributes
{
    return @[@"user", @"id", @"time_taken", @"metadata", @"hash", @"key"];
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    for (NSString *key in [DFPeanutPhoto attributes]) {
        id value = [self valueForKey:key];
        if (value) {
            if ([[value class] isSubclassOfClass:[NSURL class]]) {
                result[key] = [(NSURL *)value absoluteString];
            } else {
                result[key] = [self valueForKey:key];
            }
        }
    }
    return result;
}

+ (RKObjectMapping *)objectMapping
{
    RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[DFPeanutPhoto class]];
    [objectMapping addAttributeMappingsFromArray:[DFPeanutPhoto attributes]];
    return objectMapping;
}


- (NSString *)description
{
    return [NSString stringWithFormat:@"DFPeanutPhoto: {user:%d, id:%d, time_taken:%@, hash:%@, key:%@, metadata:%@, }",
            (int)self.user, (int)self.id, self.time_taken, self.hash, self.key.absoluteString, self.metadata.description];
}

@end
