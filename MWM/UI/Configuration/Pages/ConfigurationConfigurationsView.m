//
//  ConfigurationConfigurationsView.m
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

#import "ConfigurationConfigurationsView.h"
#import "MWMAlert.h"
#import "MWMComponents.h"
#import "MWMConfigDocument.h"
#import "MWMConfigurations.h"
#import "MWMLegacyMigration.h"
#import "MWMTheme.h"

@interface ConfigurationConfigurationsView () <NSTextFieldDelegate>
@property (strong) NSStackView *rows;
@property (strong) NSTextField *nameField;
@property (copy, nullable) NSString *problem;
@end

@implementation ConfigurationConfigurationsView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _interactive = YES;
    _nameField = [NSTextField textFieldWithString:@""];
    [_nameField setPlaceholderString:@"Name"];
    [_nameField setIdentifier:@"config-new-name"];
    [_nameField setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
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
  [button setContentTintColor:[MWMTheme textTertiary]];
  [button setIdentifier:identifier];
  [button setToolTip:tip];
  [button setEnabled:enabled];
  return button;
}

- (NSView *)cardForName:(NSString *)name active:(BOOL)active only:(BOOL)only {
  NSMutableArray *top = [NSMutableArray arrayWithObject:[MWMComponents labelWithText:name font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]]];
  if (active) {
    MWMChipView *chip = [MWMChipView chipWithText:@"Active" color:[MWMTheme success]];
    [chip setIdentifier:@"config-active"];
    [top addObject:chip];
  }
  [top addObject:[MWMComponents spacer]];
  NSButton *activate = [MWMComponents secondaryButtonWithTitle:@"Activate" target:self action:@selector(activatePressed:)];
  [activate setIdentifier:[@"activate-" stringByAppendingString:name]];
  [activate setEnabled:!active];
  [activate setToolTip:active ? @"MWM is using this configuration" : @"Use this configuration. MWM restarts."];
  [top addObject:activate];
  [top addObject:[self iconButton:@"doc.on.doc" tip:@"Duplicate" identifier:[@"duplicate-" stringByAppendingString:name] action:@selector(duplicatePressed:) enabled:YES]];
  [top addObject:[self iconButton:@"pencil" tip:@"Rename" identifier:[@"rename-" stringByAppendingString:name] action:@selector(renamePressed:) enabled:YES]];
  BOOL canDelete = !active && !only;
  [top addObject:[self iconButton:@"trash" tip:active ? @"The active configuration can't be deleted" : @"Delete" identifier:[@"delete-" stringByAppendingString:name] action:@selector(deletePressed:) enabled:canDelete]];
  NSStackView *header = [NSStackView stackViewWithViews:top];
  [header setSpacing:MWMSpacingM];
  [header setAlignment:NSLayoutAttributeCenterY];

  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setLocalizedDateFormatFromTemplate:@"d MMM yyyy"];
  NSDate *date = [MWMConfigurations modificationDateForName:name];
  NSString *file = [[MWMConfigurations pathForName:name] lastPathComponent];
  NSTextField *detail = [MWMComponents secondaryLabel:date ? [NSString stringWithFormat:@"%@ · edited %@", file, [formatter stringFromDate:date]] : file];
  [detail setIdentifier:@"config-file"];

  NSStackView *column = [NSStackView stackViewWithViews:@[header, detail]];
  [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [column setAlignment:NSLayoutAttributeLeading];
  [column setSpacing:MWMSpacingS];
  [[header.widthAnchor constraintEqualToAnchor:column.widthAnchor] setActive:YES];
  NSView *card = [MWMComponents card];
  [card setIdentifier:[@"config-" stringByAppendingString:name]];
  [card addSubview:column];
  [MWMComponents pinView:column toEdgesOf:card insets:NSEdgeInsetsMake(MWMSpacingL, MWMSpacingL, MWMSpacingL, MWMSpacingL)];
  return card;
}

- (NSView *)newCard {
  NSString *active = [MWMConfigurations activeName];
  NSTextField *title = [MWMComponents labelWithText:@"New configuration" font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]];
  NSButton *blank = [MWMComponents secondaryButtonWithTitle:@"From the defaults" target:self action:@selector(newBlankPressed:)];
  [blank setIdentifier:@"config-new-blank"];
  NSButton *copy = [MWMComponents secondaryButtonWithTitle:[NSString stringWithFormat:@"Copy of “%@”", active] target:self action:@selector(newCopyPressed:)];
  [copy setIdentifier:@"config-new-copy"];
  NSStackView *form = [NSStackView stackViewWithViews:@[self.nameField, blank, copy]];
  [form setSpacing:MWMSpacingS];
  [form setAlignment:NSLayoutAttributeCenterY];
  NSButton *file = [MWMComponents secondaryButtonWithTitle:@"Add from file…" symbol:@"square.and.arrow.down" target:self action:@selector(addFromFilePressed:)];
  [file setIdentifier:@"config-add-file"];
  NSTextField *hint = [MWMComponents wrappingLabelWithText:@"A configuration is one file in ~/.mwm. Add one you downloaded, such as an example, with Add from file." size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
  NSStackView *footer = [NSStackView stackViewWithViews:@[hint, file]];
  [footer setSpacing:MWMSpacingM];
  [footer setAlignment:NSLayoutAttributeCenterY];
  NSStackView *column = [NSStackView stackViewWithViews:@[title, form, footer]];
  [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [column setAlignment:NSLayoutAttributeLeading];
  [column setSpacing:MWMSpacingM];
  for (NSView *view in @[form, footer]) [[view.widthAnchor constraintEqualToAnchor:column.widthAnchor] setActive:YES];
  NSView *card = [MWMComponents dashedCard];
  [card setIdentifier:@"config-new"];
  [card addSubview:column];
  [MWMComponents pinView:column toEdgesOf:card insets:NSEdgeInsetsMake(MWMSpacingL, MWMSpacingL, MWMSpacingL, MWMSpacingL)];
  return card;
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
  NSArray *names = [MWMConfigurations names];
  NSString *active = [MWMConfigurations activeName];
  if ([names count] == 0) {
    NSTextField *none = [MWMComponents wrappingLabelWithText:@"No configuration has been saved yet. Make a change in Settings and save it, or add one below." size:13 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
    [none setIdentifier:@"config-empty"];
    add(none);
  }
  for (NSString *name in names) add([self cardForName:name active:[name caseInsensitiveCompare:active] == NSOrderedSame only:[names count] == 1]);
  if (self.problem != nil) {
    NSTextField *error = [MWMComponents wrappingLabelWithText:self.problem size:13 color:[MWMTheme danger] weight:NSFontWeightRegular];
    [error setIdentifier:@"config-problem"];
    add(error);
  }
  [self.rows setCustomSpacing:MWMSpacingXL afterView:self.rows.arrangedSubviews.lastObject];
  add([self newCard]);
}

#pragma mark - Asking

- (nullable NSString *)askFor:(NSString *)title detail:(NSString *)detail suggested:(NSString *)suggested button:(NSString *)button {
  MWMAlert *alert = [MWMAlert alert];
  [alert setMessageText:title];
  [alert setInformativeText:detail];
  NSTextField *field = [NSTextField textFieldWithString:suggested];
  [field setFrame:NSMakeRect(0, 0, 260, 24)];
  [alert setAccessoryView:field];
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

- (void)activatePressed:(NSButton *)sender { [self activateNamed:[self nameFromSender:sender prefix:@"activate-"]]; }

- (void)duplicatePressed:(NSButton *)sender {
  NSString *name = [self nameFromSender:sender prefix:@"duplicate-"];
  NSString *copy = [self askFor:[NSString stringWithFormat:@"Duplicate “%@”", name] detail:@"The copy has the same shortcuts and settings. Give it a name." suggested:[MWMConfigurations freeNameFrom:[name stringByAppendingString:@" copy"]] button:@"Duplicate"];
  if (copy != nil) [self duplicateNamed:name as:copy];
}

- (void)renamePressed:(NSButton *)sender {
  NSString *name = [self nameFromSender:sender prefix:@"rename-"];
  NSString *newName = [self askFor:[NSString stringWithFormat:@"Rename “%@”", name] detail:@"The file is renamed to match." suggested:name button:@"Rename"];
  if (newName != nil) [self renameNamed:name to:newName];
}

- (void)deletePressed:(NSButton *)sender { [self deleteNamed:[self nameFromSender:sender prefix:@"delete-"]]; }

- (void)newBlankPressed:(id)sender { [self createNamed:[self.nameField stringValue] copyingActive:NO]; }
- (void)newCopyPressed:(id)sender { [self createNamed:[self.nameField stringValue] copyingActive:YES]; }

- (void)addFromFilePressed:(id)sender {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setMessage:@"Choose a configuration file (.mwm.yaml or .mwm.yml)"];
  [panel setAllowsMultipleSelection:NO];
  [panel setCanChooseDirectories:NO];
  if ([panel runModal] == NSModalResponseOK) [self addFromFileAtPath:[[panel URL] path]];
}

#pragma mark - Changing

- (void)activateNamed:(NSString *)name {
  self.problem = nil;
  if (![MWMConfigurations existsNamed:name]) { [self showProblem:[NSString stringWithFormat:@"“%@” doesn't exist.", name]]; return; }
  if ([[MWMConfigurations activeName] caseInsensitiveCompare:name] == NSOrderedSame) return;
  [self.delegate configurationsView:self switchToConfigurationNamed:name];
}

// What a new configuration starts as: the bundled defaults, or a copy of the active one.
- (NSString *)defaultText {
  NSString *path = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"slate"];
  NSString *legacy = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] : nil;
  MWMConfigDocument *document = legacy ? [MWMLegacyMigration documentFromLegacySource:legacy warnings:[NSMutableArray array]] : [[MWMConfigDocument alloc] init];
  return [document stringRepresentation];
}

- (void)createNamed:(NSString *)name copyingActive:(BOOL)copyingActive {
  NSString *trimmed = [MWMConfigurations trimmedName:name];
  if ([trimmed length] == 0) trimmed = [MWMConfigurations freeNameFrom:@"New configuration"];
  NSError *error = nil;
  BOOL ok;
  if (copyingActive && [MWMConfigurations existsNamed:[MWMConfigurations activeName]]) {
    ok = [MWMConfigurations duplicateNamed:[MWMConfigurations activeName] as:trimmed error:&error];
  } else {
    ok = [MWMConfigurations createNamed:trimmed text:[self defaultText] error:&error];
  }
  self.problem = ok ? nil : [error localizedDescription];
  if (ok) [self.nameField setStringValue:@""];
  [self reload];
}

- (void)duplicateNamed:(NSString *)name as:(NSString *)copyName {
  NSError *error = nil;
  BOOL ok = [MWMConfigurations duplicateNamed:name as:copyName error:&error];
  self.problem = ok ? nil : [error localizedDescription];
  [self reload];
}

- (void)renameNamed:(NSString *)name to:(NSString *)newName {
  BOOL wasActive = [[MWMConfigurations activeName] caseInsensitiveCompare:name] == NSOrderedSame;
  NSError *error = nil;
  BOOL ok = [MWMConfigurations renameNamed:name to:newName error:&error];
  self.problem = ok ? nil : [error localizedDescription];
  [self reload];
  if (ok && wasActive) [self.delegate configurationsViewDidRenameActive:self];
}

- (void)deleteNamed:(NSString *)name {
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
  BOOL ok = [MWMConfigurations deleteNamed:name error:&error];
  self.problem = ok ? nil : [error localizedDescription];
  [self reload];
}

- (void)addFromFileAtPath:(NSString *)path {
  NSError *error = nil;
  NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
  if (text == nil || [MWMConfigDocument documentFromString:text lenient:YES error:&error] == nil) {
    [self showProblem:[NSString stringWithFormat:@"%@ can't be used: %@", [path lastPathComponent], [error localizedDescription] ?: @"it couldn't be read."]];
    return;
  }
  NSString *name = [MWMConfigurations importFileAtPath:path error:&error];
  self.problem = name ? nil : [error localizedDescription];
  [self reload];
}

@end
