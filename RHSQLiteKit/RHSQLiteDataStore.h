//
//  RHSQLiteDataStore.h
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
 Collection classes are currently just archived into the column using NSKeyedArchiver
 Any RHSQLiteObject subclasses have their dataStore set, and are saved before being replaced by placeholder references in the container.
 The same is also true for single item properties.
 */

#import <Foundation/Foundation.h>

#import "RHSQLiteObject.h"
#import "FMDatabase.h"

@class RHSQLiteObjectQuery;
@class FMDatabaseQueue;

/*!
 @class RHSQLiteDataStore
 @abstract RHSQLiteDataStore wraps an instance of an SQLite.db file and provides an object based wrapper around the db's tables.
 @discussion Usually you would only create a single instance of this datastore class per SQLite file. 
    Access to the actual SQLite file is thread-safe, however care should still be taken when using from multiple threads.
 */
@interface RHSQLiteDataStore : NSObject {
    NSString *_path;
    FMDatabaseQueue *_databaseQueue;
    
    BOOL _loaded;
    
    NSMutableArray *_knownTableNames;
    NSMutableDictionary *_associatedClassNamesByTableName;
    
    NSMutableArray *_registeredMigrationPaths;

    //cache
    NSMutableDictionary *_perTableWeakObjectCaches; //each table has an entry in the top level dictionary. Caution: Each sub dictionary's values are RHWeakValue objects, weakly wrapping underlying RHSQLiteObject subclasses

}

#pragma mark - init
/*! 
 @method initWithPath:
 @abstract Init with a specified path.
 @discussion If path does not currently exist, a new, empty file will be created.
 @param path The fully qualified path to the SQLite file that you wish to open.
 @returns The newly in initialised instance, or nil on error.
 */
-(id)initWithPath:(NSString*)path;

/*!
 @property path
 @abstract The path that this data store was initialised with.
 */
@property (nonatomic, copy, readonly) NSString *path;

/*!
 @method loadAndPerformAnyRequiredMigrations
 @abstract Load the data store, performing any required migrations.
 @discussion All object classes should be associated, and all migrations should be registered before calling this method.
    Calling this method is required before accessing any objects from the data store.
 @returns NO if a migration fails etc.
 */
-(BOOL)loadAndPerformAnyRequiredMigrations;


#pragma mark - access the underlying database
-(void)accessDatabase:(void (^)(FMDatabase *db))block;
-(void)accessDatabaseWithTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block;
-(void)accessDatabaseWithDeferredTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block;


#pragma mark - generic lookup methods

/*!
 @abstract An array of table names in the current data store.
 @discussion The data store must be loaded before accessing this property.
 */
@property (nonatomic, readonly) NSArray *tableNames;

/*!
 @method numberOfObjectsInTable:
 @abstract returns the number of objects for a given table.
 @discussion The data store must be loaded before accessing this property.
 @param tableName The name of a table in the current data store.
 @returns The count of objects in a given table.
 */
-(int64_t)numberOfObjectsInTable:(NSString*)tableName;

/*!
 @method objectFromTable:withID:
 @abstract Fetches a single RHSQLiteObject instance, representing the passed in params.
 @discussion The data store must be loaded before accessing this property.
 @param tableName The name of a table in the current data store. Must be a valid table name.
 @param objectID The ID of the object. Must be a valid ID.
 @returns The newly instantiated object, or an existing object from the instance cache.
 */
-(RHSQLiteObject*)objectFromTable:(NSString*)tableName withID:(RHSQLiteObjectID)objectID; //entries are created on the fly from sqlite, therefore this will likely return a new object on each call
-(NSArray*)objectsFromTable:(NSString*)tableName withIDs:(NSArray*)objectIDs;

-(NSArray*)objectsMatchingQuery:(RHSQLiteObjectQuery*)query;  //array of NSNumbers
-(NSArray*)objectsFromTable:(NSString*)tableName where:(NSString*)where orderedBy:(NSString*)columnName ascending:(BOOL)ascending;

-(NSArray*)objectIDsMatchingQuery:(RHSQLiteObjectQuery*)query; //array of NSNumbers
-(NSArray*)objectIDsFromTable:(NSString*)tableName where:(NSString*)where orderedBy:(NSString*)columnName ascending:(BOOL)ascending;


//textual search
-(NSArray*)objectsFromTable:(NSString*)tableName containingString:(NSString*)string inColumn:(NSString*)columnName;


//creation
-(RHSQLiteObject*)newObjectInTable:(NSString*)tableName NS_RETURNS_RETAINED;


//insertion (these methods return the newly inserted object id/ids) (behind the scenes they associate the object with the current data store, save the object and then return its new id)
-(RHSQLiteObjectID)insertObject:(RHSQLiteObject*)object;
-(NSArray*)insertObjects:(NSArray*)objects; //array of RHSQLiteObject objects


//deletion
-(BOOL)deleteObject:(RHSQLiteObject*)object;
-(NSArray*)deleteObjects:(NSArray*)objects; //array of NSNumber / BOOLs


//object class to table association. (tell the data store about your custom RHSQLiteObject subclasses here and have them automatically vended from all appropriate methods.)
@property (nonatomic, readonly) NSArray *objectClassNames; //array of NSStrings
-(void)associateObjectClass:(Class)objectClass; //we use the classes +tableName method internally to work out the table that the class should represent
-(Class)objectClassForTable:(NSString*)tableName; //defaults to an automatically generated RHSQLiteObject subclass unless a specific class has been associated using the above method.


//migrations (you can register multiple migration files with the data store, in order. ie oldest to newest and the data store will take care of executing the migration scripts, as required, in order)
-(void)registerMigrationsFile:(NSString*)migrationPath;
-(BOOL)migrationsEnabled; //true if any migrations have been registered
-(BOOL)requiresMigration;

//generic db type info
-(NSArray*)tableNames;
-(NSArray*)columnNamesForTable:(NSString*)tableName;
-(NSString*)columnTypeForTable:(NSString*)tableName andColumn:(NSString*)columnName; // these return INTEGER, TEXT, REAL, or BLOB or nil for unknown table/column pair
-(NSString*)requiredColumnTypeForObject:(id)object;


@end
