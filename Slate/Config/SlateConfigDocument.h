//
//  SlateConfigDocument.h
//  Slate
//
//  In-memory model of a managed ~/.slate.js file: the `config` object that
//  slate.applyConfig receives, plus the free-form custom code after the marker.
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

extern NSString *const SlateConfigDocumentErrorDomain;
// Line number (NSNumber) of a JavaScript error, when known.
extern NSString *const SlateConfigDocumentErrorLineKey;
// The line that separates the managed block from the user's custom code.
extern NSString *const SlateConfigDocumentCustomCodeMarker;

typedef NS_ENUM(NSInteger, SlateConfigDocumentError) {
  // The file is not in the managed format (e.g. hand-written JS calling other slate APIs).
  SlateConfigDocumentErrorNotManaged = 1,
  // The managed block threw while being evaluated (syntax error, exception).
  SlateConfigDocumentErrorScript = 2,
  // The config object is well-formed JS but invalid (bad types, unknown alias, ...).
  SlateConfigDocumentErrorInvalid = 3,
};

// A named value: a setting, or an alias in one of the alias sections.
@interface SlateConfigEntry : NSObject
@property (copy) NSString *name;
// NSString or NSNumber. Booleans are NSNumbers backed by CFBoolean.
@property (strong) id value;
+ (instancetype)entryWithName:(NSString *)name value:(id)value;
@end

@interface SlateBindingEntry : NSObject
@property (copy, nullable) NSString *group;
@property (copy) NSString *key;
@property (copy, nullable) NSString *modifiers;
@property (copy) NSString *action;
@property (copy, nullable) NSString *note;
@property (assign) BOOL enabled;
// nil uses the operation's default repeat behavior.
@property (strong, nullable) NSNumber *repeat;
+ (instancetype)bindingWithKey:(NSString *)key modifiers:(nullable NSString *)modifiers action:(NSString *)action;
@end

@interface SlateConfigDocument : NSObject

@property (strong) NSMutableArray<SlateConfigEntry *> *settings;
@property (strong) NSMutableArray<SlateConfigEntry *> *modifiers;
@property (strong) NSMutableArray<SlateConfigEntry *> *monitors;
@property (strong) NSMutableArray<SlateConfigEntry *> *positions;
@property (strong) NSMutableArray<SlateConfigEntry *> *aliases;
@property (strong) NSMutableArray<SlateBindingEntry *> *bindings;
// Everything after the custom code marker, kept byte-for-byte.
@property (copy) NSString *customCode;

// ~/.slate.js, tilde expanded.
+ (NSString *)defaultPath;

+ (nullable instancetype)documentWithContentsOfFile:(NSString *)path error:(NSError **)error;
+ (nullable instancetype)documentFromString:(NSString *)source error:(NSError **)error;

// The file contents for this document, in the canonical managed format.
- (NSString *)stringRepresentation;

// Writes atomically. An existing file is first copied to <path>.bak, and a
// symlinked path is written through to its target.
- (BOOL)writeToFile:(NSString *)path error:(NSError **)error;

// The same safe write (atomic, .bak, through symlinks) for arbitrary text.
+ (BOOL)writeString:(NSString *)contents toFile:(NSString *)path error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
