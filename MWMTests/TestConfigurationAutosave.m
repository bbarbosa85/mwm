//
//  TestConfigurationAutosave.m
//  Slate
//
//  Tests for the configuration window saving valid changes as they're made,
//  against a temporary file instead of ~/.mwm.yml.
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

#import <XCTest/XCTest.h>
#import "ConfigurationWindowController.h"
#import "ConfigurationFormView.h"
#import "MWMConfigDocument.h"

@interface TestConfigurationAutosave : XCTestCase
@property (copy) NSString *path;
@property (strong) ConfigurationWindowController *controller;
@end

@implementation TestConfigurationAutosave

// Hand-written: comments and layout the window doesn't produce.
static NSString *const kOriginal =
  @"# my config\n"
  @"modifiers:\n"
  @"  hyper: ctrl;alt;cmd   # the usual\n"
  @"bindings:\n"
  @"  - key: r\n"
  @"    mods: ${hyper}\n"
  @"    action: relaunch\n";

- (void)setUp {
  NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  [self addTeardownBlock:^{ [[NSFileManager defaultManager] removeItemAtPath:dir error:nil]; }];
  self.path = [dir stringByAppendingPathComponent:@".mwm.yml"];
  self.controller = [[ConfigurationWindowController alloc] init];
  [self.controller setValue:self.path forKey:@"configPathOverride"];
}

- (void)tearDown {
  [self.controller.window orderOut:nil];
  [self.controller close];
  self.controller = nil;
}

// The pages are laid out for one width, so the window only changes in height.
- (void)testTheWindowIsAlwaysTheSameWidth {
  NSWindow *window = [self.controller window];
  XCTAssertEqual(window.contentMinSize.width, 1080);
  XCTAssertEqual(window.contentMaxSize.width, 1080);
  NSSize wider = [(id<NSWindowDelegate>)self.controller windowWillResize:window toSize:NSMakeSize(1500, 700)];
  XCTAssertEqual(wider.width, 1080, @"dragging wider stays 1080");
  XCTAssertEqual(wider.height, 700);
  NSSize narrower = [(id<NSWindowDelegate>)self.controller windowWillResize:window toSize:NSMakeSize(600, 500)];
  XCTAssertEqual(narrower.width, 1080, @"and so does dragging narrower");
  XCTAssertEqual(NSWidth([[window contentView] frame]), 1080, @"the window opens at 1080, whatever width an older version saved");
}

- (void)load {
  [self.controller performSelector:NSSelectorFromString(@"loadFromDisk")];
}

// A page that would fit in less room, or in more, doesn't change the window.
- (void)testTheWindowStaysTheSameWidthOnEveryPage {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];
  NSWindow *window = [self.controller window];
  [window orderFront:nil];
  for (NSInteger section = 0; section < ConfigurationFormSectionCount; section++) {
    self.controller.formView.selectedSection = (ConfigurationFormSection)section;
    [window layoutIfNeeded];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    XCTAssertEqual(NSWidth([[window contentView] frame]), 1080, @"section %ld", (long)section);
    NSView *form = (NSView *)self.controller.formView;
    NSView *detail = [form valueForKey:@"detail"];
    XCTAssertGreaterThan(NSWidth(detail.frame), 860, @"the page takes what the sidebar leaves: section %ld, %@", (long)section, NSStringFromRect(detail.frame));
  }
}

- (MWMConfigDocument *)document {
  return self.controller.formView.document;
}

// Changes the form's document the way a cell edit does, then tells the window.
- (void)edit:(void (^)(MWMConfigDocument *doc))change {
  XCTAssertNotNil([self document]);
  change([self document]);
  [(id<ConfigurationFormViewDelegate>)self.controller formViewDidChangeDocument:self.controller.formView];
}

- (NSString *)onDisk:(NSString *)path {
  return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}

// Editing a slot is a sublevel page: its header and the bottom bar step aside, and
// the file only changes when its own Save is clicked.
- (void)testEditingASlotHidesTheBarAndSavesOnlyOnSave {
  NSString *text = @"positions:\n  centre: move screenOriginX+screenSizeX/4;screenOriginY screenSizeX/2;screenSizeY\n";
  [text writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];
  ConfigurationFormView *form = self.controller.formView;
  NSView *bar = [self.controller valueForKey:@"bar"];
  form.selectedSection = ConfigurationFormSectionPositions;
  XCTAssertFalse([bar isHidden], @"the gallery shows the bottom bar");
  XCTAssertFalse(form.sublevelActive);

  id slots = [form valueForKey:@"slotsView"];
  [slots performSelector:@selector(selectSlotNamed:) withObject:@"centre"];
  XCTAssertTrue(form.sublevelActive);
  XCTAssertTrue([bar isHidden], @"no saved/apply/close bar while a slot is open");
  XCTAssertTrue([[form valueForKey:@"titleLabel"] isHidden], @"the back button is the header");
  XCTAssertTrue([[form valueForKey:@"slotsSwitcher"] isHidden], @"so is the switcher");

  [slots setValue:[NSValue valueWithRect:NSMakeRect(0.1, 0, 0.3, 1)] forKey:@"draftRect"];
  XCTAssertEqualObjects([self onDisk:self.path], text, @"nothing is written until Save");
  [slots performSelector:NSSelectorFromString(@"save")];
  XCTAssertNotEqualObjects([self onDisk:self.path], text, @"Save writes the file");
  XCTAssertFalse(form.sublevelActive, @"saving goes back to the gallery");
  XCTAssertFalse([bar isHidden]);
  XCTAssertFalse([[form valueForKey:@"titleLabel"] isHidden]);
  XCTAssertFalse([[form valueForKey:@"slotsSwitcher"] isHidden], @"the switcher is back in the gallery header");
}

- (void)testLeavingThePageClosesTheSublevel {
  [@"positions:\n  centre: move screenOriginX+screenSizeX/4;screenOriginY screenSizeX/2;screenSizeY\n" writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];
  ConfigurationFormView *form = self.controller.formView;
  form.selectedSection = ConfigurationFormSectionPositions;
  [[form valueForKey:@"slotsView"] performSelector:@selector(selectSlotNamed:) withObject:@"centre"];
  XCTAssertTrue(form.sublevelActive);
  form.selectedSection = ConfigurationFormSectionGeneral;
  XCTAssertFalse(form.sublevelActive);
  XCTAssertFalse([[self.controller valueForKey:@"bar"] isHidden], @"the bar is back on the other pages");
}

- (void)testOpeningDoesNotRewriteTheFile {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];
  XCTAssertEqualObjects([self document].bindings[0].action, @"relaunch");
  [self.controller performSelector:NSSelectorFromString(@"validateAndSave")];
  XCTAssertEqualObjects([self onDisk:self.path], kOriginal, @"comments survive until something changes");
}

- (void)testValidChangesSaveAndBackUpOnce {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];

  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].action = @"hint ASDF"; }];
  XCTAssertEqualObjects([self onDisk:self.path], [[self document] stringRepresentation]);
  NSString *backup = [self.path stringByAppendingString:@".bak"];
  XCTAssertEqualObjects([self onDisk:backup], kOriginal);

  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].action = @"grid"; }];
  XCTAssertTrue([[self onDisk:self.path] containsString:@"action: {type: grid}"]);
  XCTAssertEqualObjects([self onDisk:backup], kOriginal, @".bak keeps the version from before this session");
}

- (void)testChangesWithErrorsAreNotSaved {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];

  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].modifiers = @"${hyperr}"; }];
  XCTAssertEqualObjects([self onDisk:self.path], kOriginal);
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[self.path stringByAppendingString:@".bak"]]);

  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].modifiers = @"${hyper}"; }];
  XCTAssertEqualObjects([self onDisk:self.path], kOriginal, @"back to the loaded configuration: nothing to write");

  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].action = @"undo"; }];
  XCTAssertTrue([[self onDisk:self.path] containsString:@"action: {type: custom, text: \"undo\"}"], @"saves again once it's valid");
}

- (void)testMissingFileIsNotCreatedUntilChanged {
  [self load];
  XCTAssertGreaterThan([[self document].bindings count], 0u, @"starts from the defaults");
  [self.controller performSelector:NSSelectorFromString(@"validateAndSave")];
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.path], @"untouched defaults aren't written");

  [self edit:^(MWMConfigDocument *doc) { [doc.aliases addObject:[MWMConfigEntry entryWithName:@"mine" value:@"x"]]; }];
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.path]);
}

// Ready to pick by name: shift + cmd and alt + cmd.
- (void)testTheDefaultsComeWithShiftCmdAndAltCmdGroups {
  [self load];
  NSMutableDictionary *groups = [NSMutableDictionary dictionary];
  for (MWMConfigEntry *entry in [self document].modifiers) groups[entry.name] = [entry.value description];
  XCTAssertEqualObjects(groups[@"altcmd"], @"alt;cmd");
  XCTAssertEqualObjects(groups[@"shiftcmd"], @"shift;cmd");
}

#pragma mark - Save and "not applied yet"

- (NSString *)savedLabel {
  return [(NSTextField *)[[self.controller valueForKey:@"bar"] valueForKey:@"savedLabel"] stringValue];
}

- (NSButton *)buttonTitled:(NSString *)title in:(NSView *)view {
  for (NSView *sub in view.subviews) {
    if ([sub isKindOfClass:[NSButton class]] && [[(NSButton *)sub title] isEqualToString:title]) return (NSButton *)sub;
    NSButton *found = [self buttonTitled:title in:sub];
    if (found) return found;
  }
  return nil;
}

// MWM loaded the file at launch; the window saves changes right away, but they only count once MWM restarts.
- (void)testSavedChangesAreNotAppliedUntilMWMRestarts {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self.controller setValue:kOriginal forKey:@"appliedTextOverride"];
  [self load];
  XCTAssertEqualObjects([self savedLabel], @"Saved", @"what MWM loaded is what is on disk");

  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].action = @"hint ASDF"; }];
  XCTAssertEqualObjects([self savedLabel], @"Saved · not applied yet");

  [self.controller setValue:[self onDisk:self.path] forKey:@"appliedTextOverride"];  // MWM restarted with it
  [self.controller performSelector:NSSelectorFromString(@"validateAndSave")];
  [self load];
  XCTAssertEqualObjects([self savedLabel], @"Saved");
}

- (void)testAFileMWMNeverLoadedIsNotApplied {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self.controller setValue:nil forKey:@"appliedTextOverride"];  // there was no file at launch
  [self load];
  XCTAssertEqualObjects([self savedLabel], @"Saved · not applied yet");
}

- (void)testTheBarOrdersApplySaveClose {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];
  NSWindow *window = [self.controller window];
  [window setFrame:NSMakeRect(0, 0, 1200, 780) display:NO];
  [[window contentView] layoutSubtreeIfNeeded];
  NSView *bar = [self.controller valueForKey:@"bar"];
  NSButton *apply = [self buttonTitled:@"Apply and Restart" in:bar], *save = [self buttonTitled:@"Saved" in:bar], *close = [self buttonTitled:@"Close" in:bar];
  XCTAssertNotNil(apply); XCTAssertNotNil(save); XCTAssertNotNil(close);
  XCTAssertLessThan(NSMinX(apply.frame), NSMinX(save.frame), @"Apply, then Save");
  XCTAssertLessThan(NSMinX(save.frame), NSMinX(close.frame), @"then Close");
  XCTAssertEqualObjects(save.keyEquivalent, @"s", @"⌘S");
  XCTAssertEqual(save.action, NSSelectorFromString(@"saveDocument:"));
  XCTAssertEqual(save.target, self.controller);
}

// Autosave means the file normally matches the form: Save then reads "Saved" and is disabled.
- (void)testSaveReadsSavedAndIsDisabledWhenTheFileMatches {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];
  NSView *bar = [self.controller valueForKey:@"bar"];
  NSButton *save = [self buttonTitled:@"Saved" in:bar];
  XCTAssertNotNil(save);
  XCTAssertFalse(save.enabled);
  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].action = @"hint ASDF"; }];
  XCTAssertEqualObjects(save.title, @"Saved", @"autosaved");
  XCTAssertFalse(save.enabled);
  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].modifiers = @"${hyperr}"; }];
  XCTAssertEqualObjects(save.title, @"Save", @"a change with errors isn't saved");
  XCTAssertTrue(save.enabled);
}

- (void)testSaveCreatesAMissingFileFromTheDefaults {
  [self load];
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.path]);
  NSButton *save = [self buttonTitled:@"Save" in:[self.controller valueForKey:@"bar"]];
  XCTAssertNotNil(save);
  XCTAssertTrue(save.enabled, @"there is something to save: the file doesn't exist yet");
  [self.controller performSelector:NSSelectorFromString(@"saveDocument:") withObject:nil];
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.path], @"Save writes the untouched defaults");
  XCTAssertEqualObjects(save.title, @"Saved");
  XCTAssertFalse(save.enabled);
  XCTAssertEqualObjects([self savedLabel], @"Saved · not applied yet");
}

- (void)testSaveWithErrorsWritesNothingAndSaysSo {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];
  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].modifiers = @"${hyperr}"; }];
  [self.controller performSelector:NSSelectorFromString(@"saveDocument:") withObject:nil];
  XCTAssertEqualObjects([self onDisk:self.path], kOriginal);
  XCTAssertEqualObjects([self savedLabel], @"Not saved");
}

- (void)testUnreadableFileIsLeftAlone {
  NSString *broken = @"bindings:\n  - key: r\n    action: [relaunch]\n";
  [broken writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];
  XCTAssertNil([self document], @"the form shows the error instead");
  [self.controller performSelector:NSSelectorFromString(@"validateAndSave")];
  XCTAssertEqualObjects([self onDisk:self.path], broken);
}

@end
