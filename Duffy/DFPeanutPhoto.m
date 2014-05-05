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
        @autoreleasepool {
            self.user = [NSNumber numberWithUnsignedLongLong:photo.userID];
            self.id = [NSNumber numberWithUnsignedLongLong:photo.photoID];
            NSDateFormatter *djangoFormatter = [NSDateFormatter DjangoDateFormatter];
            self.time_taken = [djangoFormatter stringFromDate:photo.creationDate];
            self.metadata = photo.metadataDictionary;
            self.hash = photo.creationHashString;
            self.file_key = photo.objectID.URIRepresentation;
        }
    }
    return self;
}


+ (NSArray *)attributes
{
    return @[@"user", @"id", @"time_taken", @"metadata", @"hash", @"file_key", @"thumb_filename", @"full_filename"];
}

- (NSDictionary *)dictionaryForAttributes:(NSArray *)attributes
{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    for (NSString *key in attributes) {
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

- (NSDictionary *)dictionary
{
    return [self dictionaryForAttributes:[DFPeanutPhoto attributes]];
}

- (NSString *)JSONString
{
    NSDictionary *JSONSafeDict = [[self dictionary] dictionaryWithNonJSONRemoved];
    return [JSONSafeDict JSONString];
}


- (NSString *)photoUploadJSONString
{
    NSDictionary *JSONSafeDict = [[self dictionaryForAttributes:@[@"id", @"user", @"hash", @"file_key"]] dictionaryWithNonJSONRemoved];
    return [JSONSafeDict JSONString];
}

+ (RKObjectMapping *)objectMapping
{
    RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[DFPeanutPhoto class]];
    [objectMapping addAttributeMappingsFromArray:[DFPeanutPhoto attributes]];
    return objectMapping;
}

- (NSString *)filename
{
    return [NSString stringWithFormat:@"%@.jpg", self.hash];
}

- (DFPhoto *)photoInContext:(NSManagedObjectContext *)context
{
    NSManagedObjectID *objectID = [context.persistentStoreCoordinator
                                   managedObjectIDForURIRepresentation:self.file_key];
    return (DFPhoto *)[context objectWithID:objectID];
}


- (NSString *)description
{
    return [NSString stringWithFormat:@"DFPeanutPhoto: {user:%d, id:%d, time_taken:%@, hash:%@, file_key:%@, metadata:%@, thumb_filename:%@ full_filename:%@}",
            (int)self.user, (int)self.id, self.time_taken, self.hash, self.file_key.absoluteString, self.metadata.description, self.thumb_filename, self.full_filename];
}

@end
