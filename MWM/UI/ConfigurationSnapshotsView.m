//
//  ConfigurationSnapshotsView.m
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

#import "ConfigurationSnapshotsView.h"
#import "NSAlert+MWM.h"
#import "ConfigurationBlockView.h"
#import "MWMComponents.h"
#import "MWMTheme.h"
#import "MWMSnapshots.h"

#pragma mark - App icons

// The icon of an app by its name: the running app, or one in the usual folders; nil when it can't be found.
static NSImage *IconForApp(NSString *name) {
  static NSMutableDictionary *cache;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ cache = [NSMutableDictionary dictionary]; });
  id cached = cache[name];
  if (cached != nil) return cached == [NSNull null] ? nil : cached;
  NSImage *icon = nil;
  for (NSRunningApplication *app in [[NSWorkspace sharedWorkspace] runningApplications]) {
    if ([app.localizedName isEqualToString:name] && app.icon != nil) { icon = app.icon; break; }
  }
  if (icon == nil) {
    for (NSString *folder in @[@"/Applications", @"/System/Applications", @"/Applications/Utilities", @"/System/Applications/Utilities", [@"~/Applications" stringByExpandingTildeInPath]]) {
      NSString *path = [[folder stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"app"];
      if ([[NSFileManager defaultManager] fileExistsAtPath:path]) { icon = [[NSWorkspace sharedWorkspace] iconForFile:path]; break; }
    }
  }
  cache[name] = icon ?: [NSNull null];
  return icon;
}

#pragma mark - The picture

// The screens as they were, with each window on them drawn as a rectangle with its app's icon.
@interface ConfigurationSnapshotPicture : NSView
@property (strong) MWMSnapshotInfo *info;
@end

@implementation ConfigurationSnapshotPicture

- (NSSize)intrinsicContentSize { return NSMakeSize(NSViewNoIntrinsicMetric, 128); }

- (void)drawRect:(NSRect)dirtyRect {
  MWMSnapshotInfo *info = self.info;
  if (info == nil) return;
  NSBezierPath *well = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect([self bounds], 0.5, 0.5) xRadius:MWMRadiusS + 2 yRadius:MWMRadiusS + 2];
  [[MWMTheme surface] setFill];
  [well fill];
  [[MWMTheme stroke] setStroke];
  [well setLineWidth:1];
  [well stroke];
  CGRect world = CGRectNull;
  for (MWMSnapshotScreen *screen in info.screens) world = CGRectUnion(world, screen.rect);
  if (CGRectIsNull(world)) for (MWMSnapshotWindow *window in info.windows) world = CGRectUnion(world, window.rect);
  if (CGRectIsNull(world) || world.size.width < 1 || world.size.height < 1) return;

  NSRect area = NSInsetRect([self bounds], 6, 6);
  CGFloat scale = MIN(NSWidth(area) / world.size.width, NSHeight(area) / world.size.height);
  CGFloat width = world.size.width * scale, height = world.size.height * scale;
  CGFloat originX = NSMidX(area) - width / 2, originY = NSMidY(area) + height / 2;   // top of the picture (this view is not flipped)
  NSRect (^place)(CGRect) = ^NSRect(CGRect r) {
    return NSMakeRect(originX + (r.origin.x - world.origin.x) * scale, originY - (r.origin.y - world.origin.y + r.size.height) * scale, r.size.width * scale, r.size.height * scale);
  };

  for (MWMSnapshotScreen *screen in info.screens) {
    NSBezierPath *frame = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(place(screen.rect), 0.5, 0.5) xRadius:4 yRadius:4];
    [[MWMTheme surface] setFill];
    [frame fill];
    [[MWMTheme stroke] setStroke];
    [frame setLineWidth:1];
    if (!screen.connected) { CGFloat dash[] = {3, 2}; [frame setLineDash:dash count:2 phase:0]; }
    [frame stroke];
  }
  for (MWMSnapshotWindow *window in info.windows) {
    NSRect rect = NSInsetRect(place(window.rect), 1, 1);
    if (NSWidth(rect) < 3 || NSHeight(rect) < 3) continue;
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:3 yRadius:3];
    [[MWMTheme tint:[MWMTheme accent] opacity:0.22] setFill];
    [path fill];
    [[MWMTheme tint:[MWMTheme accent] opacity:0.7] setStroke];
    [path setLineWidth:1];
    [path stroke];
    CGFloat side = MIN(MIN(NSWidth(rect), NSHeight(rect)) * 0.6, 26);
    if (side < 9) continue;
    NSRect box = NSMakeRect(NSMidX(rect) - side / 2, NSMidY(rect) - side / 2, side, side);
    NSImage *icon = IconForApp(window.app);
    if (icon != nil) {
      [icon drawInRect:box fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    } else {
      NSString *letter = [[window.app length] > 0 ? [window.app substringToIndex:1] : @"?" uppercaseString];
      NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:side * 0.6 weight:NSFontWeightSemibold], NSForegroundColorAttributeName: [MWMTheme accent]};
      NSSize size = [letter sizeWithAttributes:attributes];
      [letter drawAtPoint:NSMakePoint(NSMidX(box) - size.width / 2, NSMidY(box) - size.height / 2) withAttributes:attributes];
    }
  }
}

@end

#pragma mark - Page

@interface ConfigurationSnapshotsView () <NSTextFieldDelegate>
@property (strong) NSTextField *nameField;
@property (strong) NSButton *saveButton;
@property (strong) NSStackView *rows;
@property (copy) NSArray<MWMSnapshotInfo *> *snapshots;
@end

@implementation ConfigurationSnapshotsView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _confirmsDeleting = YES;
    _snapshots = @[];
    [self buildInterface];
    [self reload];
    // Snapshots saved from the menu bar or by a shortcut show up here too.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(snapshotsChanged:) name:MWMSnapshotsDidChangeNotification object:nil];
  }
  return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)snapshotsChanged:(NSNotification *)note {
  if (self.window == nil) return;   // not on screen: it reloads when shown
  [self reload];
  [self.delegate snapshotsViewDidChange:self];
}

- (void)buildInterface {
  self.nameField = [NSTextField textFieldWithString:@""];
  [self.nameField setDelegate:self];
  [self.nameField setIdentifier:@"snapshot-name"];
  [self.nameField setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  self.saveButton = [MWMComponents accentButtonWithTitle:@"Save" symbol:@"camera" target:self action:@selector(savePressed:)];
  [self.saveButton setIdentifier:@"snapshot-save"];
  [self.saveButton setToolTip:@"Record where every open window is right now"];

  self.rows = [NSStackView stackViewWithViews:@[]];
  [self.rows setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [self.rows setAlignment:NSLayoutAttributeLeading];
  [self.rows setSpacing:MWMSpacingM];
  [self.rows setEdgeInsets:NSEdgeInsetsMake(8, MWMSpacingXL, MWMSpacingXL, MWMSpacingXL)];
  NSScrollView *scroll = [MWMComponents scrollViewWithContent:self.rows];
  [self addSubview:scroll];
  [MWMComponents pinView:scroll toEdgesOf:self insets:NSEdgeInsetsMake(0, 0, 0, 0)];
}

#pragma mark - Rows

- (NSImageView *)iconViewForApp:(NSString *)app size:(CGFloat)size {
  NSImage *icon = IconForApp(app);
  NSImageView *view = [NSImageView imageViewWithImage:icon ?: [NSImage imageWithSystemSymbolName:@"app" accessibilityDescription:app]];
  [view setToolTip:app];
  [view setTranslatesAutoresizingMaskIntoConstraints:NO];
  [NSLayoutConstraint activateConstraints:@[[view.widthAnchor constraintEqualToConstant:size], [view.heightAnchor constraintEqualToConstant:size]]];
  return view;
}

// "4 windows · kept · screen missing", the missing part in the warning color.
- (NSAttributedString *)infoTextFor:(MWMSnapshotInfo *)info {
  NSUInteger count = [info windowCount];
  NSMutableString *text = [NSMutableString stringWithFormat:@"%lu window%@", (unsigned long)count, count == 1 ? @"" : @"s"];
  if (info.keepAfterRestart) [text appendString:@" · kept"];
  NSMutableParagraphStyle *centered = [[NSMutableParagraphStyle alloc] init];
  [centered setAlignment:NSTextAlignmentCenter];
  NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName: [MWMTheme fontCaption], NSForegroundColorAttributeName: [MWMTheme textTertiary], NSParagraphStyleAttributeName: centered}];
  if (!info.allScreensConnected) {
    [attributed appendAttributedString:[[NSAttributedString alloc] initWithString:@" · screen missing" attributes:@{NSFontAttributeName: [MWMTheme fontCaption], NSForegroundColorAttributeName: [MWMTheme warning], NSParagraphStyleAttributeName: centered}]];
  }
  return attributed;
}

// A card: the name and its actions on top (Restore, keep, menu), the screens and windows centered below,
// and one quiet line of information.
- (NSView *)cardForSnapshot:(MWMSnapshotInfo *)info {
  NSString *name = info.name;
  NSMutableArray *top = [NSMutableArray arrayWithObject:[MWMComponents labelWithText:name font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]]];
  if (info.isLaptop) [top addObject:[MWMChipView chipWithText:@"Laptop" color:[MWMTheme accent]]];
  [top addObject:[MWMComponents spacer]];

  NSButton *restore = [MWMComponents accentButtonWithTitle:@"Restore" symbol:@"play.fill" target:self action:@selector(restorePressed:)];
  [restore setIdentifier:[@"restore-" stringByAppendingString:name]];
  [restore setToolTip:@"Put every window back where it was"];

  NSButton *pin = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:info.keepAfterRestart ? @"pin.fill" : @"pin" accessibilityDescription:@"Keep after restart"] target:self action:@selector(pinPressed:)];
  [pin setBordered:NO];
  [pin setContentTintColor:info.keepAfterRestart ? [MWMTheme accent] : [MWMTheme textTertiary]];
  [pin setIdentifier:[@"keep-" stringByAppendingString:name]];
  [pin setToolTip:info.keepAfterRestart ? @"Kept after restart. Click to forget it when MWM quits." : @"Click to keep it after restart."];

  NSButton *more = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"ellipsis" accessibilityDescription:@"More"] target:self action:@selector(morePressed:)];
  [more setBordered:NO];
  [more setContentTintColor:[MWMTheme textSecondary]];
  [more setIdentifier:name];
  [top addObjectsFromArray:@[restore, pin, more]];
  NSStackView *header = [NSStackView stackViewWithViews:top];
  [header setSpacing:MWMSpacingS];
  [header setAlignment:NSLayoutAttributeCenterY];

  ConfigurationSnapshotPicture *picture = [[ConfigurationSnapshotPicture alloc] init];
  picture.info = info;
  [picture setToolTip:info.screensText];
  [picture setTranslatesAutoresizingMaskIntoConstraints:NO];
  [[picture.heightAnchor constraintEqualToConstant:128] setActive:YES];

  NSTextField *infoLine = [NSTextField labelWithAttributedString:[self infoTextFor:info]];
  [infoLine setAlignment:NSTextAlignmentCenter];
  [infoLine setIdentifier:@"snapshot-info"];

  NSStackView *column = [NSStackView stackViewWithViews:@[header, picture, infoLine]];
  [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [column setAlignment:NSLayoutAttributeLeading];
  [column setSpacing:MWMSpacingM];
  [[header.widthAnchor constraintEqualToAnchor:column.widthAnchor] setActive:YES];
  [[picture.widthAnchor constraintEqualToAnchor:column.widthAnchor] setActive:YES];
  [[infoLine.widthAnchor constraintEqualToAnchor:column.widthAnchor] setActive:YES];

  NSView *card = [MWMComponents card];
  [card setIdentifier:[@"snapshot-" stringByAppendingString:name]];
  [card addSubview:column];
  [MWMComponents pinView:column toEdgesOf:card insets:NSEdgeInsetsMake(MWMSpacingM, MWMSpacingL, MWMSpacingM, MWMSpacingM + 2)];
  return card;
}

// The place to make the next snapshot: a live picture of the windows as they are now, a name, and Save.
// It stays at the end of the grid, so the page looks the same with none, one or many snapshots.
- (NSView *)newSnapshotCard {
  NSButton *refresh = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:@"Look at the windows again"] target:self action:@selector(refreshPressed:)];
  [refresh setBordered:NO];
  [refresh setContentTintColor:[MWMTheme textTertiary]];
  [refresh setToolTip:@"Look at the windows again"];
  [refresh setIdentifier:@"snapshot-refresh"];
  NSStackView *header = [NSStackView stackViewWithViews:@[[MWMComponents labelWithText:@"New snapshot" font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]], [MWMComponents spacer],
                                                          [MWMComponents captionLabel:@"your windows now"], refresh]];
  [header setSpacing:MWMSpacingS];
  [header setAlignment:NSLayoutAttributeCenterY];

  ConfigurationSnapshotPicture *picture = [[ConfigurationSnapshotPicture alloc] init];
  picture.info = [MWMSnapshots currentWindows];
  [picture setToolTip:@"What would be saved: the open windows on your screens"];
  [picture setIdentifier:@"snapshot-live"];
  [picture setTranslatesAutoresizingMaskIntoConstraints:NO];
  [[picture.heightAnchor constraintEqualToConstant:128] setActive:YES];

  [self.nameField setPlaceholderString:[self suggestedName]];
  NSStackView *form = [NSStackView stackViewWithViews:@[self.nameField, self.saveButton]];
  [form setSpacing:MWMSpacingS];
  [form setAlignment:NSLayoutAttributeCenterY];

  NSStackView *column = [NSStackView stackViewWithViews:@[header, picture, form]];
  [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [column setAlignment:NSLayoutAttributeLeading];
  [column setSpacing:MWMSpacingM];
  for (NSView *view in @[header, picture, form]) [[view.widthAnchor constraintEqualToAnchor:column.widthAnchor] setActive:YES];

  NSView *card = [MWMComponents dashedCard];
  [card setIdentifier:@"snapshot-new"];
  [card addSubview:column];
  [MWMComponents pinView:column toEdgesOf:card insets:NSEdgeInsetsMake(MWMSpacingM + 2, MWMSpacingL, MWMSpacingM + 2, MWMSpacingL)];
  return card;
}

- (void)refreshPressed:(id)sender { [self reload]; }

- (void)reload {
  self.snapshots = [MWMSnapshots snapshots];
  for (NSView *view in [[self.rows arrangedSubviews] copy]) {
    [self.rows removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  // Two cards to a row: the snapshots, then the new-snapshot card. With none yet, a few words fill the empty half.
  NSMutableArray *cards = [NSMutableArray array];
  for (MWMSnapshotInfo *info in self.snapshots) [cards addObject:[self cardForSnapshot:info]];
  [cards addObject:[self newSnapshotCard]];
  if ([self.snapshots count] == 0) {
    NSTextField *intro = [MWMComponents wrappingLabelWithText:@"No snapshots yet.\n\nArrange your windows, name this one and save it. Then restore it any time, or give it a shortcut." size:13 color:[MWMTheme textTertiary] weight:NSFontWeightRegular];
    [intro setIdentifier:@"snapshots-empty"];
    NSView *holder = [[NSView alloc] init];
    [holder setTranslatesAutoresizingMaskIntoConstraints:NO];
    [holder addSubview:intro];
    [intro setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[
      [intro.leadingAnchor constraintEqualToAnchor:holder.leadingAnchor constant:MWMSpacingXL + 4], [intro.trailingAnchor constraintEqualToAnchor:holder.trailingAnchor constant:-MWMSpacingXL],
      [intro.centerYAnchor constraintEqualToAnchor:holder.centerYAnchor],
    ]];
    [cards addObject:holder];
  }
  for (NSUInteger i = 0; i < [cards count]; i += 2) {
    NSView *right = i + 1 < [cards count] ? cards[i + 1] : [[NSView alloc] init];
    NSStackView *pair = [NSStackView stackViewWithViews:@[cards[i], right]];
    [pair setSpacing:MWMSpacingM];
    [pair setDistribution:NSStackViewDistributionFillEqually];
    [pair setAlignment:NSLayoutAttributeTop];
    [self.rows addArrangedSubview:pair];
    [[pair.widthAnchor constraintEqualToAnchor:self.rows.widthAnchor constant:-2 * MWMSpacingXL] setActive:YES];
  }
  [self updateSaveButton];
}

- (NSString *)suggestedName {
  NSArray *taken = [self.snapshots valueForKey:@"name"];
  for (NSUInteger i = 1;; i++) {
    NSString *name = [NSString stringWithFormat:@"snapshot%lu", (unsigned long)i];
    if (![taken containsObject:name]) return name;
  }
}

- (void)updateSaveButton {
  NSString *name = [[self.nameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *problem = [name length] == 0 ? nil : [MWMSnapshots problemWithName:name except:nil];
  [self.saveButton setEnabled:problem == nil];
  [self.saveButton setToolTip:problem ?: @"Record where every open window is right now"];
}

- (void)controlTextDidChange:(NSNotification *)note { [self updateSaveButton]; }

#pragma mark - Actions

- (void)saveCurrentWindowsAs:(NSString *)name {
  NSString *trimmed = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([trimmed length] == 0) trimmed = [self suggestedName];
  if ([MWMSnapshots problemWithName:trimmed except:nil] != nil) return;
  if (![MWMSnapshots saveCurrentWindowsAs:trimmed keepAfterRestart:YES]) return;
  [self.nameField setStringValue:@""];
  [self reload];
  [self.delegate snapshotsViewDidChange:self];
}

- (void)savePressed:(id)sender { [self saveCurrentWindowsAs:[self.nameField stringValue]]; }

- (void)restoreNamed:(NSString *)name { [MWMSnapshots restoreName:name]; }
- (void)restorePressed:(NSButton *)button { [self restoreNamed:[self nameFromIdentifier:button.identifier prefix:@"restore-"]]; }

- (NSString *)nameFromIdentifier:(NSString *)identifier prefix:(NSString *)prefix {
  return [identifier hasPrefix:prefix] ? [identifier substringFromIndex:[prefix length]] : identifier;
}

- (void)setKeep:(BOOL)keep forName:(NSString *)name {
  [MWMSnapshots setKeepAfterRestart:keep forName:name];
  [self reload];
}

- (void)pinPressed:(NSButton *)button {
  NSString *name = [self nameFromIdentifier:button.identifier prefix:@"keep-"];
  for (MWMSnapshotInfo *info in self.snapshots) if ([info.name isEqualToString:name]) { [self setKeep:!info.keepAfterRestart forName:name]; return; }
}

- (void)updateNamed:(NSString *)name {
  if (![MWMSnapshots updateName:name]) return;
  [self reload];
  [self.delegate snapshotsViewDidChange:self];
}

- (void)deleteNamed:(NSString *)name {
  if (self.confirmsDeleting) {
    NSAlert *alert = [NSAlert mwm_alert];
    [alert setMessageText:[NSString stringWithFormat:@"Delete \"%@\"?", name]];
    [alert setInformativeText:@"The saved window arrangement is removed. A shortcut that restores it will do nothing."];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Delete"];
    if ([alert runModal] == NSAlertFirstButtonReturn) return;
  }
  [MWMSnapshots deleteName:name];
  [self reload];
  [self.delegate snapshotsViewDidChange:self];
}

- (void)renameNamed:(NSString *)name {
  NSAlert *alert = [NSAlert mwm_alert];
  [alert setMessageText:@"Rename snapshot"];
  [alert setInformativeText:@"Shortcuts that use the old name need the new one."];
  NSTextField *field = [NSTextField textFieldWithString:name];
  [field setFrame:NSMakeRect(0, 0, 240, 24)];
  [alert setAccessoryView:field];
  [alert mwm_widen];
  [alert addButtonWithTitle:@"Rename"];
  [alert addButtonWithTitle:@"Cancel"];
  if ([alert runModal] != NSAlertFirstButtonReturn) return;
  NSString *problem = [MWMSnapshots problemWithName:[field stringValue] except:name];
  if (problem != nil) {
    NSAlert *failed = [NSAlert mwm_alert];
    [failed setMessageText:problem];
    [failed runModal];
    return;
  }
  [MWMSnapshots renameFrom:name to:[field stringValue]];
  [self reload];
  [self.delegate snapshotsViewDidChange:self];
}

- (void)morePressed:(NSButton *)button {
  NSString *name = button.identifier;
  BOOL kept = NO;
  for (MWMSnapshotInfo *info in self.snapshots) if ([info.name isEqualToString:name]) kept = info.keepAfterRestart;
  NSMenu *menu = [[NSMenu alloc] init];
  NSMenuItem *keep = [menu addItemWithTitle:@"Keep after restart" action:@selector(keepChosen:) keyEquivalent:@""];
  [keep setState:kept ? NSControlStateValueOn : NSControlStateValueOff];
  NSMenuItem *rename = [menu addItemWithTitle:@"Rename…" action:@selector(renameChosen:) keyEquivalent:@""];
  NSMenuItem *update = [menu addItemWithTitle:@"Update with current windows" action:@selector(updateChosen:) keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem *delete = [menu addItemWithTitle:@"Delete…" action:@selector(deleteChosen:) keyEquivalent:@""];
  for (NSMenuItem *item in @[keep, rename, update, delete]) { [item setTarget:self]; [item setRepresentedObject:name]; }
  [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, NSHeight(button.bounds) + 4) inView:button];
}

- (void)keepChosen:(NSMenuItem *)item {
  NSString *name = item.representedObject;
  for (MWMSnapshotInfo *info in self.snapshots) if ([info.name isEqualToString:name]) { [self setKeep:!info.keepAfterRestart forName:name]; return; }
}
- (void)renameChosen:(NSMenuItem *)item { [self renameNamed:item.representedObject]; }
- (void)updateChosen:(NSMenuItem *)item { [self updateNamed:item.representedObject]; }
- (void)deleteChosen:(NSMenuItem *)item { [self deleteNamed:item.representedObject]; }

@end
