//
//  SlateConfigDocument.h
//  Slate
//
//  In-memory model of ~/.mwm.yml: settings, the alias sections and bindings,
//  read from and written to YAML. Nothing in the file is ever executed.
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
// Line number (NSNumber, 1-based) the error is about, when known.
extern NSString *const SlateConfigDocumentErrorLineKey;
// Index (NSNumber) in `bindings` of the binding the error is about, when there is one.
extern NSString *const SlateConfigDocumentErrorBindingIndexKey;
// Name (NSString) of the setting or alias the error is about, when there is one.
extern NSString *const SlateConfigDocumentErrorEntryNameKey;

typedef NS_ENUM(NSInteger, SlateConfigDocumentError) {
  // The file isn't valid YAML (or uses YAML features Slate doesn't read).
  SlateConfigDocumentErrorSyntax = 2,
  // The YAML is fine but the configuration isn't (bad types, unknown alias, ...).
  SlateConfigDocumentErrorInvalid = 3,
};

// How the configuration window groups bindings, from what the action does.
typedef NS_ENUM(NSInteger, SlateBindingCategory) {
  SlateBindingCategoryApps,           // focus 'App'
  SlateBindingCategoryLayout,         // move, throw, corner, chain, sequence, layout, snapshots
  SlateBindingCategoryWindowActions,  // resize, nudge, push, undo, hide/show/toggle, directional focus
  SlateBindingCategoryFeatures,       // hint, grid, switch, relaunch, shell, anything else
};

// A named value: a setting, or an alias in one of the alias sections.
@interface SlateConfigEntry : NSObject
@property (copy) NSString *name;
// NSString or NSNumber. Booleans are NSNumbers backed by CFBoolean.
@property (strong) id value;
// Line in the file it was read from; 0 when it wasn't read from a file. Not part of equality.
@property (assign) NSUInteger line;
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
// Line in the file it was read from; 0 when it wasn't read from a file. Not part of equality.
@property (assign) NSUInteger line;
+ (instancetype)bindingWithKey:(NSString *)key modifiers:(nullable NSString *)modifiers action:(NSString *)action;
@end

// A binding with its aliases expanded, ready to register.
@interface SlateResolvedBinding : NSObject
@property (copy) NSString *hotkey;   // "key" or "key:mods"
@property (copy) NSString *action;
@property (strong, nullable) NSNumber *repeat;
@property (assign) NSUInteger index; // in the document's bindings
@end

// What Slate loads from a document: settings with aliases expanded (string
// values; numbers and booleans as written) and the enabled bindings.
@interface SlateResolvedConfig : NSObject
@property (strong) NSArray<SlateConfigEntry *> *settings;
@property (strong) NSArray<SlateResolvedBinding *> *bindings;
@end

@interface SlateConfigDocument : NSObject

@property (strong) NSMutableArray<SlateConfigEntry *> *settings;
@property (strong) NSMutableArray<SlateConfigEntry *> *modifiers;
@property (strong) NSMutableArray<SlateConfigEntry *> *monitors;
@property (strong) NSMutableArray<SlateConfigEntry *> *positions;
@property (strong) NSMutableArray<SlateConfigEntry *> *aliases;
@property (strong) NSMutableArray<SlateBindingEntry *> *bindings;

// ~/.mwm.yml, tilde expanded.
+ (NSString *)defaultPath;

+ (nullable instancetype)documentWithContentsOfFile:(NSString *)path error:(NSError **)error;
+ (nullable instancetype)documentFromString:(NSString *)source error:(NSError **)error;

// lenient:YES checks only the structure, so a config with an unknown or
// duplicate alias still loads (the configuration window, mid-edit).
+ (nullable instancetype)documentFromString:(NSString *)source lenient:(BOOL)lenient error:(NSError **)error;

// Expands aliases into what Slate registers. Fails on the first unknown,
// duplicate or looping alias.
- (nullable SlateResolvedConfig *)resolve:(NSError **)error;

// The same, but keeps going: every problem is added to `errors`, and the
// bindings and settings that had one are left out of the result.
- (SlateResolvedConfig *)resolveCollectingErrors:(NSMutableArray<NSError *> *)errors;

// Replaces ${name} references with this document's aliases, following nested
// references. Unknown references are left as written.
- (NSString *)expandAliases:(NSString *)text;

- (SlateBindingCategory)categoryOfBinding:(SlateBindingEntry *)binding;

// The file contents for this document, as YAML in Slate's canonical layout.
- (NSString *)stringRepresentation;

// Writes atomically. An existing file is first copied to <path>.bak, and a
// symlinked path is written through to its target.
- (BOOL)writeToFile:(NSString *)path error:(NSError **)error;

// The same safe write (atomic, .bak, through symlinks) for arbitrary text.
+ (BOOL)writeString:(NSString *)contents toFile:(NSString *)path error:(NSError **)error;

// backup:NO skips the .bak copy, for repeated saves of one editing session.
+ (BOOL)writeString:(NSString *)contents toFile:(NSString *)path backup:(BOOL)backup error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
