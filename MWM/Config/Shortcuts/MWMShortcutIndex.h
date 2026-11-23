//
//  MWMShortcutIndex.h
//  Slate
//
//  The shortcuts of a configuration, understood for the Keyboard page: which
//  modifier group each one uses (hyper, shyper, or a custom set), what kind of
//  thing it does, a title for it, and which share the same keys.
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

@class MWMConfigDocument, MWMBindingEntry;

NS_ASSUME_NONNULL_BEGIN

// What a shortcut does, as the Keyboard page groups and colors it.
typedef NS_ENUM(NSInteger, MWMShortcutKind) {
  MWMShortcutKindMoveToSlot,      // blue: Layout
  MWMShortcutKindFocusApp,        // green: windows and apps
  MWMShortcutKindFocusWindow,
  MWMShortcutKindResizeNudge,     // resize, nudge, push, throw
  MWMShortcutKindFeature,         // purple: hints, grid, switcher, relaunch
  MWMShortcutKindOther,           // anything written by hand
};

@interface MWMShortcutInfo : NSObject
@property (strong) MWMBindingEntry *binding;
@property (assign) NSUInteger index;                       // in the document's bindings
@property (copy) NSString *keyName;                        // "pad8", "c"
@property (copy) NSArray<NSString *> *modifierNames;       // ctrl, alt, shift, cmd in that order
@property (copy, nullable) NSString *groupName;            // "hyper", or nil for a set no group names
@property (copy, nullable) NSString *identity;             // equal for shortcuts that fire on the same keys
@property (assign) MWMShortcutKind kind;
@property (copy) NSString *title;                          // "Move to third2", "Focus Finder"
@property (copy, nullable) NSString *detail;               // "on Samsung"
@property (assign) BOOL conflict;                          // another enabled shortcut has the same keys
+ (NSString *)kindTitle:(MWMShortcutKind)kind;
@end

@interface MWMModifierGroup : NSObject
@property (copy) NSString *name;                           // "hyper"; "Custom" for sets no group names
@property (copy) NSArray<NSString *> *modifierNames;
@property (assign) BOOL custom;
@property (assign) NSUInteger count;
@end

@interface MWMShortcutIndex : NSObject

+ (instancetype)indexForDocument:(MWMConfigDocument *)document;

@property (readonly) NSArray<MWMShortcutInfo *> *shortcuts;
// The groups the file names (in file order), then Custom if some shortcuts use other modifier sets.
@property (readonly) NSArray<MWMModifierGroup *> *groups;
@property (readonly) NSUInteger conflictCount;

- (NSArray<MWMShortcutInfo *> *)shortcutsInGroup:(nullable NSString *)groupName;   // nil: all
- (nullable MWMShortcutInfo *)shortcutForKeyName:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames;
- (nullable MWMShortcutInfo *)shortcutAtBindingIndex:(NSUInteger)index;
- (NSUInteger)countOfKind:(MWMShortcutKind)kind;

@end

NS_ASSUME_NONNULL_END
