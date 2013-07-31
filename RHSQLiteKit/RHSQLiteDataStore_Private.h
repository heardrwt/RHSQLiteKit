//
//  RHSQLiteDataStore.h
//  RHSQLiteKit
//
//  Created by Richard Heard on 13/07/13.
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
// PRIVATE : DO NOT USE UNLESS YOU KNOW WHAT YOU ARE DOING

#import "RHSQLiteDataStore.h"

@interface RHSQLiteDataStore () <NSKeyedUnarchiverDelegate, NSKeyedArchiverDelegate>

//metadata (it's like a magic key value store, for storage of tasty morsels)
-(id)_metadataValueForKey:(NSString*)columnName;
-(void)_metadataSetValue:(id)object forKey:(NSString*)columnName;


//cache access
-(NSMutableDictionary*)_weakObjectCacheForTable:(NSString*)tableName; // these are weak value dictionaries created using CFDictionaryCreate() careful.
-(RHSQLiteObject*)_cachedObjectForTable:(NSString*)tableName objectID:(RHSQLiteObjectID)objectID;

//cache management
-(void)_objectCheckIn:(RHSQLiteObject*)object;
-(void)_objectCheckOut:(RHSQLiteObject*)object; //careful.. this can be called from inside the objects dealloc method (only use tableName and objectID);

//archiving and unarchiving - See: <NSKeyedUnarchiverDelegate, NSKeyedArchiverDelegate>
//RHSQLiteObject subclasses are replaced by an instance of the RHSQLiteObjectPlaceholder class by archivers using the dataStore as a delegate

@end

