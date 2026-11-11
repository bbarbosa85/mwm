//
//  SlateYAML.h
//  Slate
//
//  A small, strict YAML reader for ~/.slate.yml. It understands the subset a
//  configuration needs: block mappings and sequences, plain and quoted
//  scalars, booleans, numbers, null, comments, and empty {} / []. Anything
//  else (anchors, tags, multi-line strings, flow collections) is rejected
//  with an error that names the line, rather than guessed at.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see http://www.gnu.org/licenses

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const SlateYAMLErrorDomain;
// Line number (NSNumber, 1-based) where a parse error was found.
extern NSString *const SlateYAMLErrorLineKey;

// A mapping that keeps its keys in file order and remembers their lines.
@interface SlateYAMLMapping : NSObject
@property (readonly) NSArray<NSString *> *keys;
// Line of the first key; 0 for an empty {} mapping's own line.
@property (assign) NSUInteger line;
- (nullable id)objectForKey:(NSString *)key;
- (NSUInteger)lineForKey:(NSString *)key;
@end

@interface SlateYAML : NSObject

// Returns a SlateYAMLMapping, NSArray, NSString, NSNumber (booleans are
// CFBoolean-backed), or NSNull (also for an empty document).
+ (nullable id)parse:(NSString *)text error:(NSError **)error;

// A double-quoted scalar, escaped so it always reads back as the same string.
+ (NSString *)quotedString:(NSString *)string;

// A mapping key: plain when that's unambiguous, quoted otherwise.
+ (NSString *)key:(NSString *)key;

// true/false, a number, or a quoted string.
+ (NSString *)scalar:(id)value;

@end

NS_ASSUME_NONNULL_END
