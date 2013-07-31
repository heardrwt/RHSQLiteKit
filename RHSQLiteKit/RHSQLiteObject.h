//
//  RHSQLiteObject.h
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


/*
 
 TODO: make deleted and invalid BOOLs instead of overwriting the object ID. 
 People might like to delete and then still know the id of the thing they deleted.
 
 TODO: some kind of alive object cache. so that multiple requests for the same object IDs return the same object.
 
 */

#import "RHDynamicPropertyObject.h"

#define RHSQLiteObjectIDInvalid INT64_MAX              //represents an invalid object ID
#define RHSQLiteObjectIDNotYetAvailable INT64_MAX - 1  //represents an object that is in the process of being created and does not yet have a sqlite row id
typedef int64_t RHSQLiteObjectID;


@class RHSQLiteDataStore;

@interface RHSQLiteObject : RHDynamicPropertyObject {
    RHSQLiteDataStore *_dataStore;
    RHSQLiteObjectID _objectID;
    
    BOOL _loaded;  // true if we have loaded our contents from the db.
    BOOL _deleted; // true if the object does not exist in the db either due to it being deleted, or failing to find a row with a given ID upon load

    NSMutableDictionary *_loadedColumnsAndValues;
    
    NSMutableDictionary *_unsavedChanges; //used to store values before we save them to the db
}

//preferred lookup method
+(id)objectFromDataStore:(RHSQLiteDataStore*)dataStore objectID:(RHSQLiteObjectID)objectID; //this method uses the datastores cache, to return existing objects if available.

//these methods skip checking for existing table-id pairs in the dataStore allocations cache, allowing you create duplicates if you would like to. for whatever puropose.
-(id)initWithDataStore:(RHSQLiteDataStore*)dataStore objectID:(RHSQLiteObjectID)objectID;
-(id)initWithDataStore:(RHSQLiteDataStore*)dataStore; // id = RHSQLiteObjectIDNotYetAvailable;
-(id)init; // dataStore = nil; id = RHSQLiteObjectIDNotYetAvailable; (data store must be associated before saving this object)

-(BOOL)associateWithDataStore:(RHSQLiteDataStore*)dataStore; // once an instance is associated with a data store, it can not be changed and will raise an exception.
@property (nonatomic, retain, readonly) RHSQLiteDataStore  *dataStore; //objects retain their dataStore


+(NSString*)tableName; //subclassers: you must implement this method and return the appropriate table name for your subclass. Do not call super.
-(NSString*)tableName;

+(NSString*)primaryKeyName; //defaults to "_ROWID_". Every row in a table in SQLite has a unique row id, which can be accessed using _ROWID_
-(NSString*)primaryKeyName;


@property (nonatomic, readonly) RHSQLiteObjectID objectID;

//loading (on property access, if required, load is automatically called)
-(BOOL)needsLoading;
-(BOOL)load;
-(BOOL)reload;

//object getters (KVO compliant) these return either NSDate, NSNumber, NSString, NSData, or NSNull. These raise for unknown columns
-(id)objectForColumn:(NSString*)columnName;
-(id)objectForKeyedSubscript:(NSString *)columnName; //for new style access of keys and values ie user[@"firstName"];
-(BOOL)columnHasNullValue:(NSString *)columnName;

//object setters
-(void)setObject:(id)obj forColumn:(NSString*)columnName;
-(void)setObject:(id)obj forKeyedSubscript:(NSString *)columnName;

//specific classed object getters (these return nil if the fetched object is not of the specified class)
-(NSData*)dataForColumn:(NSString*)columnName;
-(NSDate*)dateForColumn:(NSString*)columnName;
-(NSNumber*)numberForColumn:(NSString*)columnName;
-(NSString*)stringForColumn:(NSString*)columnName;
-(const char *)UTF8StringForColumn:(NSString*)columnName;


//primitive getters
-(BOOL)boolForColumn:(NSString*)columnName;
-(int)intForColumn:(NSString*)columnName;
-(long)longForColumn:(NSString*)columnName;
-(unsigned long)unsignedLongForColumn:(NSString*)columnName;
-(long long)longLongForColumn:(NSString*)columnName;
-(unsigned long long)unsignedLongLongForColumn:(NSString*)columnName;
-(double)doubleForColumn:(NSString*)columnName;
-(float)floatForColumn:(NSString*)columnName;
-(NSInteger)integerForColumn:(NSString*)columnName;
-(NSUInteger)unsignedIntegerForColumn:(NSString*)columnName;


//primitive setters
-(void)setBool:(BOOL)value forColumn:(NSString*)columnName;
-(void)setInt:(int)value forColumn:(NSString*)columnName;
-(void)setLong:(long)value forColumn:(NSString*)columnName;
-(void)setUnsignedLong:(unsigned long)value forColumn:(NSString*)columnName;
-(void)setLongLong:(long long)value forColumn:(NSString*)columnName;
-(void)setUnsignedLongLong:(unsigned long long)value forColumn:(NSString*)columnName;
-(void)setDouble:(double)value forColumn:(NSString*)columnName;
-(void)setFloat:(float)value forColumn:(NSString*)columnName;
-(void)setInteger:(NSInteger)value forColumn:(NSString*)columnName;
-(void)setUnsignedInteger:(NSUInteger)value forColumn:(NSString*)columnName;


//saving
-(BOOL)hasUnsavedChanges;
-(BOOL)save;
-(BOOL)saveWithError:(NSError**)errorOut;
-(BOOL)revert;

//creation
-(BOOL)hasBeenCreated;
-(BOOL)create;
-(BOOL)createWithError:(NSError**)errorOut;

//deletion
-(BOOL)hasBeenDeleted;
-(BOOL)delete;

//columns
-(NSArray*)columnNames; //array of NSStrings
-(BOOL)hasColumn:(NSString*)columnName;
//-(RHSQLiteColumnType)columnTypeForColumn:(NSString*)columnName;
-(NSString*)columnNameForProperty:(NSString*)propertyName; //these return nil if the column does not exist. bigString => big_string; big_string => bigString;
-(NSString*)propertyNameForColumn:(NSString*)columnName;    
-(Class)classForColumn:(NSString*)columnName; //If a property is defined for a given column name, that class is returned, otherwise we use whatever we can determine from the DB


//dictionary representation
-(NSString*)dictionaryKeyForColumn:(NSString*)columnName; //defaults to converting propertyName to property_name
-(NSDictionary*)dictionaryRepresentation; //non objects are boxed into NSNumber
-(NSDictionary*)unsavedDictionaryRepresentation; //only returns modified columns

//sql
-(NSString*)loadSQL;
-(NSString*)deleteSQL;

-(NSString*)createSQLWithArguments:(NSArray **)argumentsOut;
-(NSString*)saveSQLWithArguments:(NSArray **)argumentsOut;

-(NSString*)createTableSQL; //this requires the datastore to be set and returns the tables current create sql statement.


@end
