//
//  MWMAction.h
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

typedef NS_ENUM(NSInteger, MWMActionKind) {
  MWMActionKindMove,           // a=position name, b=monitor name ("" for the current screen)
  MWMActionKindFocusApp,       // a=application name
  MWMActionKindFocusDirection, // a=left|right|up|down|behind
  MWMActionKindThrow,          // a=screen (a monitor name, number, next, previous), b=style
  MWMActionKindNudge,          // a=x, b=y
  MWMActionKindResize,         // a=x, b=y
  MWMActionKindPush,           // a=direction, b=options
  MWMActionKindHint,           // a=characters
  MWMActionKindGrid,           // a=arguments
  MWMActionKindSwitch,
  MWMActionKindRelaunch,
  MWMActionKindCustom,         // a=the whole text
  MWMActionKindSnapshot,       // a=snapshot name, b="save-to-disk" or ""
  MWMActionKindRestoreSnapshot,// a=snapshot name
};

@interface MWMAction : NSObject

@property (assign) MWMActionKind kind;
@property (copy) NSString *a;
@property (copy) NSString *b;

// Reads an action string. Names in ${...} are kept as names.
+ (MWMAction *)parse:(NSString *)text;
// An action of this kind with sensible starting values.
+ (MWMAction *)actionOfKind:(MWMActionKind)kind;
// The action string for the current kind and fields.
- (NSString *)string;

+ (NSArray<NSNumber *> *)allKinds;
+ (NSString *)titleForKind:(MWMActionKind)kind;
+ (NSArray<NSString *> *)directions;
+ (NSArray<NSString *> *)pushDirections;

@end

@interface MWMAction (Preview)
// Where a position puts a window, as fractions of the screen (x, y, width,
// height, top-left origin), or NO if it can't be worked out (it depends on the window).
+ (BOOL)previewForPositionText:(NSString *)text rect:(CGRect *)rect;

// For the text of a "move x;y w;h [screen]" or "push direction [style] [screen]" action: where it puts a window
// on a sample screen, as fractions of it, with a sample window for the names that mean the window.
// Returns NO with nil error for any other text; with an error in plain words when the text has a mistake.
+ (BOOL)getWindowRect:(CGRect *)rect forActionText:(NSString *)text applies:(BOOL *)applies error:(NSString * _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END
