## RHSQLiteKit

RHSQLiteKit is an object based wrapper for SQLite and FMDB, allowing for multiple databases in the same app. Objects are automatically cached and disposed of as you access them, providing an easy to use data store.


## Interface

```objectivec


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

//init
-(id)initWithPath:(NSString*)path;
@property (nonatomic, copy, readonly) NSString *path;

//all object classes should be associated, and all migrations should be registered before calling this method.
-(BOOL)loadAndPerformAnyRequiredMigrations;


//access the underlying database
-(void)accessDatabase:(void (^)(FMDatabase *db))block;
-(void)accessDatabaseWithTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block;
-(void)accessDatabaseWithDeferredTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block;


//generic lookup methods
@property (nonatomic, readonly) NSArray *tableNames;

-(int64_t)numberOfObjectsInTable:(NSString*)tableName;

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


```


## Licence
Released under the Modified BSD License. 
(Attribution Required)
<pre>
RHSQLiteKit

Copyright (c) 2013 Richard Heard. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
</pre>

## issues

Feel free to file issues for anything that doesn't work correctly, or you feel could be improved. 

## Appreciation 

If you find this project useful, buy me a beer the next time you see me, or grab me something from my [**wishlist**](http://www.amazon.com/gp/registry/wishlist/3FWPYC4SEU5QM ). 

