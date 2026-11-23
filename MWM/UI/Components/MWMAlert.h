//
//  MWMAlert.h
//  Slate
//
//  The reusable pieces of the configuration window, built from MWMTheme: labels,
//  cards, chips, icon tiles, separators and buttons. Pages ask for these instead
//  of assembling them again.
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// What an alert is about; it sets the color and symbol of the tile at its left.
typedef NS_ENUM(NSInteger, MWMAlertKind) {
  MWMAlertKindInfo,      // news and answers
  MWMAlertKindConfirm,   // a question before something is lost or changed
  MWMAlertKindDanger,    // a question before something is deleted
  MWMAlertKindWarning,   // something went wrong or needs attention
  MWMAlertKindSuccess,
};

// The one design for every alert and confirmation: a tile for the kind, a title, a sentence, optional
// controls, and buttons. It answers like NSAlert does: the first button added is the
// default (on the right, answering Return) and returns NSAlertFirstButtonReturn, the next one the second.
@interface MWMAlert : NSObject
@property (assign) MWMAlertKind kind;
// The app's icon centered above centered text, as in the About window, instead of the tile for the kind.
@property (assign) BOOL showsAppIcon;
@property (copy, nullable) NSString *messageText;
@property (copy, nullable) NSString *informativeText;
@property (strong, nullable) NSView *accessoryView;           // a field or fields under the text; as wide as the alert
@property (readonly) NSPanel *window;

+ (instancetype)alert;
- (NSButton *)addButtonWithTitle:(NSString *)title;
// A button for an action that deletes or removes, in red.
- (NSButton *)addDestructiveButtonWithTitle:(NSString *)title;
// For a window that stays up while something happens: shown without waiting, closed by dismiss. A button
// calls the handler instead of ending a modal run.
@property (copy, nullable) void (^buttonHandler)(NSModalResponse response);
- (void)show;
- (void)dismiss;
- (NSModalResponse)runModal;
- (void)beginSheetModalForWindow:(NSWindow *)window completionHandler:(nullable void (^)(NSModalResponse response))handler;

// A problem found while loading the configuration or running an action: what it is, and where, with Quit and
// Skip. Returns YES when the user chose Quit.
+ (BOOL)quitOrSkipAfterProblem:(NSString *)name reason:(nullable NSString *)reason context:(nullable NSString *)context;
@end

NS_ASSUME_NONNULL_END
