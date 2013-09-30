//
//  RHSQLiteObject.m
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

#import "RHSQLiteKit.h"

#import "RHSQLiteObject.h"
#import "RHSQLiteDataStore.h"
#import "RHSQLiteDataStore_Private.h"

#import "FMDatabaseQueue.h"
#import "FMResultSet.h"

#import "NSArray+RHNumberAdditions.h"
#import "NSString+RHCaseAdditions.h"
#import "NSString+RHNumberAdditions.h"

#define DATA_STORE_REQUIRED() do {if (!_dataStore)[NSException raise:NSInvalidArgumentException format:@"Error: dataStore is required by %@.", NSStringFromSelector(_cmd)]; } while (0)
#define CLASS_OR_NIL(object, kind) ( kind *)([object isKindOfClass:[kind class]] ? object : nil)
#define REQUIRE_SUBCLASS_IMPLEMENTATION() do { [NSException raise:NSInternalInconsistencyException format:@"Error: You must implement %@ in your subclass.", NSStringFromSelector(_cmd)];} while (0)


@interface RHSQLiteObject ()
//private
-(BOOL)_processLoadResultsDictionary:(NSDictionary*)dictionary;

//handle the encoding of non storable database types aka colors and urls etc by using NSKeyedArchiver
//passes through NSData NSString NSNumber NSNull
extern id RHSQLiteObjectValueEncode(RHSQLiteDataStore *dataStore, id objectToBeEncoded);
extern id RHSQLiteObjectValueDecode(RHSQLiteDataStore *dataStore, id objectToBeDecoded, Class expectedClass);


@end

@implementation RHSQLiteObject
@synthesize dataStore=_dataStore;

#pragma mark - init

+(id)objectFromDataStore:(RHSQLiteDataStore*)dataStore objectID:(RHSQLiteObjectID)objectID{
    if (!dataStore)[NSException raise:NSInvalidArgumentException format:@"Error: dataStore is required by %@.", NSStringFromSelector(_cmd)];
    //just pass through to the kindly provided data store
    return [dataStore objectFromTable:[self tableName] withID:objectID];
}

-(id)initWithDataStore:(RHSQLiteDataStore*)dataStore objectID:(RHSQLiteObjectID)objectID{
    if (objectID == RHSQLiteObjectIDInvalid){
        [NSException raise:NSInvalidArgumentException format:@"Error: Unable to initialize an SQLiteObject with an invalid objectID. objectID != RHSQLiteObjectIDInvalid"];
        return nil;
    }

    self = [super init];
    if (self){
        _dataStore = dataStore;
        _objectID = objectID;
        
        _loadedColumnsAndValues = [[NSMutableDictionary alloc] init];
        _unsavedChanges = [[NSMutableDictionary alloc] init];
        
        if (_dataStore && _objectID < RHSQLiteObjectIDNotYetAvailable)[_dataStore _objectCheckIn:self];
    }
    
    
    return self;
}

-(id)initWithDataStore:(RHSQLiteDataStore*)dataStore{
    return [self initWithDataStore:dataStore objectID:RHSQLiteObjectIDNotYetAvailable];
}

-(id)init{
    return [self initWithDataStore:nil objectID:RHSQLiteObjectIDNotYetAvailable];
}

-(void)dealloc{
    //check out
    if (_dataStore && _objectID < RHSQLiteObjectIDNotYetAvailable)[_dataStore _objectCheckOut:self];

    _dataStore = nil;

}


#pragma mark - data store
-(BOOL)associateWithDataStore:(RHSQLiteDataStore*)dataStore{
    if (_dataStore == dataStore || !_dataStore){
        _dataStore = dataStore;
        if (_dataStore && _objectID < RHSQLiteObjectIDNotYetAvailable)[_dataStore _objectCheckIn:self];
        return YES; //no change
    }

    [NSException raise:NSInvalidArgumentException format:@"Error: Failed to associate with the requested data store as this object is already associated with another data store."];
    return NO;
}


#pragma mark - table name
+(NSString*)tableName{
    REQUIRE_SUBCLASS_IMPLEMENTATION();
    return nil;
}

-(NSString*)tableName {
    return [self.class tableName];
}

#pragma mark - primary key name
+(NSString*)primaryKeyName{
    return @"_ROWID_";
}

-(NSString*)primaryKeyName{
    return [self.class primaryKeyName];
}


#pragma mark - object ID
-(RHSQLiteObjectID)objectID{
    return _objectID;
}

#pragma mark - loading
-(BOOL)needsLoading{
    return !_loaded;
}

-(BOOL)load{
    DATA_STORE_REQUIRED();
    if (_loaded) return YES;
    
    //invalid id
    if (_objectID == RHSQLiteObjectIDInvalid){
        RHErrorLog(@"Error: tried to load an invalid RHSQliteObject.");
        return NO;
    }
    
    //unsaved object, don't attempt to load
    if (_objectID == RHSQLiteObjectIDNotYetAvailable){
        RHLog(@"Load called on an unsaved RHSQliteObject. Ignoring.");
        return NO;
    }
    
    
    __block BOOL result = NO;
    [_dataStore accessDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:[self loadSQL]];
        if ([resultSet next]){
            result = [self _processLoadResultsDictionary:[resultSet resultDictionary]];
        } else {
            RHErrorLog(@"Error: Load failed with error: %@.", [db lastError]);
            result = [self _processLoadResultsDictionary:nil];
        }
        [resultSet close];
    } ];

    //set our loaded flag if we succeeded in loading
    _loaded = result;
    return result;
}

-(BOOL)reload{
    BOOL previouslyLoaded = _loaded;
    _loaded = NO;
    BOOL result = [self load];
    _loaded = previouslyLoaded;
    return result;
}

-(BOOL)_processLoadResultsDictionary:(NSDictionary*)dictionary{
    [_loadedColumnsAndValues removeAllObjects];
    if (!dictionary){
        RHErrorLog(@"Error: Failed to load RHSQliteObject with ID: %lli.", _objectID);
        _objectID = RHSQLiteObjectIDInvalid;
        return NO;
    }
    
    [_loadedColumnsAndValues addEntriesFromDictionary:dictionary];
    return YES;
}


#pragma mark - known column properties support
-(id)valueForUndefinedKey:(NSString *)key{
    NSString *columnName = [self columnNameForProperty:key];
    if (columnName) return [self objectForColumn:columnName];

    //if not known, return super
    return [super valueForUndefinedKey:key];
}

-(void)setValue:(id)value forUndefinedKey:(NSString *)key{
    NSString *columnName = [self columnNameForProperty:key];
    if (columnName){
        [self setObject:value forColumn:columnName];
    } else {
        //if not known, use supers implementation
        [super setValue:value forUndefinedKey:key];
    }
}


#pragma mark - RHDynamicPropertyObject methods
-(id)valueForDynamicProperty:(NSString*)propertyName{
    NSString *columnName = [self columnNameForProperty:propertyName];
    return [self objectForColumn:columnName];
}

-(void)setValue:(id)value forDynamicProperty:(NSString*)propertyName{
    NSString *columnName = [self columnNameForProperty:propertyName];
    [self setObject:value forColumn:columnName];
}


#pragma mark - object getters (KVO compliant) these return either NSDate, NSNumber, NSString, NSData, or NSNull
-(id)objectForColumn:(NSString*)columnName{
    if (![self hasColumn:columnName]){
        [NSException raise:NSInvalidArgumentException format:@"Error: Unable to get the value for unknown column: %@.", columnName];
        return nil;
    }

    //load
    if ([self needsLoading])[self load];
    
    //first check unsaved properties
    id result = RHSQLiteObjectValueDecode(_dataStore, [_unsavedChanges objectForKey:columnName], [self classForColumn:columnName]);
    if (result) return result;

    //now loaded values
    result = RHSQLiteObjectValueDecode(_dataStore, [_loadedColumnsAndValues objectForKey:columnName], [self classForColumn:columnName]);
    if (result) return result;
    
    //RHLog(@"Failed to find value for columnName %@", columnName);
    return nil;
}

-(id)objectForKeyedSubscript:(NSString *)columnName{
    return [self objectForColumn:columnName];
}
-(BOOL)columnHasNullValue:(NSString *)columnName{
    id value = [self objectForColumn:columnName];
    return value == nil || value == [NSNull null];
}

#pragma mark - object setters
-(void)setObject:(id)obj forColumn:(NSString*)columnName{
    if (![self hasColumn:columnName]){
        [NSException raise:NSInvalidArgumentException format:@"Error: Unable to set the value for unknown column: %@.", columnName];
        return;
    }

    //always save into unsaved changes
    if (!obj) obj = [NSNull null];
    [self willChangeValueForKey:[self propertyNameForColumn:columnName]];
    [_unsavedChanges setObject:RHSQLiteObjectValueEncode(_dataStore, obj) forKey:columnName];
    [self didChangeValueForKey:[self propertyNameForColumn:columnName]];
}

-(void)setObject:(id)obj forKeyedSubscript:(NSString*)columnName{
    [self setObject:obj forColumn:columnName];
}


//#pragma mark - specific classed object getters (these return nil if the fetched object is not of the specified class)
-(NSData*)dataForColumn:(NSString*)columnName{
    return CLASS_OR_NIL([self objectForColumn:columnName], NSData);
}

-(NSDate*)dateForColumn:(NSString*)columnName{
    id obj = [self objectForColumn:columnName];
    
    if ([obj respondsToSelector:@selector(doubleValue)]){
        obj = [NSDate dateWithTimeIntervalSince1970:[obj doubleValue]];
    }
    
    return CLASS_OR_NIL(obj, NSDate);
}

-(NSNumber*)numberForColumn:(NSString*)columnName{
    return CLASS_OR_NIL([self objectForColumn:columnName], NSNumber);
}

-(NSString*)stringForColumn:(NSString*)columnName{
    return CLASS_OR_NIL([self objectForColumn:columnName], NSString);
}

-(const char *)UTF8StringForColumn:(NSString*)columnName{
    return [CLASS_OR_NIL([self objectForColumn:columnName], NSString) UTF8String];
}


#pragma mark - primitive getters
-(BOOL)boolForColumn:(NSString*)columnName{
    return [[self numberForColumn:columnName] boolValue];
}

-(int)intForColumn:(NSString*)columnName{
    return [[self numberForColumn:columnName] intValue];
}

-(long)longForColumn:(NSString*)columnName{
    return [[self numberForColumn:columnName] longValue];
}

-(unsigned long)unsignedLongForColumn:(NSString*)columnName{
    return [[self numberForColumn:columnName] unsignedLongValue];
}

-(long long)longLongForColumn:(NSString*)columnName{
    return [[self numberForColumn:columnName] longLongValue];
}

-(unsigned long long)unsignedLongLongForColumn:(NSString*)columnName{
    return [[self numberForColumn:columnName] unsignedLongLongValue];
}

-(double)doubleForColumn:(NSString*)columnName{
    return [[self numberForColumn:columnName] doubleValue];
}

-(float)floatForColumn:(NSString*)columnName{
    return [[self numberForColumn:columnName] floatValue];
}

-(NSInteger)integerForColumn:(NSString*)columnName{
    return [[self numberForColumn:columnName] integerValue];
}

-(NSUInteger)unsignedIntegerForColumn:(NSString*)columnName{
    return [[self numberForColumn:columnName] unsignedIntegerValue];
}


#pragma mark - primitive setters
-(void)setBool:(BOOL)value forColumn:(NSString*)columnName{
    [self setObject:[NSNumber numberWithBool:value] forColumn:columnName];
}

-(void)setInt:(int)value forColumn:(NSString*)columnName{
    [self setObject:[NSNumber numberWithInt:value] forColumn:columnName];
}

-(void)setLong:(long)value forColumn:(NSString*)columnName{
    [self setObject:[NSNumber numberWithLong:value] forColumn:columnName];
}

-(void)setUnsignedLong:(unsigned long)value forColumn:(NSString*)columnName{
    [self setObject:[NSNumber numberWithUnsignedLong:value] forColumn:columnName];
}

-(void)setLongLong:(long long)value forColumn:(NSString*)columnName{
    [self setObject:[NSNumber numberWithLongLong:value] forColumn:columnName];
}

-(void)setUnsignedLongLong:(unsigned long long)value forColumn:(NSString*)columnName{
    [self setObject:[NSNumber numberWithUnsignedLongLong:value] forColumn:columnName];
}

-(void)setDouble:(double)value forColumn:(NSString*)columnName{
    [self setObject:[NSNumber numberWithDouble:value] forColumn:columnName];
}

-(void)setFloat:(float)value forColumn:(NSString*)columnName{
    [self setObject:[NSNumber numberWithFloat:value] forColumn:columnName];
}

-(void)setInteger:(NSInteger)value forColumn:(NSString*)columnName{
    [self setObject:[NSNumber numberWithInteger:value] forColumn:columnName];
}

-(void)setUnsignedInteger:(NSUInteger)value forColumn:(NSString*)columnName{
    [self setObject:[NSNumber numberWithUnsignedInteger:value] forColumn:columnName];
}


#pragma mark - columns
-(NSArray*)columnNames{
    DATA_STORE_REQUIRED();
    return [_dataStore columnNamesForTable:[self tableName]];
}

-(BOOL)hasColumn:(NSString*)columnName{
    if (!columnName) return NO;
    
    if (!_dataStore){
        //if we don't have a data store, we need to allow any column name to be added to _unsavedChanges etc. so we return true.
        return YES;
    }
    
    return [[self columnNames] containsObject:columnName];
}

-(NSString*)columnNameForProperty:(NSString*)propertyName{
    NSString *columnName = [propertyName sk_underscoreString];
    
    //special case our objectID - id conversion
    if ([columnName isEqualToString:@"object_i_d"]) columnName = @"id";
    
    //special cases for things that are usually all Caps
    columnName = [columnName stringByReplacingOccurrencesOfString:@"_i_d" withString:@"_id"];
    columnName = [columnName stringByReplacingOccurrencesOfString:@"_u_r_l" withString:@"_url"];
    
    if (![self hasColumn:columnName]){
        RHErrorLog(@"Warning: Unknown column name: %@ for property name: %@.", columnName, propertyName);
    }
    return columnName;
}
    
-(NSString*)propertyNameForColumn:(NSString*)columnName{
    if (![self hasColumn:columnName]){
        RHErrorLog(@"Warning: Asking for property name for unknown column name: %@.", columnName);
    }
     NSString *propertyName = [columnName sk_camelcaseString];
    
    //special case our objectID - id conversion
    if ([propertyName isEqualToString:@"id"]) propertyName = @"objectID";
    
    //special cases for things that are usually all caps
    propertyName = [propertyName hasSuffix:@"Id"] ? [propertyName stringByReplacingOccurrencesOfString:@"Id" withString:@"ID"] : propertyName;
    propertyName = [propertyName stringByReplacingOccurrencesOfString:@"Url" withString:@"URL"];
    
    return propertyName;
}

-(Class)classForColumn:(NSString*)columnName{
    //first try and look for any specific class type associated with this columns property
    NSString *propertyName = [self propertyNameForColumn:columnName];
    Class result = [[self class] classForProperty:propertyName];
    if (result) return result;
    
    //if that failed, use our current values class
    result = [[self objectForColumn:columnName] class];
    
    //if its NULL, fall through to the data store column type
    if ([result isKindOfClass:[NSNull class]]){
        result = NULL;
    }
    if (result) return result;
    
    //if that fails, we need to look at the table definition AKA INTEGER TEXT REAL BLOB (use the data store)
    DATA_STORE_REQUIRED();
    NSString *type = [_dataStore columnTypeForTable:[self tableName] andColumn:columnName];
    if ([type isEqualToString:@"TEXT"]) return [NSString class];
    if ([type isEqualToString:@"INTEGER"]) return [NSNumber class];
    if ([type isEqualToString:@"REAL"]) return [NSNumber class];
    if ([type isEqualToString:@"BLOB"]) return [NSData class];

    //unknown
    return NULL;
}

#pragma mark - saving
-(BOOL)hasUnsavedChanges{
    return [[_unsavedChanges allKeys] count] > 0;
}

-(BOOL)save{
    return [self saveWithError:nil];
}
-(BOOL)saveWithError:(NSError**)errorOut{
    DATA_STORE_REQUIRED();
    
    if (![self hasBeenCreated]){
        RHLog(@"Note: Object not yet created. Forwarding to createWithError:.");
        return [self createWithError:errorOut];
    }
        
    //if we have no changes. we are already saved...
    if (![self hasUnsavedChanges]) return YES;
    
    //TODO: When saving, make sure that only valid keys in _unsavedChanges are included in the save query.
    // Before a datastore is associated we allow stuff to be stored for any column name.

    __block BOOL result = NO;
    RHLog(@"Saving all unsaved changes.");
        
    //perform the save
    [_dataStore accessDatabase:^(FMDatabase *db) {

        NSArray *args = nil;
        NSString *sql = [self saveSQLWithArguments:&args];
        if (sql){
            result = [db executeUpdate:sql withArgumentsInArray:args];
            if (!result){
                RHErrorLog(@"Error: Save failed with error %@.", [db lastError]);
                if (errorOut) *errorOut = [db lastError];
            }
        }

    }];
    
    //clear out unsaved changes if successful
    if (result){
        [_unsavedChanges removeAllObjects];
    }
    
    [self reload];
    
    return result;
}

-(BOOL)revert{
    RHLog(@"Reverting all unsaved changes.");
    [_unsavedChanges removeAllObjects];
    return YES;
}

#pragma mark - creation
-(BOOL)hasBeenCreated{
    return _objectID != RHSQLiteObjectIDNotYetAvailable;
}

-(BOOL)create{
    return [self createWithError:nil];
}

-(BOOL)createWithError:(NSError**)errorOut{
    DATA_STORE_REQUIRED();
    
    //TODO: When saving, make sure that only valid keys in _unsavedChanges are included in the save query.
    // Before a datastore is associated we allow stuff to be stored for any column name.
    
    __block BOOL result = NO;
    __block RHSQLiteObjectID newID = RHSQLiteObjectIDInvalid;
    
    if ([self hasBeenCreated]){
        RHLog(@"Note: Object has already been created. Forwarding to saveWithError:");
        return [self saveWithError:errorOut];
    }
    
    //perform the creation
    [_dataStore accessDatabase:^(FMDatabase *db) {
        
        NSArray *args = nil;
        NSString *sql = [self createSQLWithArguments:&args];
        if (sql){
            result = [db executeUpdate:sql withArgumentsInArray:args];
            if (result) newID = [db lastInsertRowId];
            if (!result){
                RHErrorLog(@"Error: Create failed with error %@.", [db lastError]);
                if (errorOut) *errorOut = [db lastError];
            }
        }
    }];
    
    _objectID = newID;

    //clear out unsaved changes if successful
    if (result){
        [_unsavedChanges removeAllObjects];
    }

    [self reload];
    
    //check in
    if (_objectID < RHSQLiteObjectIDNotYetAvailable && result){
        [_dataStore _objectCheckIn:self];
    }
    
    return result;
}

#pragma mark - deletion
-(BOOL)hasBeenDeleted{
    return _deleted;
}

-(BOOL)delete{
    DATA_STORE_REQUIRED();
    if ([self hasBeenDeleted]) return YES;

    __block BOOL result = NO;
    if ([self hasBeenCreated]){
        [_dataStore accessDatabase:^(FMDatabase *db) {
            result = [db executeUpdate:[self deleteSQL]];
        }];
    } else {
        //if we have not yet been created, the easiest way to delete ourselves is just nuke our not yet created ID
        result = YES;
    }

    if (result){
        //mark as deleted
        _deleted = YES;
    }
    
    return result;
}

#pragma mark - dictionary representation
-(NSString*)dictionaryKeyForColumn:(NSString*)columnName{
    //just passthrough. we provide this for subclasses to use as they see fit.
    return columnName;
}

-(NSDictionary*)dictionaryRepresentation{
    [self load];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [_loadedColumnsAndValues enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [result setObject:RHSQLiteObjectValueDecode(_dataStore, obj, [self classForColumn:key]) forKey:[self dictionaryKeyForColumn:key]];
    }];
    return [NSDictionary dictionaryWithDictionary:result];
}

-(NSDictionary*)unsavedDictionaryRepresentation{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [_unsavedChanges enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [result setObject:RHSQLiteObjectValueDecode(_dataStore, obj, [self classForColumn:key]) forKey:[self dictionaryKeyForColumn:key]];
    }];
    return [NSDictionary dictionaryWithDictionary:result];
}


#pragma mark - sql
-(NSString*)loadSQL{
    if (![self hasBeenCreated]) return nil;
    if ([self hasBeenDeleted]) return nil;
    return [NSString stringWithFormat:@"SELECT * FROM `%@` WHERE `%@` = %lli;", self.tableName, self.primaryKeyName, self.objectID];
}
-(NSString*)deleteSQL{
    if (![self hasBeenCreated]) return nil;
    return [NSString stringWithFormat:@"DELETE FROM `%@` WHERE `%@` = %lli;", self.tableName, self.primaryKeyName, self.objectID];
    
}

-(NSString*)createSQLWithArguments:(NSArray **)argumentsOut{
    if (argumentsOut) *argumentsOut = nil;
    if ([self hasBeenCreated]) return nil;
    if ([_unsavedChanges count] < 1){
        //if we have no current unsaved values, lets try and save with NSNull for our primaryKeyName
        if (argumentsOut) *argumentsOut = [NSArray arrayWithObject:[NSNull null]];
        return [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (?);", [self tableName], [self primaryKeyName]];
    }
    
    NSMutableArray *names = [NSMutableArray array];
    NSMutableArray *values = [NSMutableArray array];
    NSMutableString *questions = [NSMutableString string];
    
    for (NSString *columnName in [_unsavedChanges allKeys]) {
        id value = [_unsavedChanges objectForKey:columnName];
        [names addObject:columnName];
        [values addObject:value];
        [questions appendString:@"?, "];
    }

    //remove the last comma+space
    [questions deleteCharactersInRange:NSMakeRange(questions.length - 2, 2)];
    
    //set our args
    if (argumentsOut) *argumentsOut = [NSArray arrayWithArray:values];

    //build our actual sql
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@);", [self tableName], [names componentsJoinedByString:@", "], questions];
    
    //return
    return sql;
}

-(NSString*)saveSQLWithArguments:(NSArray **)argumentsOut{
    if (argumentsOut) *argumentsOut = nil;
    if (![self hasBeenCreated]) return nil;
    if ([_unsavedChanges count] < 1){
        RHErrorLog(@"Unable to generate save SQL statment because there are no values to save.");
        return nil;
    }
    NSMutableArray *names = [NSMutableArray array];
    NSMutableArray *values = [NSMutableArray array];
    
    for (NSString *columnName in [_unsavedChanges allKeys]) {
        id value = [_unsavedChanges objectForKey:columnName];
        [names addObject:columnName];
        [values addObject:value];
    }
    
    //set our args
    if (argumentsOut) *argumentsOut = [NSArray arrayWithArray:values];
    
    //build our actual sql
    NSString *sql = [NSString stringWithFormat:@"UPDATE `%@` SET `%@`=? WHERE `%@` = %llu;", [self tableName], [names componentsJoinedByString:@"`=?, `"], [self primaryKeyName], self.objectID];
    
    //return
    return sql;
}



-(NSString*)createTableSQL{
    DATA_STORE_REQUIRED();
    __block NSString *result = nil;
    [_dataStore accessDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"SELECT `sql` FROM sqlite_master WHERE `type` = 'table' and lower(name) = '%@';", self.tableName ];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]){
            result = [resultSet stringForColumn:@"sql"];
        }
        [resultSet close];
    }];
    return result;
}


#pragma mark - value encoding / decoding 
id RHSQLiteObjectValueEncode(RHSQLiteDataStore *dataStore, id objectToBeEncoded){
    //simple pass throughs
    if ([objectToBeEncoded isKindOfClass:[NSString class]]) return objectToBeEncoded;
    if ([objectToBeEncoded isKindOfClass:[NSNumber class]]) return objectToBeEncoded;
    if ([objectToBeEncoded isKindOfClass:[NSData class]]) return objectToBeEncoded;
    if ([objectToBeEncoded isKindOfClass:[NSNull class]]) return objectToBeEncoded;
    
    //more complex conversions
    if ([objectToBeEncoded isKindOfClass:[NSDate class]]){
        RHLog(@"Encoding NSDate -> NSNumber using timeIntervalSince1970.");
        return [NSNumber numberWithDouble:[objectToBeEncoded timeIntervalSince1970]];
    }
    
    //nscoding supported objects && RHSQLiteObjects. RHSQLiteObjects are actually archivable via way of the RHSQLitePlaceholder class.
    if ([objectToBeEncoded conformsToProtocol:@protocol(NSCoding)] || [objectToBeEncoded isKindOfClass:[RHSQLiteObject class]]){
        NSMutableData *mutableData = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:mutableData];
        [archiver setDelegate:dataStore];
        [archiver encodeObject:objectToBeEncoded forKey:@"root"]; // root == backwards compatible NSKeyedArchiveRootObjectKey
        [archiver finishEncoding];
        NSData *data = [NSData dataWithData:mutableData];
        if (data){
            RHLog(@"Encoded %@ -> NSData using NSKeyedArchiver.", NSStringFromClass([objectToBeEncoded class]));
            return data;
        }
    }
    

    //default to passthrough
    return objectToBeEncoded;
}

id RHSQLiteObjectValueDecode(RHSQLiteDataStore *dataStore, id objectToBeDecoded, Class expectedClass){
        
    //nothing can really be gleamed from nil, so just pass through
    if (!objectToBeDecoded || objectToBeDecoded == [NSNull null]){
        return nil;
    }
    
    //if the object is already of the expected class, return early.
    if ([objectToBeDecoded isKindOfClass:expectedClass]){
        return objectToBeDecoded;
    }
    
    //NSNumber to NSDate
    if ([expectedClass isSubclassOfClass:[NSDate class]] && [objectToBeDecoded isKindOfClass:[NSNumber class]]){
        RHLog(@"Decoding NSNumber -> NSDate using dateWithTimeIntervalSince1970.");
        return [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)objectToBeDecoded doubleValue]];
    }

    //NSString to NSDate
    if ([expectedClass isSubclassOfClass:[NSDate class]] && [objectToBeDecoded isKindOfClass:[NSString class]]){
        RHLog(@"Decoding NSString -> NSDate using dateWithTimeIntervalSince1970.");
        return [NSDate dateWithTimeIntervalSince1970:[(NSString*)objectToBeDecoded doubleValue]];
    }

    //nscoding supported objects
    if ([expectedClass instancesRespondToSelector:@selector(initWithCoder:)] || [expectedClass isSubclassOfClass:[RHSQLiteObject class]]){
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:objectToBeDecoded];
        [unarchiver setDelegate:dataStore];
        id result = [unarchiver decodeObjectForKey:@"root"]; // root == backwards compatible NSKeyedArchiveRootObjectKey
        [unarchiver finishDecoding];
        if ([result isKindOfClass:expectedClass]){
            RHLog(@"Successfully Decoded NSData -> %@ using NSKeyedUnarchiver.", NSStringFromClass(expectedClass));
            return result;
        }
    }
    
    
    //default to passthrough
    RHErrorLog(@"Error: Unable to transform object of class %@ into expected class %@. Returning as is.", NSStringFromClass([objectToBeDecoded class]), NSStringFromClass(expectedClass));
    return objectToBeDecoded;
}


#pragma mark - description
-(NSString*)description{
    if (!_loaded)[self load];
    NSString *state = [self hasBeenDeleted] ? @"DELETED" : [self hasBeenCreated] ? @"CREATED" : @"NOT-YET-CREATED";        
    return [NSString stringWithFormat:@"<%@: %p, datastore: %p, state: %@, id: %lld, values: %@, unsavedValues: %@>", NSStringFromClass([self class]), self, _dataStore, state, _objectID, [self dictionaryRepresentation], [self unsavedDictionaryRepresentation]];
}

@end
