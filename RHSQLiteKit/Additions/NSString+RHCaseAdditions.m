//
//  NSString+RHCaseAdditions.m
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

#import "NSString+RHCaseAdditions.h"

@implementation NSString (sk_RHCaseAdditions)

-(NSString*)sk_uppercaseFirstString{
    if (self.length < 1) return self;
    return [[[self substringToIndex:1] uppercaseString] stringByAppendingString:[self substringFromIndex:1]];
}

-(NSString*)sk_lowercaseFirstString{
    if (self.length < 1) return self;
    return [[[self substringToIndex:1] lowercaseString] stringByAppendingString:[self substringFromIndex:1]];
}

-(NSString*)sk_camelcaseString{
    NSArray *components = [self componentsSeparatedByString:@"_"];
    NSMutableString *result = [NSMutableString string];
    
    for (NSString *component in components) {
        if (result.length == 0){
            [result appendString:[component sk_lowercaseFirstString]];
        } else {
            [result appendString:[component sk_uppercaseFirstString]];
        }
    }
    
    return [NSString stringWithString:result];
}

-(NSString*)sk_underscoreString{
    NSMutableString *result = [NSMutableString stringWithString:self];
    NSRange range = [result rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]];
    
    while (range.location != NSNotFound) {
        [result replaceCharactersInRange:range withString:[[result substringWithRange:range] lowercaseString]];
        [result insertString:@"_" atIndex:range.location];
        range = [result rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]];
    }
    
    return [NSString stringWithString:result];
}

-(NSString*)sk_stringByDeletingComments{
    NSRange range;
    NSMutableString *result = [NSMutableString stringWithString:self];

    //remove: /* comment */
    while ((range = [result rangeOfString:@"/\\*.*?\\*/" options:NSRegularExpressionSearch]).location != NSNotFound){
        [result replaceCharactersInRange:range withString:@""];
    }
    
    //remove: //comment
    while ((range = [result rangeOfString:@"//.*?\\n" options:NSRegularExpressionSearch]).location != NSNotFound){
        [result replaceCharactersInRange:range withString:@""];
    }

    return [NSString stringWithString:result];
}

-(NSString*)sk_stringByTrimmingWhitespaceAndNewlineCharacters{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end

//include an implementation in this file so we don't have to use -load_all for this category to be included in a static lib
@interface sk_RHFixCategoryBugClassNSSRHCA : NSObject @end @implementation sk_RHFixCategoryBugClassNSSRHCA @end

