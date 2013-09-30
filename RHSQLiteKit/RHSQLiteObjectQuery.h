//
//  RHSQLiteObjectQuery.h
//  RHSQLiteKit
//
//  Created by Richard Heard on 14/07/13.
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

#import <Foundation/Foundation.h>

/*!
 @class RHSQLiteObjectQuery
 @abstract RHSQLiteObjectQuery represents the various parts of an SQL query.
 @discussion The generated SQL from this class takes the form "SELECT * FROM {tableName} WHERE {where} ORDER BY {orderedBy} {ASC/DESC};"
 */
@interface RHSQLiteObjectQuery : NSObject {
    Class _objectClass;
    NSString *_where;
    NSString *_orderedBy;
}

/*!
 @method +(id)queryForObjectClass:where:orderedBy:ascending:
 @abstract Initialises a new query instance.
 @param objClass They kind of RHSQLiteObject subclass what you want returned by the query. (+[RHSQLiteObject tableName] is used internally)
 @param where A valid SQL WHERE statement.
 @param columnName The name of a valid column that you want results sorted by.
 @param ascending Whether results should be returned in ascending or descending order.
 @returns The newly instantiated RHSQLiteQuery object.
 */
+(id)queryForObjectClass:(Class)objClass where:(NSString*)where orderedBy:(NSString*)columnName ascending:(BOOL)ascending;


/*!
 @property objectClass
 @abstract They kind of RHSQLiteObject subclass what you want returned by the query. (+[RHSQLiteObject tableName] is used internally)
 */
@property (nonatomic, assign) Class objectClass;

/*!
 @method setWhere
 @abstract Set the queries SQL WHERE statement.
 @param where A valid SQL WHERE statement.
 */
-(void)setWhere:(NSString*)where;

/*!
 @method setOrderedBy:ascending:
 @abstract Set the queries SQL ORDER BY clause.
 @param columnName The name of a valid column that you want results sorted by.
 @param ascending Whether results should be returned in ascending or descending order.
 */
-(void)setOrderedBy:(NSString*)columnName ascending:(BOOL)ascending;

/*!
 @method sql
 @abstract Access the generated SQL query for the instances specified params.
 @returns Generated SQL query of the form "SELECT * FROM {tableName} WHERE {where} ORDER BY {orderedBy} {ASC/DESC};"
 */
-(NSString*)sql;

@end
