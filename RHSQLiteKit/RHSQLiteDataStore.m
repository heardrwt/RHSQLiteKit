//
//  RHSQLiteDataStore.m
//  RHSQLiteKit
//
//  Created by Richard Heard on 12/07/13.
//  Copyright (c) 2013 Richard Heard. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//  1. Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//  notice, this list of conditions and the following disclaimer in the
//  documentation and/or other materials provided with the distribution.
//  3. The name of the author may not be used to endorse or promote products
//  derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "RHSQLiteDataStore.h"
#import "RHSQLiteDataStore_Private.h"
#import "RHSQLiteObject.h"
#import "RHSQLiteDynamicObjectParent.h"
#import "RHSQLiteObjectPlaceholder.h"
#import "RHSQLiteObjectQuery.h"
#import "RHWeakValue.h"

#import "FMDatabaseQueue.h"
#import "FMResultSet.h"

#import "NSArray+RHNumberAdditions.h"
#import "NSString+RHCaseAdditions.h"
#import "NSString+RHNumberAdditions.h"

#define RHSQLiteDataStoreMetadataTableName @"metadata"

#define REQUIRE_LOADED() do {if (!_loaded)[NSException raise:NSInvalidArgumentException format:@"Error: %@ can only be called after the data store is loaded.", NSStringFromSelector(_cmd)]; } while (0)
#define REQUIRE_NOT_LOADED() do {if (_loaded)[NSException raise:NSInvalidArgumentException format:@"Error: %@ must be called before the data store is loaded.", NSStringFromSelector(_cmd)]; } while (0)

#define ENSURE_KNOWN_TABLE(table) do {if (![_knownTableNames containsObject:table])[NSException raise:NSInvalidArgumentException format:@"Error: %@ is not a known table name.", table]; } while (0)
#define ENSURE_NOT_INVALID_ID(objectID) do {if (objectID == RHSQLiteObjectIDInvalid)[NSException raise:NSInvalidArgumentException format:@"Error: Unable to load an object with an Invalid ID."]; } while (0)


@interface RHSQLiteDataStore ()

@property (nonatomic, copy) NSString *path;
@property (nonatomic, retain) FMDatabaseQueue *databaseQueue;

//private stuff
-(void)_populateKnownTableNames;
-(void)_loadDefaultTableClassAssociations;
+(NSString*)_defaultClassNameForTable:(NSString*)tableName;

//migrations
-(NSUInteger)_currentSchemaVersion;
-(NSUInteger)_maxSchemaVersion;
-(BOOL)_performRequiredMigrations;
-(BOOL)_performMigrationToSchemaVersion:(NSUInteger)version;

//cached
-(void)_invalidateCachedColumnNamesForTable:(NSString*)tableName;

//metadata
-(BOOL)_metadataTableExists;
-(BOOL)_metadataCreateTable;
-(BOOL)_metadataColumnExists:(NSString*)columnName;
-(BOOL)_metadataCreateColumn:(NSString*)columnName forStorageOfValue:(id)value;

@end

@implementation RHSQLiteDataStore
@synthesize path=_path;
@synthesize databaseQueue=_databaseQueue;


#pragma mark - init
-(id)initWithPath:(NSString*)path{
    self = [super init];
    if (self){
        _path = [path copy];
        _databaseQueue = [[FMDatabaseQueue alloc] initWithPath:_path];
        
        if (!_databaseQueue){
            RHErrorLog(@"Error: Failed to open database with path %@.", _path);
            self = nil;
            return nil;
        }
        
        //setup our structures
        _knownTableNames = [[NSMutableArray alloc] init];
        _associatedClassNamesByTableName = [[NSMutableDictionary alloc] init];
        _registeredMigrationPaths = [[NSMutableArray alloc] init];
        _perTableWeakObjectCaches = [[NSMutableDictionary alloc] init];
        _cachedTableColumnNames = [[NSMutableDictionary alloc] init];
        //some defaults
        _loaded = NO;
        
    }
    return self;
}

-(void)dealloc{
    _path = nil;
    [_databaseQueue close];
    _databaseQueue = nil;
}


#pragma mark - load the data store
-(BOOL)loadAndPerformAnyRequiredMigrations{
    //first, perform any required migrations
    if (![self _performRequiredMigrations]){
        RHErrorLog(@"Error: Migration reported an error.");
        return NO;
    }
    
    //populate our known table names
    [self _populateKnownTableNames];
    
    //now we dynamically generate classes for any tables that have no specifically associated SQLiteObject subclasses
    [self _loadDefaultTableClassAssociations];
    
    //check for and log any associated table classes that dont have an actual table
    for (NSString *tableName in _associatedClassNamesByTableName.allKeys) {
        if (![_knownTableNames containsObject:tableName]){
            RHErrorLog(@"Warning: We were unable to find an actual sql table for the associated RHSQLiteObject subclass '%@'.", [_associatedClassNamesByTableName objectForKey:tableName]);
        }
    }
    
    //finally set our loaded flag
    _loaded = YES;

    RHLog(@"%@", self);
    //success
    return YES;
}


#pragma mark - access db
-(void)accessDatabase:(void (^)(FMDatabase *db))block{
    [_databaseQueue inDatabase:^(FMDatabase *db) {
        block(db);
        if ([db hadError]){
            //log db errors
            NSError *newError = [db lastError];
            RHErrorLog(@"Error: %@", newError);
        }
    }];
}

-(void)accessDatabaseWithTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block{
    [_databaseQueue inTransaction:block];
}

-(void)accessDatabaseWithDeferredTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block{
    [_databaseQueue inDeferredTransaction:block];
}


#pragma mark - generic lookup methods
-(NSArray*)tableNames{
    REQUIRE_LOADED();
    return [NSArray arrayWithArray:_knownTableNames];
}

-(void)_populateKnownTableNames{
    [_knownTableNames removeAllObjects];
    [self accessDatabase:^(FMDatabase *db) {
        NSString *sql = @"SELECT `name` FROM `sqlite_master` WHERE `type` = 'table' AND `name` NOT LIKE 'sqlite_%';";
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            NSString *name = [resultSet stringForColumn:@"name"];
            //TODO: skip list
            RHLog(@"Found table name: %@.", name);
            [_knownTableNames addObject:name];
        }
        [resultSet close];
    }];
    
}

-(int64_t)numberOfObjectsInTable:(NSString*)tableName{
    REQUIRE_LOADED(); ENSURE_KNOWN_TABLE(tableName);
    __block int64_t result = 0;
    [self accessDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"SELECT count(*) as `count` FROM `%@`;", tableName];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]){
            result = [resultSet unsignedLongLongIntForColumn:@"count"];
        }
        [resultSet close];
    }];
    return result;
}

-(RHSQLiteObject*)objectFromTable:(NSString*)tableName withID:(RHSQLiteObjectID)objectID{
    REQUIRE_LOADED(); ENSURE_KNOWN_TABLE(tableName); ENSURE_NOT_INVALID_ID(objectID);
    
    //check our cache first
    RHSQLiteObject *result = [self _cachedObjectForTable:tableName objectID:objectID];
    if (! result){
        result = [[[self objectClassForTable:tableName] alloc] initWithDataStore:self objectID:objectID];
    }
    return result;
}

-(NSArray*)objectsFromTable:(NSString*)tableName withIDs:(NSArray*)objectIDs{
    NSMutableArray* result = [NSMutableArray array];
    for (NSNumber *objectID in objectIDs) {
        RHSQLiteObject *object = [self objectFromTable:tableName withID:[objectID unsignedLongLongValue]];
        if (object){
            [result addObject:object];
        }
    }
    return [NSArray arrayWithArray:result];
}

-(NSArray*)objectsMatchingQuery:(RHSQLiteObjectQuery*)query{
    NSString *tableName = [query.objectClass tableName];
    REQUIRE_LOADED(); ENSURE_KNOWN_TABLE(tableName);
    return [self objectsFromTable:tableName withIDs:[self objectIDsMatchingQuery:query]];
}

-(NSArray*)objectsFromTable:(NSString*)tableName where:(NSString*)where orderedBy:(NSString*)columnName ascending:(BOOL)ascending{
    REQUIRE_LOADED(); ENSURE_KNOWN_TABLE(tableName);
    return [self objectsFromTable:tableName withIDs:[self objectIDsFromTable:tableName where:where orderedBy:columnName ascending:ascending]];
}

-(NSArray*)objectIDsMatchingQuery:(RHSQLiteObjectQuery*)query{
    NSString *tableName = [query.objectClass tableName];
    NSString *primaryKeyName = [query.objectClass primaryKeyName];
    REQUIRE_LOADED(); ENSURE_KNOWN_TABLE(tableName);
    NSMutableArray *objectIDs = [NSMutableArray array];
    [self accessDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:query.sql];
        while ([resultSet next]) {
            NSNumber *objectID = [NSNumber numberWithUnsignedLongLong:[resultSet unsignedLongLongIntForColumn:primaryKeyName]];
            [objectIDs addObject:objectID];
        }
        [resultSet close];
    }];
    
    return [NSArray arrayWithArray:objectIDs];
}

-(NSArray*)objectIDsFromTable:(NSString*)tableName where:(NSString*)where orderedBy:(NSString*)columnName ascending:(BOOL)ascending{
    REQUIRE_LOADED(); ENSURE_KNOWN_TABLE(tableName);
    RHSQLiteObjectQuery *query = [RHSQLiteObjectQuery queryForObjectClass:[self objectClassForTable:tableName] where:where orderedBy:columnName ascending:ascending];
    return [self objectIDsMatchingQuery:query];
}


#pragma mark - textual search
-(NSArray*)objectsFromTable:(NSString*)tableName containingString:(NSString*)string inColumn:(NSString*)columnName{
    REQUIRE_LOADED(); ENSURE_KNOWN_TABLE(tableName);
    NSString *primaryKeyName = [[self objectClassForTable:tableName] primaryKeyName];
    NSString *where = [NSString stringWithFormat:@"`%@` LIKE '%%%@%%'", tableName, string];
    return [self objectsFromTable:tableName where:where orderedBy:primaryKeyName ascending:YES];
}


#pragma mark - creation
-(RHSQLiteObject*)newObjectInTable:(NSString*)tableName{
    REQUIRE_LOADED(); ENSURE_KNOWN_TABLE(tableName);
    return [[[self objectClassForTable:tableName] alloc] initWithDataStore:self];
}


#pragma mark - insertion
-(RHSQLiteObjectID)insertObject:(RHSQLiteObject*)object{
    [object associateWithDataStore:self];
    [object save];
    return object.objectID;
}

-(NSArray*)insertObjects:(NSArray*)objects{
    NSMutableArray *objectIDs = [NSMutableArray array];
    for (RHSQLiteObject *object in objects) {
        RHSQLiteObjectID objectID = [self insertObject:object];
        [objectIDs sk_addLongLong:objectID];
    }
    
    return [NSArray arrayWithArray:objectIDs];
}


#pragma mark - deletion
-(BOOL)deleteObject:(RHSQLiteObject*)object{
    return [object delete];
}

-(NSArray*)deleteObjects:(NSArray*)objects{
    NSMutableArray *results = [NSMutableArray array];
    for (RHSQLiteObject *object in objects) {
        BOOL result = [self insertObject:object];
        [results sk_addBool:result];
    }
    
    return [NSArray arrayWithArray:results];
}


#pragma mark - table name to class associations
-(NSArray*)objectClassNames{
    return [NSArray arrayWithArray:[_associatedClassNamesByTableName allValues]];
}

-(void)_loadDefaultTableClassAssociations{
    //if a custom class has already been registered for a given table name, this process continues to use that class.
    for (NSString *rawTableName in _knownTableNames) {
        [self objectClassForTable:rawTableName];
    }
}

-(void)associateObjectClass:(Class)objectClass{
    REQUIRE_NOT_LOADED();
    
    if(![objectClass isSubclassOfClass:[RHSQLiteObject class]]){
        [NSException raise:NSInvalidArgumentException format:@"-[RHSQLiteDataStore associateObjectClass:] must be a subclass of RHSQLiteObject."];
        return;
    }

    NSString *className = NSStringFromClass(objectClass);
    NSString *tableName = [NSClassFromString(className) tableName];
    
    //add to the associations dictionary
    [_associatedClassNamesByTableName setObject:className forKey:tableName];
}

-(Class)objectClassForTable:(NSString*)tableName{
    NSString *tableClassName = [_associatedClassNamesByTableName objectForKey:tableName];
    Class tableClass = NSClassFromString(tableClassName);
    
    if (!tableClassName && [_knownTableNames containsObject:tableName]){
        //load a new one and associate it
        NSString *newClassName = [self.class _defaultClassNameForTable:tableName];
        tableClass = RHSQLiteDynamicObjectParentCreateNewSubclassWithNameAndTableName(newClassName, tableName);
        
        if (tableClass) [self associateObjectClass:tableClass];
    }
        
    if (!tableClass){
        RHErrorLog(@"Error: unable to get class for unknown table '%@'.", tableName);
        return nil;
    }
        
    return tableClass;
}


+(NSString*)_defaultClassNameForTable:(NSString*)tableName{
    return [NSString stringWithFormat:@"RHSQLite%@", [[tableName sk_camelcaseString] sk_uppercaseFirstString]];
}


#pragma mark - migrations
-(void)registerMigrationsFile:(NSString*)migrationPath{
    REQUIRE_NOT_LOADED();
    [_registeredMigrationPaths addObject:migrationPath];
}

-(BOOL)migrationsEnabled{
    return _registeredMigrationPaths.count > 0;
}

-(BOOL)requiresMigration{
    return [self _currentSchemaVersion] < [self _maxSchemaVersion];
}

#pragma mark - internal migrations support
-(NSUInteger)_currentSchemaVersion{
    return [[self _metadataValueForKey:@"schema_version"] unsignedIntegerValue];
}

-(NSUInteger)_maxSchemaVersion{
    return _registeredMigrationPaths.count;
}


-(BOOL)_performRequiredMigrations{
    while ([self requiresMigration]){
        //perform migration
        BOOL result = NO;
        NSUInteger nextRequiredMigration = [self _currentSchemaVersion] + 1;
        result = [self _performMigrationToSchemaVersion:nextRequiredMigration];

        //bail if we failed our current migration
        if (!result){
            RHErrorLog(@"Error: failed to perform migration from schema %lu to %lu.", (unsigned long)[self _currentSchemaVersion], (unsigned long)nextRequiredMigration);
            return NO;
        }
        //bump our schema version
        [self _metadataSetValue:[NSNumber numberWithUnsignedInteger:nextRequiredMigration] forKey:@"schema_version"];
    }

    return YES;
}

-(BOOL)_performMigrationToSchemaVersion:(NSUInteger)version{
    if (version > _registeredMigrationPaths.count){
        [NSException raise:NSInvalidArgumentException format:@"Error: Failed to perform schema migration. Unknown schema version %lu.", (unsigned long)version];
        return NO;
    }
    
    //this is a hack, but rmdb does not currently support running commands from files directly.
    NSString *schemaPath = [_registeredMigrationPaths objectAtIndex:version - 1];
    NSString *sql = [[NSString alloc] initWithContentsOfFile:schemaPath encoding:NSUTF8StringEncoding error:nil];
    if (!sql){
        RHErrorLog(@"Error: Failed to perform Migration %lu. Unable to find file with path '%@'.", (unsigned long)version, schemaPath);
        return NO;
    }
    
    RHLog(@"Performing schema migration (%lu)->(%lu) for db %@.", (unsigned long)[self _currentSchemaVersion], (unsigned long)version, _path);
    
    __block BOOL result = YES;
    [_databaseQueue inDatabase:^(FMDatabase *db) {
        //run each query individually.
        NSArray *queries = [sql componentsSeparatedByString:@";"];
        
        for(NSString *query in queries){
            NSString *stripped = [[query sk_stringByDeletingComments] sk_stringByTrimmingWhitespaceAndNewlineCharacters];
            
            if ([stripped length] > 0){
                if(![db executeUpdate:query]){
                    RHErrorLog(@"Error: Failed to perform part of migration:%ld. Failing query: {\n%@\n}.", (unsigned long)version, stripped);
                    result = NO;
                    break;
                }
            }
        }
        
    }];
    
    //return our result
    return result;
}


#pragma mark - generic db type info
-(NSArray*)columnNamesForTable:(NSString*)tableName{
    NSArray* columnNames = [_cachedTableColumnNames objectForKey:tableName];
    if (columnNames) return columnNames;
    
    NSMutableArray *mutableResults = [NSMutableArray array];
    [self accessDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info(`%@`)", tableName];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            NSString *name = [resultSet stringForColumn:@"name"];
            if (name) [mutableResults addObject:name];
        }
        [resultSet close];
    }];
    
    NSArray *results = [NSArray arrayWithArray:mutableResults];
    [_cachedTableColumnNames setObject:results forKey:tableName];
    return results;
}

-(void)_invalidateCachedColumnNamesForTable:(NSString*)tableName{
    [_cachedTableColumnNames removeObjectForKey:tableName];
}

-(NSString*)columnTypeForTable:(NSString*)tableName andColumn:(NSString*)columnName{
    __block NSString *result = nil;
    [self accessDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info(`%@`)", tableName];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            NSString *name = [resultSet stringForColumn:@"name"];
            if ([name isEqualToString:columnName]) result = [resultSet stringForColumn:@"type"];
        }
        [resultSet close];
    }];
    return result;
}

-(NSString*)requiredColumnTypeForObject:(id)object{
    if ([object isKindOfClass:[NSNumber class]]){
        if(strcmp([object objCType], @encode(double)) == 0 || strcmp([object objCType], @encode(float)) == 0) {
            return @"REAL";
        }
        return @"INTEGER";
    }
    
    if ([object isKindOfClass:[NSString class]] || [object isKindOfClass:[NSDate class]]){
        return @"TEXT";
    }
    
    //assume blob
    return @"BLOB";

}


#pragma mark - metadata
-(BOOL)_metadataTableExists{
    __block BOOL result = NO;
    [self accessDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"SELECT count(name) as `count` FROM `sqlite_master` WHERE `type` = 'table' AND `name` = '%@';", RHSQLiteDataStoreMetadataTableName];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]){
            result = [resultSet longForColumn:@"count"] > 0;
        }
        [resultSet close];
    }];
    return result;
}

-(BOOL)_metadataCreateTable{
    if ([self _metadataTableExists]) return YES;
    __block BOOL result = NO;
    [self accessDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE '%@' ( 'id' INTEGER PRIMARY KEY ON CONFLICT REPLACE AUTOINCREMENT);", RHSQLiteDataStoreMetadataTableName];
        result = [db executeUpdate:sql];
        if (result) result = [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO `%@` VALUES(1);", RHSQLiteDataStoreMetadataTableName]];
    }];
    RHLog(@"Creating metadata table. Result:%i.", result);
    return result;
}

-(BOOL)_metadataColumnExists:(NSString*)columnName{
    return [[self columnNamesForTable:RHSQLiteDataStoreMetadataTableName] containsObject:columnName];
}

-(BOOL)_metadataCreateColumn:(NSString*)columnName forStorageOfValue:(id)value{
    if ([self _metadataColumnExists:columnName]) return YES;
    __block BOOL result = NO;
    [self accessDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"ALTER TABLE `%@` ADD COLUMN '%@' %@;", RHSQLiteDataStoreMetadataTableName, columnName, [self requiredColumnTypeForObject:value]];
        result = [db executeUpdate:sql];
    }];
    RHLog(@"Creating metadata column %@. Result:%i.", columnName, result);
    [self _invalidateCachedColumnNamesForTable:RHSQLiteDataStoreMetadataTableName];
    return result;
}

-(id)_metadataValueForKey:(NSString*)columnName{
    if (![self _metadataColumnExists:columnName]) return nil;
    __block id result = nil;
    [self accessDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"SELECT `%@` FROM `%@` WHERE `id` = 1;", columnName, RHSQLiteDataStoreMetadataTableName];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            result = [resultSet objectForColumnName:columnName];
        }
        [resultSet close];
    }];
    return result;
}

-(void)_metadataSetValue:(id)object forKey:(NSString*)columnName{
    if (![self _metadataTableExists]) [self _metadataCreateTable];
    if (![self _metadataColumnExists:columnName]) [self _metadataCreateColumn:columnName forStorageOfValue:object];
    __block BOOL result = NO;
    [self accessDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"UPDATE `%@` SET `%@` = ? where `id` = 1;", RHSQLiteDataStoreMetadataTableName, columnName];
        result = [db executeUpdate:sql, object];
    }];
    RHLog(@"Setting metadata column %@ to value %@. Result:%i.", columnName, object, result);
    
}



#pragma mark - object cache management
-(NSMutableDictionary*)_weakObjectCacheForTable:(NSString*)tableName{
    REQUIRE_LOADED(); ENSURE_KNOWN_TABLE(tableName);

    //TODO: MAKE THREAD SAFE
    NSMutableDictionary *cache = [_perTableWeakObjectCaches objectForKey:tableName];
    
    if (!cache){
        NSMutableDictionary *newCache = [NSMutableDictionary dictionary];
        if (newCache){
            cache = newCache;
            [_perTableWeakObjectCaches setObject:newCache forKey:tableName];
        }
    }
    
    return cache;
}

-(RHSQLiteObject*)_cachedObjectForTable:(NSString*)tableName objectID:(RHSQLiteObjectID)objectID{
    REQUIRE_LOADED(); ENSURE_KNOWN_TABLE(tableName);
    if (objectID == RHSQLiteObjectIDInvalid) return nil;
    if (objectID == RHSQLiteObjectIDNotYetAvailable) return nil;
    
    NSMutableDictionary *cache = [self _weakObjectCacheForTable:tableName];
    RHWeakValue *value = [cache objectForKey:[NSNumber numberWithLongLong:objectID]];
    RHSQLiteObject *sqLiteObject = [value weakValue];
    if (sqLiteObject.objectID != objectID) return nil;
    
    return sqLiteObject;
}


#pragma mark - object cache access

//used to implement the weak linking cache
-(void)_objectCheckIn:(RHSQLiteObject*)object{
    if (!object) return;
    //RHLog(@"Checking in object: <%@: %p> with ID %llu", NSStringFromClass(object.class), object, object.objectID);

    RHSQLiteObject *strongObject = object; //keep it around for a while
    
    //TODO: this is not currently thread safe. likely a good idea to make this thread safe at some point
    
    if (strongObject.objectID != RHSQLiteObjectIDInvalid && strongObject.objectID != RHSQLiteObjectIDNotYetAvailable){
        NSString *table = [strongObject tableName];
        NSMutableDictionary *cache = [self _weakObjectCacheForTable:table];
        [cache setObject:[RHWeakValue weakValueWithObject:strongObject] forKey:[NSNumber numberWithLongLong:strongObject.objectID]];
    }
}

-(void)_objectCheckOut:(RHSQLiteObject*)object{
    //called from inside RHSQLiteObject's dealloc method, so not safe to use any instance variables implemented above RHSQLiteObject.
    if (!object) return;
    
    //RHLog(@"Checking out object: <%@: %p> with ID %llu", NSStringFromClass(object.class), object, object.objectID);

    __unsafe_unretained __block RHSQLiteObject *safeObject = object;
    
    NSString *table = [safeObject tableName];
    NSMutableDictionary *cache = [self _weakObjectCacheForTable:table];
    [cache removeObjectForKey:[NSNumber numberWithLongLong:safeObject.objectID]];
    
}


#pragma mark - NSKeyedArchiverDelegate
- (id)archiver:(NSKeyedArchiver *)archiver willEncodeObject:(id)object{
    //sets the dataStore on the objects being encoded and then calls save.
    if ([object isKindOfClass:[RHSQLiteObject class]]){
        [object associateWithDataStore:self];
        [object save];
        return [RHSQLiteObjectPlaceholder placeholderWithObject:object];
    }
    
    return object;
}


#pragma mark - NSKeyedUnarchiverDelegate
- (id)unarchiver:(NSKeyedUnarchiver *)unarchiver didDecodeObject:(id)object {
    if ([object isKindOfClass:[RHSQLiteObjectPlaceholder class]]){
        //discard the placeholder object, instead pulling its corresponding object from our data stores cache, via way of the placeholder
        return [(RHSQLiteObjectPlaceholder*)object representedObjectInDataStore:self];
    }
    return  object;
}


#pragma mark - description
-(NSString*)description{
    return [NSString stringWithFormat:@"<%@: %p, path: %@, loaded: %i, tables: %@>", NSStringFromClass([self class]), self, _path, _loaded, _associatedClassNamesByTableName];
}


@end
