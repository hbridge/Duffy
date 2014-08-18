//
//  DFContactsStore.m
//  Strand
//
//  Created by Henry Bridge on 8/18/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFContactsStore.h"

@implementation DFContactsStore
@synthesize context = _context, model = _model, persistentStoreCoordinator = _persistentStoreCoordinator;


static DFContactsStore *defaultStore;

+ (DFContactsStore *)sharedStore {
  if (!defaultStore) {
    defaultStore = [[super allocWithZone:nil] init];
  }
  return defaultStore;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedStore];
}


- (id)init
{
  self = [super init];
  if (self) {
    
  }
  return self;
}


#pragma mark - Create and Find Contacts

- (DFContact *)createContactWithName:(NSString *)name phoneNumberString:(NSString *)phoneNumberString
{
  DFContact *contact = [NSEntityDescription
                       insertNewObjectForEntityForName:@"DFContact"
                       inManagedObjectContext:self.context];

  contact.name = name;
  contact.phoneNumber = phoneNumberString;
  contact.modifiedDate = [NSDate date];

  return contact;
}

- (NSArray *)allContacts
{
  return [self contactsWithPredicate:nil];
}

- (NSArray *)contactsModifiedAfterDate:(NSDate *)date
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"modifiedDate >= %@", date];
  return [self contactsWithPredicate:predicate];
}

- (DFContact *)contactWithPhoneNumberString:(NSString *)phoneNumberString
{
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [[self.model entitiesByName] objectForKey:@"DFContact"];
  request.entity = entity;
  request.fetchLimit = 1;

  request.predicate = [NSPredicate predicateWithFormat:@"phoneNumber == %@", phoneNumberString];
  NSError *error;
  NSArray *result = [self.context executeFetchRequest:request error:&error];
  if (error) {
    [NSException raise:@"Could not fetch contacts" format:@"Error: %@", error.description];
  }
  
  return result.firstObject;
}

- (NSArray *)contactsWithPredicate:(NSPredicate *)predicate
{
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [[self.model entitiesByName] objectForKey:@"DFContact"];
  request.entity = entity;
  
  NSSortDescriptor *nameSort = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
  request.sortDescriptors = [NSArray arrayWithObject:nameSort];
  
  request.predicate = predicate;
  
  NSError *error;
  NSArray *result = [self.context executeFetchRequest:request error:&error];
  if (!result) {
    [NSException raise:@"Could fetch photos"
                format:@"Error: %@", [error localizedDescription]];
  }
  
  return result;
}


#pragma mark - Core Data stack


- (NSManagedObjectContext *)context
{
  if (_context != nil) {
    return _context;
  }
  
  NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
  if (coordinator != nil) {
    _context = [[NSManagedObjectContext alloc] init];
    [_context setPersistentStoreCoordinator:coordinator];
    [_context setUndoManager:nil];
  }
  return _context;
}

- (NSManagedObjectModel *)model
{
  if (_model != nil) {
    return _model;
  }
  NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"DFContactsModel" withExtension:@"momd"];
  _model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
  return _model;
}
// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
  if (_persistentStoreCoordinator != nil) {
    return _persistentStoreCoordinator;
  }
  
  NSURL *storeURL = [[self.class applicationDocumentsDirectory]
                     URLByAppendingPathComponent:@"Contacts.sqlite"];
  
  NSError *error = nil;
  _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
                                 initWithManagedObjectModel:[self model]];
  if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                 configuration:nil
                                                           URL:storeURL
                                                       options:nil
                                                         error:&error]) {
    
    DDLogError(@"Error loading persistent store %@, %@", error, [error userInfo]);
    [self deleteStoreFiles:storeURL];
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                   configuration:nil
                                                             URL:storeURL
                                                         options:nil
                                                           error:&error]) {
      DDLogError(@"Still got error loading persistent store after deleting: %@, %@", error, error.userInfo);
      abort();
    }
  }
  
  return _persistentStoreCoordinator;
}

- (void)deleteStoreFiles:(NSURL *)storeURL
{
  NSError *error;
  [[NSFileManager defaultManager] removeItemAtURL:storeURL error:&error];
  
  DDLogWarn(@"Deleted persistent store %@, error: %@", storeURL, error);
  error = nil;
  NSURL *storeShm = [[storeURL URLByDeletingPathExtension]
                     URLByAppendingPathComponent:@"sqlite-shm"];
  [[NSFileManager defaultManager] removeItemAtURL:storeShm
                                            error:&error];
  DDLogWarn(@"Deleted store shm %@, error: %@", storeShm, error);
  error = nil;
  NSURL *storeWal = [[storeURL URLByDeletingPathExtension]
                     URLByAppendingPathComponent:@"sqlite-wal"];
  [[NSFileManager defaultManager] removeItemAtURL:storeWal
                                            error:&error];
  DDLogWarn(@"Deleted store wal %@, error: %@", storeWal, error);
}

- (void)saveContext
{
  NSError *error = nil;
  NSManagedObjectContext *managedObjectContext = self.context;
  if (managedObjectContext != nil) {
    if ([managedObjectContext hasChanges]){
      DDLogInfo(@"Contacts DB changes found, saving.");
      if(![managedObjectContext save:&error]) {
        DDLogError(@"Unresolved error while saving %@, %@", error, [error userInfo]);
        abort();
      }
    }
  }
}

+ (NSURL *)applicationDocumentsDirectory
{
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
