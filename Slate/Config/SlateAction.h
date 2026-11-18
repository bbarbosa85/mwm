//
//  SlateAction.h
//  Slate
//
//  An action string from ~/.mwm.yml ("focus 'Finder'", "${lefthalf} ${monitor-a}")
//  split into a kind and up to two fields, so the window can offer a dropdown
//  per kind instead of a text box. Anything not recognized stays "custom".
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

typedef NS_ENUM(NSInteger, SlateActionKind) {
  SlateActionKindMove,           // a=position name, b=monitor name ("" for the current screen)
  SlateActionKindFocusApp,       // a=application name
  SlateActionKindFocusDirection, // a=left|right|up|down|behind
  SlateActionKindThrow,          // a=screen (a monitor name, number, next, previous), b=style
  SlateActionKindNudge,          // a=x, b=y
  SlateActionKindResize,         // a=x, b=y
  SlateActionKindPush,           // a=direction, b=options
  SlateActionKindHint,           // a=characters
  SlateActionKindGrid,           // a=arguments
  SlateActionKindSwitch,
  SlateActionKindRelaunch,
  SlateActionKindCustom,         // a=the whole text
  SlateActionKindSnapshot,       // a=snapshot name, b="save-to-disk" or ""
  SlateActionKindRestoreSnapshot,// a=snapshot name
};

@interface SlateAction : NSObject

@property (assign) SlateActionKind kind;
@property (copy) NSString *a;
@property (copy) NSString *b;

// Reads an action string. Names in ${...} are kept as names.
+ (SlateAction *)parse:(NSString *)text;
// An action of this kind with sensible starting values.
+ (SlateAction *)actionOfKind:(SlateActionKind)kind;
// The action string for the current kind and fields.
- (NSString *)string;

+ (NSArray<NSNumber *> *)allKinds;
+ (NSString *)titleForKind:(SlateActionKind)kind;
+ (NSArray<NSString *> *)directions;
+ (NSArray<NSString *> *)pushDirections;

@end

@interface SlateAction (Preview)
// Where a position puts a window, as fractions of the screen (x, y, width,
// height, top-left origin), or NO if it can't be worked out (it depends on the window).
+ (BOOL)previewForPositionText:(NSString *)text rect:(CGRect *)rect;
@end

NS_ASSUME_NONNULL_END
