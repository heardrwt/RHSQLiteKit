//
//  RHSQLiteObjectPlaceholder.h
//  RHSQLiteKit
//
//  Created by Richard Heard on 29/07/2013.
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
// INTERNAL CLASS: DO NOT USE UNLESS YOU KNOW WHAT YOU ARE DOING

#import <Foundation/Foundation.h>
#import "RHSQLiteObject.h"

/*!
 @class RHSQLiteObjectPlaceholder
 @abstract RHSQLiteObjectPlaceholder is used by an instance of the RHSQLiteDataStore when archiving / unarchiving RHSQLiteObjects.
 @discussion It only comes into play when the data store is set as the delegate on the NSKeyedArchiver / NSKeyedUnarchiver.
 */
@interface RHSQLiteObjectPlaceholder : NSObject <NSCoding>

+(id)placeholderWithObject:(RHSQLiteObject*)object;
+(id)placeholderWithClassName:(NSString*)className tableName:(NSString*)tableName objectID:(RHSQLiteObjectID)objectID;

-(id)initWithClassName:(NSString*)className tableName:(NSString*)tableName objectID:(RHSQLiteObjectID)objectID;

@property (nonatomic, readonly) NSString *className;
@property (nonatomic, readonly) NSString *tableName;
@property (nonatomic, readonly) RHSQLiteObjectID objectID;

-(RHSQLiteObject*)representedObjectInDataStore:(RHSQLiteDataStore*)dataStore;

@end
