//
//  NSDictionary+DFJSON.m
//  Duffy
//
//  Created by Henry Bridge on 3/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "NSDictionary+DFJSON.h"

@implementation NSDictionary (DFJSON)

- (NSString *)JSONString
{
    
    if (![NSJSONSerialization isValidJSONObject:self]) {
        NSLog(@"Warning: json invalid for dict, enumerating types and removing unsafe types.");
        [self enumerateObjectTypes:@""];
        return [[self dictionaryWithNonJSONRemoved] JSONString];
    }
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self
                                                       options:0
                                                         error:&error];
    
    if (! jsonData) {
        NSLog(@"NSDictionary+DFJSON error: %@", error.localizedDescription);
        return @"{}";
    } else {
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
}


- (void)enumerateObjectTypes:(NSString *)path
{
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSLog(@"key: %@.%@, class %@", path, key, [key class]);
        NSLog(@"value: %@, class %@", obj, [obj class]);
        
        if ([[obj class] isSubclassOfClass:[NSDictionary class]]) {
            NSString *newPath = [NSString stringWithFormat:@"%@.%@", path, (NSString *)key];
            [(NSDictionary*)obj enumerateObjectTypes:newPath];
        }
    }];
}

+ (BOOL)isJSONSafeKey:(id)key
{
    return [[key class] isSubclassOfClass:[NSString class]];
}

+ (BOOL)isJSONSafeValue:(id)value
{
    // NSString, NSNumber, NSArray, NSDictionary, or NSNull.
    return (
        [[value class] isSubclassOfClass:[NSString class]] ||
            [[value class] isSubclassOfClass:[NSNumber class]] ||
            [[value class] isSubclassOfClass:[NSArray class]] ||
            [[value class] isSubclassOfClass:[NSDictionary class]] ||
            [[value class] isSubclassOfClass:[NSNull class]]
    );
}

- (NSDictionary *)dictionaryWithNonJSONRemoved
{
    NSMutableDictionary *mutableCopy = [self mutableCopy];
    NSMutableArray *keysToRemove = [[NSMutableArray alloc] init];
    [mutableCopy enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (![NSDictionary isJSONSafeKey:key] || ![NSDictionary isJSONSafeValue:obj]) {
            [keysToRemove addObject:key];
        }
        
        if ([[obj class] isSubclassOfClass:[NSDictionary class]]) {
            mutableCopy[key] = [(NSDictionary*)obj dictionaryWithNonJSONRemoved];
        }
    }];
    
    [mutableCopy removeObjectsForKeys:keysToRemove];
    
    return mutableCopy;
}

@end
