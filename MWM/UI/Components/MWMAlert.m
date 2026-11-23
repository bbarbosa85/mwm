//
//  MWMAlert.m
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

#import "MWMAlert.h"
#import "MWMComponents.h"
#import "MWMTheme.h"

static const CGFloat kAlertWidth = 440;
static const CGFloat kPadding = 22;

@interface MWMAlert ()
@property (strong) NSPanel *panel;
@property (strong) NSMutableArray<NSButton *> *buttons;
@property (weak) NSWindow *sheetParent;
@end

@implementation MWMAlert

+ (instancetype)alert {
  MWMAlert *alert = [[MWMAlert alloc] init];
  alert.buttons = [NSMutableArray array];
  return alert;
}

#pragma mark - Buttons

- (NSButton *)addButton:(NSButton *)button {
  NSUInteger index = [self.buttons count];
  [button setTag:NSAlertFirstButtonReturn + (NSInteger)index];
  [button setTarget:self];
  [button setAction:@selector(buttonPressed:)];
  if (index == 0) [button setKeyEquivalent:@"\r"];
  else if ([[button title] isEqualToString:@"Cancel"]) [button setKeyEquivalent:@"\e"];
  [self.buttons addObject:button];
  return button;
}

- (NSButton *)addButtonWithTitle:(NSString *)title {
  return [self addButton:[MWMComponents secondaryButtonWithTitle:title target:nil action:nil]];
}

- (NSButton *)addDestructiveButtonWithTitle:(NSString *)title {
  return [self addButton:[MWMComponents dangerButtonWithTitle:title target:nil action:nil]];
}

- (void)buttonPressed:(NSButton *)button {
  NSModalResponse response = (NSModalResponse)[button tag];
  if (self.buttonHandler != nil) { self.buttonHandler(response); return; }
  if (self.sheetParent != nil) [self.sheetParent endSheet:self.panel returnCode:response];
  else [NSApp stopModalWithCode:response];
}

#pragma mark - Layout

- (NSString *)symbol {
  switch (self.kind) {
    case MWMAlertKindInfo: return @"info";
    case MWMAlertKindConfirm: return @"questionmark";
    case MWMAlertKindDanger: return @"trash";
    case MWMAlertKindWarning: return @"exclamationmark.triangle";
    case MWMAlertKindSuccess: return @"checkmark";
  }
}

- (NSColor *)color {
  switch (self.kind) {
    case MWMAlertKindInfo: case MWMAlertKindConfirm: return [MWMTheme accent];
    case MWMAlertKindDanger: return [MWMTheme danger];
    case MWMAlertKindWarning: return [MWMTheme warning];
    case MWMAlertKindSuccess: return [MWMTheme success];
  }
}

- (NSPanel *)window {
  if (self.panel != nil) return self.panel;
  if ([self.buttons count] == 0) [self addButtonWithTitle:@"OK"];
  CGFloat textWidth = kAlertWidth - 2 * kPadding - 36 - MWMSpacingM;
  NSMutableArray *texts = [NSMutableArray array];
  NSTextField *title = [MWMComponents wrappingLabelWithText:self.messageText ?: @"" size:14 color:[MWMTheme textPrimary] weight:NSFontWeightSemibold];
  [title setPreferredMaxLayoutWidth:textWidth];
  [texts addObject:title];
  if ([self.informativeText length] > 0) {
    NSTextField *body = [MWMComponents wrappingLabelWithText:self.informativeText size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
    [body setPreferredMaxLayoutWidth:textWidth];
    [texts addObject:body];
  }
  NSStackView *header;
  if (self.showsAppIcon) {
    // The icon above, and the text centered under it, across the alert's whole width.
    textWidth = kAlertWidth - 2 * kPadding;
    for (NSTextField *text in texts) { [text setAlignment:NSTextAlignmentCenter]; [text setPreferredMaxLayoutWidth:textWidth]; }
    NSImage *icon = [[NSBundle mainBundle] imageForResource:@"icon"] ?: [NSApp applicationIconImage];
    NSImageView *iconView = [NSImageView imageViewWithImage:icon];
    [iconView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [iconView setIdentifier:@"alert-app-icon"];
    [[iconView.widthAnchor constraintEqualToConstant:64] setActive:YES];
    [[iconView.heightAnchor constraintEqualToConstant:64] setActive:YES];
    NSStackView *textColumn = [NSStackView stackViewWithViews:texts];
    [textColumn setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [textColumn setAlignment:NSLayoutAttributeCenterX];
    [textColumn setSpacing:4];
    header = [NSStackView stackViewWithViews:@[iconView, textColumn]];
    [header setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [header setAlignment:NSLayoutAttributeCenterX];
    [header setSpacing:MWMSpacingM];
    [[textColumn.widthAnchor constraintEqualToConstant:textWidth] setActive:YES];
  } else {
    NSStackView *textColumn = [MWMComponents columnWithViews:texts spacing:4 insets:NSEdgeInsetsZero];
    NSView *tile = [MWMComponents iconTileWithSymbol:[self symbol] color:[self color] size:36];
    header = [NSStackView stackViewWithViews:@[tile, textColumn]];
    [header setSpacing:MWMSpacingM];
    [header setAlignment:NSLayoutAttributeTop];
    [[textColumn.widthAnchor constraintEqualToConstant:textWidth] setActive:YES];
  }

  NSMutableArray *rows = [NSMutableArray arrayWithObject:header];
  if (self.accessoryView != nil) {
    [self.accessoryView setTranslatesAutoresizingMaskIntoConstraints:NO];
    // A view laid out by frames has no height of its own to give.
    if ([self.accessoryView intrinsicContentSize].height == NSViewNoIntrinsicMetric) [[self.accessoryView.heightAnchor constraintEqualToConstant:NSHeight(self.accessoryView.frame)] setActive:YES];
    [rows addObject:self.accessoryView];
  }
  NSMutableArray *buttonViews = [NSMutableArray array];
  [buttonViews addObject:[MWMComponents spacer]];
  for (NSButton *button in [self.buttons reverseObjectEnumerator]) [buttonViews addObject:button];
  NSStackView *buttonRow = [NSStackView stackViewWithViews:buttonViews];
  [buttonRow setSpacing:MWMSpacingS];
  [buttonRow setAlignment:NSLayoutAttributeCenterY];
  [rows addObject:buttonRow];

  NSStackView *content = [MWMComponents columnWithViews:rows spacing:MWMSpacingL insets:NSEdgeInsetsMake(kPadding, kPadding, MWMSpacingL + 2, kPadding)];
  [[content.widthAnchor constraintEqualToConstant:kAlertWidth] setActive:YES];
  [content setTranslatesAutoresizingMaskIntoConstraints:NO];

  NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, kAlertWidth, 200) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskFullSizeContentView backing:NSBackingStoreBuffered defer:YES];
  [panel setTitlebarAppearsTransparent:YES];
  [panel setTitleVisibility:NSWindowTitleHidden];
  [[panel standardWindowButton:NSWindowCloseButton] setHidden:YES];
  [[panel standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];
  [[panel standardWindowButton:NSWindowZoomButton] setHidden:YES];
  [panel setMovableByWindowBackground:YES];
  [panel setReleasedWhenClosed:NO];
  NSView *holder = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, kAlertWidth, 200)];
  [holder addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [content.topAnchor constraintEqualToAnchor:holder.topAnchor constant:MWMSpacingS], [content.leadingAnchor constraintEqualToAnchor:holder.leadingAnchor],
  ]];
  [panel setContentView:holder];
  [holder layoutSubtreeIfNeeded];
  [panel setContentSize:NSMakeSize(kAlertWidth, [content fittingSize].height + MWMSpacingS)];
  self.panel = panel;
  return panel;
}

#pragma mark - Showing

- (void)show {
  NSPanel *panel = [self window];
  [panel center];
  [NSApp activateIgnoringOtherApps:YES];
  [panel makeKeyAndOrderFront:nil];
}

- (void)dismiss {
  [self.panel orderOut:nil];
}

- (NSModalResponse)runModal {
  NSPanel *panel = [self window];
  self.sheetParent = nil;
  [panel center];
  [NSApp activateIgnoringOtherApps:YES];
  NSModalResponse response = [NSApp runModalForWindow:panel];
  [panel orderOut:nil];
  return response;
}

- (void)beginSheetModalForWindow:(NSWindow *)parent completionHandler:(void (^)(NSModalResponse))handler {
  NSPanel *panel = [self window];
  self.sheetParent = parent;
  [parent beginSheet:panel completionHandler:^(NSModalResponse response) {
    [panel orderOut:nil];
    if (handler) handler(response);
  }];
}

#pragma mark - Problems

+ (BOOL)quitOrSkipAfterProblem:(NSString *)name reason:(NSString *)reason context:(NSString *)context {
  MWMAlert *alert = [MWMAlert alert];
  alert.kind = MWMAlertKindWarning;
  alert.messageText = name;
  NSMutableArray *lines = [NSMutableArray array];
  if ([context length] > 0) [lines addObject:context];
  if ([reason length] > 0) [lines addObject:reason];
  alert.informativeText = [lines componentsJoinedByString:@"\n"];
  [[alert addButtonWithTitle:@"Quit"] setKeyEquivalent:@"q"];
  [[alert addButtonWithTitle:@"Skip"] setKeyEquivalent:@"s"];
  return [alert runModal] == NSAlertFirstButtonReturn;
}

@end
