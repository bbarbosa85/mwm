//
//  ConfigurationProfilesView.m
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

#import "ConfigurationProfilesView.h"
#import "MWMAlert.h"
#import "MWMComponents.h"
#import "MWMConfigDocument.h"
#import "MWMProfiles.h"
#import "MWMLegacyMigration.h"
#import "MWMTheme.h"

@interface ConfigurationProfilesView () <NSTextFieldDelegate>
@property (strong) NSStackView *rows;
@property (strong) NSTextField *nameField;
@property (copy, nullable) NSString *problem;
@property (assign) ConfigurationProfilesMode mode;
@property (copy, nullable) NSString *draftText;
@property (copy, nullable) NSString *draftFrom;
@property (assign) BOOL draftFromCard;
@end

@implementation ConfigurationProfilesView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _interactive = YES;
    _nameField = [MWMNameField nameFieldWithPlaceholder:@"Name" identifier:@"profile-new-name" compact:NO];
    _rows = [NSStackView stackViewWithViews:@[]];
    [_rows setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [_rows setAlignment:NSLayoutAttributeLeading];
    [_rows setSpacing:MWMSpacingM];
    [_rows setEdgeInsets:NSEdgeInsetsMake(8, MWMSpacingXL, MWMSpacingXL, MWMSpacingXL)];
    NSScrollView *scroll = [MWMComponents scrollViewWithContent:_rows];
    [self addSubview:scroll];
    [MWMComponents pinView:scroll toEdgesOf:self insets:NSEdgeInsetsMake(0, 0, 0, 0)];
    [self reload];
  }
  return self;
}

#pragma mark - Page

- (NSButton *)iconButton:(NSString *)symbol tip:(NSString *)tip identifier:(NSString *)identifier action:(SEL)action enabled:(BOOL)enabled {
  NSButton *button = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:tip] target:self action:action];
  [button setBordered:NO];
  [button setContentTintColor:[MWMTheme textSecondary]];
  [button setIdentifier:identifier];
  [button setToolTip:tip];
  [button setEnabled:enabled];
  return button;
}

// The profile the window shows: the running one unless another was chosen and not applied yet.
- (NSString *)editing { return self.editingName ?: [MWMProfiles activeName]; }

- (void)setEditingName:(NSString *)editingName { _editingName = [editingName copy]; [self reload]; }

- (NSView *)cardForName:(NSString *)name active:(BOOL)active only:(BOOL)only {
  BOOL editing = [name caseInsensitiveCompare:[self editing]] == NSOrderedSame;
  NSMutableArray *top = [NSMutableArray arrayWithObject:[MWMComponents labelWithText:name font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]]];
  if (active) {
    MWMChipView *chip = [MWMChipView chipWithText:@"Active" color:[MWMTheme success]];
    [chip setIdentifier:@"profile-active"];
    [top addObject:chip];
  }
  if (editing && !active) {
    MWMChipView *pending = [MWMChipView chipWithText:@"Editing · not applied" color:[MWMTheme warning]];
    [pending setIdentifier:@"profile-pending"];
    [top addObject:pending];
  }
  [top addObject:[MWMComponents spacer]];
  NSButton *use = [MWMComponents secondaryButtonWithTitle:@"Use" target:self action:@selector(usePressed:)];
  [use setIdentifier:[@"use-" stringByAppendingString:name]];
  [use setEnabled:!editing];
  [use setToolTip:editing ? @"This is the profile being edited" : @"Edit this profile. MWM switches to it when you press Apply and Restart."];
  [top addObject:use];
  [top addObject:[self iconButton:@"doc.on.doc" tip:@"Duplicate" identifier:[@"duplicate-" stringByAppendingString:name] action:@selector(duplicatePressed:) enabled:YES]];
  [top addObject:[self iconButton:@"pencil" tip:@"Rename" identifier:[@"rename-" stringByAppendingString:name] action:@selector(renamePressed:) enabled:YES]];
  BOOL canDelete = !active && !editing && !only;
  [top addObject:[self iconButton:@"trash" tip:active ? @"The active profile can't be deleted" : (editing ? @"This profile is being edited" : @"Delete") identifier:[@"delete-" stringByAppendingString:name] action:@selector(deletePressed:) enabled:canDelete]];
  NSStackView *header = [NSStackView stackViewWithViews:top];
  [header setSpacing:MWMSpacingM];
  [header setAlignment:NSLayoutAttributeCenterY];

  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setLocalizedDateFormatFromTemplate:@"d MMM yyyy"];
  NSDate *date = [MWMProfiles modificationDateForName:name];
  NSString *file = [[MWMProfiles pathForName:name] lastPathComponent];
  NSTextField *detail = [MWMComponents secondaryLabel:date ? [NSString stringWithFormat:@"%@ · edited %@", file, [formatter stringFromDate:date]] : file];
  [detail setIdentifier:@"profile-file"];

  NSStackView *column = [NSStackView stackViewWithViews:@[header, detail]];
  [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [column setAlignment:NSLayoutAttributeLeading];
  [column setSpacing:MWMSpacingS];
  [[header.widthAnchor constraintEqualToAnchor:column.widthAnchor] setActive:YES];
  NSView *card = [MWMComponents card];
  [card setIdentifier:[@"profile-" stringByAppendingString:name]];
  [card addSubview:column];
  [MWMComponents pinView:column toEdgesOf:card insets:NSEdgeInsetsMake(MWMSpacingL, MWMSpacingL, MWMSpacingL, MWMSpacingL)];
  return card;
}

// One of the three ways to add a profile (or one profile to copy): the whole card is the button.
- (NSView *)optionWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle identifier:(NSString *)identifier action:(SEL)action {
  NSView *tile = [MWMComponents iconTileWithSymbol:symbol color:[MWMTheme accent] size:28];
  NSTextField *titleLabel = [MWMComponents labelWithText:title font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]];
  NSTextField *subtitleLabel = [MWMComponents wrappingLabelWithText:subtitle size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
  NSStackView *column = [NSStackView stackViewWithViews:@[tile, titleLabel, subtitleLabel]];
  [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [column setAlignment:NSLayoutAttributeLeading];
  [column setSpacing:MWMSpacingS];
  NSView *card = [MWMComponents card];
  [card setIdentifier:[identifier stringByAppendingString:@"-card"]];
  [card addSubview:column];
  [MWMComponents pinView:column toEdgesOf:card insets:NSEdgeInsetsMake(MWMSpacingL, MWMSpacingL, MWMSpacingL, MWMSpacingL)];
  NSButton *hit = [NSButton buttonWithTitle:@"" target:self action:action];
  [hit setBordered:NO];
  [hit setTransparent:YES];
  [hit setIdentifier:identifier];
  [hit setToolTip:subtitle];
  [card addSubview:hit];
  [MWMComponents pinView:hit toEdgesOf:card insets:NSEdgeInsetsMake(0, 0, 0, 0)];
  return card;
}

- (NSView *)addHeader {
  NSButton *back = [MWMComponents secondaryButtonWithTitle:@"Back" symbol:@"arrow.left" target:self action:@selector(backPressed:)];
  [back setIdentifier:@"profile-add-back"];
  NSTextField *title = [MWMComponents labelWithText:@"Add profile" font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]];
  NSStackView *header = [NSStackView stackViewWithViews:@[back, title]];
  [header setSpacing:MWMSpacingM];
  [header setAlignment:NSLayoutAttributeCenterY];
  return header;
}

// Step 1: where the new profile comes from.
- (NSArray<NSView *> *)sourceViews {
  NSString *running = [MWMProfiles activeName];
  BOOL hasRunning = [MWMProfiles existsNamed:running];
  NSView *fromRunning = [self optionWithSymbol:@"play.circle" title:@"From what's running"
                                      subtitle:hasRunning ? [NSString stringWithFormat:@"A copy of “%@” as it is now", running] : @"Starts from the defaults"
                                    identifier:@"profile-source-running" action:@selector(sourceRunningPressed:)];
  NSView *duplicate = [self optionWithSymbol:@"doc.on.doc" title:@"Duplicate one" subtitle:@"Pick from your profiles" identifier:@"profile-source-duplicate" action:@selector(sourceDuplicatePressed:)];
  NSView *file = [self optionWithSymbol:@"square.and.arrow.down" title:@"From a file" subtitle:@"An example or a backup" identifier:@"profile-source-file" action:@selector(sourceFilePressed:)];
  NSMutableArray *views = [NSMutableArray arrayWithObject:[self addHeader]];
  NSStackView *row = [MWMComponents equalRowWithViews:@[fromRunning, duplicate, file] spacing:MWMSpacingM];
  [views addObject:row];
  return views;
}

// Step 1b: which profile to copy.
- (NSArray<NSView *> *)duplicateViews {
  NSMutableArray *views = [NSMutableArray arrayWithObject:[self addHeader]];
  [views addObject:[MWMComponents secondaryLabel:@"Which profile do you want a copy of?"]];
  for (NSString *name in [MWMProfiles names]) {
    [views addObject:[self optionWithSymbol:@"square.stack.3d.up" title:name subtitle:[[MWMProfiles pathForName:name] lastPathComponent] identifier:[@"profile-copy-" stringByAppendingString:name] action:@selector(copyOnePressed:)]];
  }
  return views;
}

// What a profile holds, in counts.
- (NSDictionary *)summaryForText:(NSString *)text {
  MWMConfigDocument *document = [MWMConfigDocument documentFromString:text lenient:YES error:nil];
  NSMutableArray *groups = [NSMutableArray array];
  for (MWMBindingEntry *binding in document.bindings) {
    if ([binding.group length] > 0 && ![groups containsObject:binding.group]) [groups addObject:binding.group];
  }
  return @{@"shortcuts": @([document.bindings count]), @"modifiers": @([document.modifiers count]), @"screens": @([document.monitors count]),
           @"slots": @([document.positions count]), @"settings": @([document.settings count]), @"groups": groups};
}

- (NSView *)countColumn:(NSString *)label count:(NSNumber *)count {
  NSTextField *number = [MWMComponents labelWithText:[count stringValue] size:15 color:[MWMTheme textPrimary] weight:NSFontWeightSemibold];
  NSStackView *column = [NSStackView stackViewWithViews:@[number, [MWMComponents secondaryLabel:label]]];
  [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [column setAlignment:NSLayoutAttributeLeading];
  [column setSpacing:MWMSpacingXS];
  return column;
}

// Step 2: the name, and a summary of what the new profile holds.
- (NSArray<NSView *> *)nameViews {
  NSMutableArray *views = [NSMutableArray arrayWithObject:[self addHeader]];
  NSTextField *from = [MWMComponents secondaryLabel:[NSString stringWithFormat:@"From: %@", self.draftFrom ?: @""]];
  [from setIdentifier:@"profile-draft-from"];
  [views addObject:from];
  [self.nameField setTarget:self];
  [self.nameField setAction:@selector(createPressed:)];
  [(MWMNameField *)self.nameField setInvalid:self.problem != nil];
  [views addObject:[MWMComponents nameBlockWithField:(MWMNameField *)self.nameField width:0]];
  if (self.problem != nil) {
    NSTextField *error = [MWMComponents wrappingLabelWithText:self.problem size:13 color:[MWMTheme danger] weight:NSFontWeightRegular];
    [error setIdentifier:@"profile-problem"];
    [views addObject:error];
  }
  NSDictionary *summary = [self summaryForText:self.draftText ?: @""];
  NSStackView *counts = [NSStackView stackViewWithViews:@[
    [self countColumn:@"shortcuts" count:summary[@"shortcuts"]], [self countColumn:@"modifiers" count:summary[@"modifiers"]],
    [self countColumn:@"screens" count:summary[@"screens"]], [self countColumn:@"slots" count:summary[@"slots"]],
    [self countColumn:@"settings" count:summary[@"settings"]], [MWMComponents spacer]]];
  [counts setSpacing:MWMSpacingXL];
  [counts setAlignment:NSLayoutAttributeTop];
  NSMutableArray *content = [NSMutableArray arrayWithObject:counts];
  NSArray *groups = summary[@"groups"];
  if ([groups count] > 0) {
    NSTextField *groupsLabel = [MWMComponents wrappingLabelWithText:[NSString stringWithFormat:@"Groups: %@", [groups componentsJoinedByString:@", "]] size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
    [groupsLabel setIdentifier:@"profile-draft-groups"];
    [content addObject:groupsLabel];
  }
  NSStackView *column = [NSStackView stackViewWithViews:content];
  [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [column setAlignment:NSLayoutAttributeLeading];
  [column setSpacing:MWMSpacingM];
  [[counts.widthAnchor constraintEqualToAnchor:column.widthAnchor] setActive:YES];
  NSView *card = [MWMComponents card];
  [card setIdentifier:@"profile-draft-summary"];
  [card addSubview:column];
  [MWMComponents pinView:column toEdgesOf:card insets:NSEdgeInsetsMake(MWMSpacingL, MWMSpacingL, MWMSpacingL, MWMSpacingL)];
  [views addObject:card];
  NSButton *cancel = [MWMComponents secondaryButtonWithTitle:@"Cancel" target:self action:@selector(cancelPressed:)];
  [cancel setIdentifier:@"profile-add-cancel"];
  NSButton *create = [MWMComponents primaryButtonWithTitle:@"Create profile" target:self action:@selector(createPressed:)];
  [create setIdentifier:@"profile-add-create"];
  NSStackView *buttons = [NSStackView stackViewWithViews:@[[MWMComponents spacer], cancel, create]];
  [buttons setSpacing:MWMSpacingS];
  [views addObject:buttons];
  return views;
}

- (void)reload {
  for (NSView *view in [[self.rows arrangedSubviews] copy]) {
    [self.rows removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  void (^add)(NSView *) = ^(NSView *view) {
    [self.rows addArrangedSubview:view];
    [[view.widthAnchor constraintEqualToAnchor:self.rows.widthAnchor constant:-2 * MWMSpacingXL] setActive:YES];
  };
  if (self.mode != ConfigurationProfilesModeList) {
    NSArray *views = self.mode == ConfigurationProfilesModeSource ? [self sourceViews] : (self.mode == ConfigurationProfilesModePickDuplicate ? [self duplicateViews] : [self nameViews]);
    for (NSView *view in views) add(view);
    return;
  }
  NSArray *names = [MWMProfiles names];
  NSString *active = [MWMProfiles activeName];
  if ([names count] == 0) {
    NSTextField *none = [MWMComponents wrappingLabelWithText:@"No profile has been saved yet. Make a change in Settings and save it, or add one below." size:13 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
    [none setIdentifier:@"profile-empty"];
    add(none);
  }
  for (NSString *name in names) add([self cardForName:name active:[name caseInsensitiveCompare:active] == NSOrderedSame only:[names count] == 1]);
  if (self.problem != nil) {
    NSTextField *error = [MWMComponents wrappingLabelWithText:self.problem size:13 color:[MWMTheme danger] weight:NSFontWeightRegular];
    [error setIdentifier:@"profile-problem"];
    add(error);
  }
  NSButton *addButton = [MWMComponents secondaryButtonWithTitle:@"Add profile" symbol:@"plus" target:self action:@selector(addPressed:)];
  [addButton setIdentifier:@"profile-add"];
  [self.rows addArrangedSubview:addButton];
}

#pragma mark - Asking

- (nullable NSString *)askFor:(NSString *)title detail:(NSString *)detail suggested:(NSString *)suggested button:(NSString *)button {
  MWMAlert *alert = [MWMAlert alert];
  [alert setMessageText:title];
  [alert setInformativeText:detail];
  MWMNameField *field = [MWMNameField nameFieldWithPlaceholder:nil identifier:@"ask-name" compact:NO];
  [field setStringValue:suggested];
  NSView *holder = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 44)];
  [holder addSubview:field];
  [MWMComponents pinView:field toEdgesOf:holder insets:NSEdgeInsetsMake(0, 0, 0, 0)];
  [alert setAccessoryView:holder];
  [alert addButtonWithTitle:button];
  [alert addButtonWithTitle:@"Cancel"];
  [NSApp activateIgnoringOtherApps:YES];
  [[alert window] setInitialFirstResponder:field];
  if ([alert runModal] != NSAlertFirstButtonReturn) return nil;
  return [field stringValue];
}

- (void)showProblem:(NSString *)message {
  self.problem = message;
  [self reload];
}

- (NSString *)nameFromSender:(NSButton *)sender prefix:(NSString *)prefix { return [sender.identifier substringFromIndex:[prefix length]]; }

#pragma mark - Buttons

- (void)usePressed:(NSButton *)sender { [self useNamed:[self nameFromSender:sender prefix:@"use-"]]; }

- (void)duplicatePressed:(NSButton *)sender {
  [self beginDraftDuplicating:[self nameFromSender:sender prefix:@"duplicate-"] fromCard:YES];
}

- (void)renamePressed:(NSButton *)sender {
  NSString *name = [self nameFromSender:sender prefix:@"rename-"];
  NSString *newName = [self askFor:[NSString stringWithFormat:@"Rename “%@”", name] detail:@"The file is renamed to match." suggested:name button:@"Rename"];
  if (newName != nil) [self renameNamed:name to:newName];
}

- (void)deletePressed:(NSButton *)sender { [self deleteNamed:[self nameFromSender:sender prefix:@"delete-"]]; }

- (void)addPressed:(id)sender { [self beginAdd]; }
- (void)backPressed:(id)sender { [self goBack]; }
- (void)cancelPressed:(id)sender { [self cancelAdd]; }
- (void)createPressed:(id)sender { [self createDraftNamed:[self.nameField stringValue]]; }
- (void)sourceRunningPressed:(id)sender { [self beginDraftFromRunning]; }
- (void)sourceDuplicatePressed:(id)sender { self.mode = ConfigurationProfilesModePickDuplicate; [self reload]; }
- (void)copyOnePressed:(NSButton *)sender { [self beginDraftDuplicating:[self nameFromSender:sender prefix:@"profile-copy-"] fromCard:NO]; }

- (void)sourceFilePressed:(id)sender {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setMessage:@"Choose a profile file (.mwm.yaml or .mwm.yml)"];
  [panel setAllowsMultipleSelection:NO];
  [panel setCanChooseDirectories:NO];
  if ([panel runModal] == NSModalResponseOK) [self beginDraftFromFileAtPath:[[panel URL] path]];
}

#pragma mark - Changing

- (void)useNamed:(NSString *)name {
  self.problem = nil;
  if (![MWMProfiles existsNamed:name]) { [self showProblem:[NSString stringWithFormat:@"“%@” doesn't exist.", name]]; return; }
  if ([[self editing] caseInsensitiveCompare:name] == NSOrderedSame) return;
  [self.delegate profilesView:self useProfileNamed:name];
}

// What a new profile starts as: the bundled defaults, or a copy of the active one.
- (NSString *)defaultText {
  NSString *path = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"slate"];
  NSString *legacy = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] : nil;
  MWMConfigDocument *document = legacy ? [MWMLegacyMigration documentFromLegacySource:legacy warnings:[NSMutableArray array]] : [[MWMConfigDocument alloc] init];
  return [document stringRepresentation];
}

#pragma mark - Adding

- (void)beginAdd {
  self.problem = nil;
  self.mode = ConfigurationProfilesModeSource;
  [self reload];
}

- (void)startNamingFrom:(NSString *)from text:(NSString *)text suggested:(NSString *)suggested fromCard:(BOOL)fromCard {
  self.problem = nil;
  self.draftFrom = from;
  self.draftText = text;
  self.draftFromCard = fromCard;
  [self.nameField setStringValue:[MWMProfiles freeNameFrom:suggested]];
  self.mode = ConfigurationProfilesModeName;
  [self reload];
}

- (void)beginDraftFromRunning {
  NSString *running = [MWMProfiles activeName];
  NSString *text = [MWMProfiles existsNamed:running] ? [NSString stringWithContentsOfFile:[MWMProfiles pathForName:running] encoding:NSUTF8StringEncoding error:nil] : nil;
  if (text != nil) [self startNamingFrom:[NSString stringWithFormat:@"%@ (running)", running] text:text suggested:[running stringByAppendingString:@" copy"] fromCard:NO];
  else [self startNamingFrom:@"the defaults" text:[self defaultText] suggested:@"New profile" fromCard:NO];
}

- (void)beginDraftDuplicating:(NSString *)name fromCard:(BOOL)fromCard {
  NSString *text = [NSString stringWithContentsOfFile:[MWMProfiles pathForName:name] encoding:NSUTF8StringEncoding error:nil];
  if (text == nil) { self.mode = ConfigurationProfilesModeList; [self showProblem:[NSString stringWithFormat:@"“%@” couldn't be read.", name]]; return; }
  [self startNamingFrom:name text:text suggested:[name stringByAppendingString:@" copy"] fromCard:fromCard];
}

- (void)beginDraftFromFileAtPath:(NSString *)path {
  NSError *error = nil;
  NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
  if (text == nil || [MWMConfigDocument documentFromString:text lenient:YES error:&error] == nil) {
    self.problem = [NSString stringWithFormat:@"%@ can't be used: %@", [path lastPathComponent], [error localizedDescription] ?: @"it couldn't be read."];
    self.mode = ConfigurationProfilesModeSource;
    [self reload];
    return;
  }
  NSString *base = [path lastPathComponent];
  for (NSString *suffix in @[@".mwm.yaml", @".mwm.yml", @".yaml", @".yml"]) {
    if ([base.lowercaseString hasSuffix:suffix]) { base = [base substringToIndex:[base length] - [suffix length]]; break; }
  }
  [self startNamingFrom:[path lastPathComponent] text:text suggested:[base length] > 0 ? base : @"New profile" fromCard:NO];
}

- (void)goBack {
  self.problem = nil;
  if (self.mode == ConfigurationProfilesModeName) self.mode = self.draftFromCard ? ConfigurationProfilesModeList : ConfigurationProfilesModeSource;
  else if (self.mode == ConfigurationProfilesModePickDuplicate) self.mode = ConfigurationProfilesModeSource;
  else self.mode = ConfigurationProfilesModeList;
  [self reload];
}

- (void)cancelAdd {
  self.problem = nil;
  self.mode = ConfigurationProfilesModeList;
  [self reload];
}

- (void)createDraftNamed:(NSString *)name {
  NSString *trimmed = [MWMProfiles trimmedName:name];
  if ([trimmed length] == 0) { self.problem = @"Give the profile a name."; [self reload]; return; }
  NSError *error = nil;
  if (![MWMProfiles createNamed:trimmed text:self.draftText ?: @"" error:&error]) {
    self.problem = [error localizedDescription];
    [self reload];
    return;
  }
  self.problem = nil;
  self.draftText = nil;
  self.mode = ConfigurationProfilesModeList;
  [self reload];
}

- (void)duplicateNamed:(NSString *)name as:(NSString *)copyName {
  NSError *error = nil;
  BOOL ok = [MWMProfiles duplicateNamed:name as:copyName error:&error];
  self.problem = ok ? nil : [error localizedDescription];
  [self reload];
}

- (void)renameNamed:(NSString *)name to:(NSString *)newName {
  NSError *error = nil;
  NSString *trimmed = [MWMProfiles trimmedName:newName];
  BOOL ok = [MWMProfiles renameNamed:name to:newName error:&error];
  self.problem = ok ? nil : [error localizedDescription];
  if (ok && self.editingName != nil && [self.editingName caseInsensitiveCompare:name] == NSOrderedSame) _editingName = [trimmed copy];
  [self reload];
  if (ok) [self.delegate profilesView:self didRenameProfileNamed:name to:trimmed];
}

- (void)deleteNamed:(NSString *)name {
  if ([[self editing] caseInsensitiveCompare:name] == NSOrderedSame) { [self showProblem:[NSString stringWithFormat:@"“%@” is open in this window. Use another profile first.", name]]; return; }
  if (self.interactive) {
    MWMAlert *alert = [MWMAlert alert];
    [alert setKind:MWMAlertKindDanger];
    [alert setMessageText:[NSString stringWithFormat:@"Delete “%@”?", name]];
    [alert setInformativeText:@"It's moved to the Trash. Backups in your gist aren't affected."];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addDestructiveButtonWithTitle:@"Delete"];
    [NSApp activateIgnoringOtherApps:YES];
    if ([alert runModal] == NSAlertFirstButtonReturn) return;
  }
  NSError *error = nil;
  BOOL ok = [MWMProfiles deleteNamed:name error:&error];
  self.problem = ok ? nil : [error localizedDescription];
  [self reload];
}

@end
