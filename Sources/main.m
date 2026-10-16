#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "AGSession.h"

static NSColor *Mint(void) { return [NSColor colorWithSRGBRed:0.52 green:0.94 blue:0.80 alpha:1]; }
static NSTextField *Label(NSString *text, CGFloat size, NSFontWeight weight) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = NSColor.labelColor;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

@interface AGSurface : NSView
@end
@implementation AGSurface
- (BOOL)isFlipped { return YES; }
@end

@interface AGHeader : AGSurface
@end
@implementation AGHeader
- (void)mouseDown:(NSEvent *)event { [self.window performWindowDragWithEvent:event]; }
@end

@interface AGPanel : NSPanel
@end
@implementation AGPanel
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface AGDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate>
@property (nonatomic, strong) AGPanel *panel;
@property (nonatomic, strong) AGSession *session;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) AGSurface *content;
@property (nonatomic, strong) NSTextField *subtitle, *stateLabel, *clockLabel, *timeHint, *customLabel, *unitLabel;
@property (nonatomic, strong) NSTextField *displayTitle, *displayDetail, *lockTitle, *lockDetail, *footer;
@property (nonatomic, strong) NSTextField *customInput;
@property (nonatomic, strong) NSSwitch *displaySwitch, *lockSwitch;
@property (nonatomic, strong) NSButton *actionButton, *pinButton, *languageButton;
@property (nonatomic, strong) NSMutableArray<NSButton *> *presets;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@property (nonatomic) NSInteger selectedMinutes;
@property (nonatomic) BOOL arabic, pinned, customPending, lastActive;
@end

@implementation AGDelegate
- (NSString *)ar:(NSString *)ar en:(NSString *)en { return self.arabic ? ar : en; }
- (NSButton *)icon:(NSString *)symbol help:(NSString *)help frame:(NSRect)frame action:(SEL)action parent:(NSView *)parent {
    NSButton *button = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:help] target:self action:action];
    button.frame = frame;
    button.bordered = NO;
    button.contentTintColor = NSColor.secondaryLabelColor;
    button.toolTip = help;
    button.accessibilityLabel = help;
    [parent addSubview:button];
    return button;
}
- (void)place:(NSView *)view frame:(NSRect)frame parent:(NSView *)parent { view.frame = frame; [parent addSubview:view]; }
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSUserDefaults *prefs = NSUserDefaults.standardUserDefaults;
    self.arabic = [prefs objectForKey:@"Arabic"] ? [prefs boolForKey:@"Arabic"] : YES;
    self.pinned = [prefs boolForKey:@"Pinned"];
    self.selectedMinutes = [prefs objectForKey:@"Minutes"] ? [prefs integerForKey:@"Minutes"] : 60;
    if (self.selectedMinutes < 0 || self.selectedMinutes > 1440) self.selectedMinutes = 60;
    self.session = [AGSession new];
    __weak AGDelegate *weakSelf = self;
    self.session.onChange = ^(AGSession *session) {
        if (weakSelf.lastActive != session.isActive) [weakSelf refresh];
        else [weakSelf refreshClock];
    };
    [self buildWindow];
    self.displaySwitch.state = [prefs objectForKey:@"DisplayAwake"] ? [prefs boolForKey:@"DisplayAwake"] : NSControlStateValueOn;
    self.lockSwitch.state = [prefs objectForKey:@"IdleLock"] ? [prefs boolForKey:@"IdleLock"] : NSControlStateValueOn;
    if (self.lockSwitch.state == NSControlStateValueOn) self.displaySwitch.state = NSControlStateValueOn;
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:@"moon.zzz" accessibilityDescription:@"Awake Glass"];
    self.statusItem.button.image.template = YES;
    self.statusItem.button.toolTip = @"Awake Glass";
    [self rebuildMenu];
    if (self.selectedMinutes > 0) self.customInput.stringValue = [NSString stringWithFormat:@"%ld", (long)self.selectedMinutes];
    [self refresh];
    [self showPanel:nil];
}
- (void)buildWindow {
    self.panel = [[AGPanel alloc] initWithContentRect:NSMakeRect(0,0,360,508)
        styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    self.panel.title = @"Awake Glass";
    self.panel.delegate = self;
    self.panel.opaque = NO;
    self.panel.backgroundColor = NSColor.clearColor;
    self.panel.hasShadow = YES;
    self.panel.hidesOnDeactivate = NO;
    self.panel.releasedWhenClosed = NO;
    self.panel.movableByWindowBackground = YES;
    self.panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.panel.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    self.panel.level = self.pinned ? NSFloatingWindowLevel : NSNormalWindowLevel;
    NSGlassEffectView *glass = [[NSGlassEffectView alloc] initWithFrame:NSMakeRect(0,0,360,508)];
    glass.style = NSGlassEffectViewStyleRegular;
    glass.cornerRadius = 28;
    glass.tintColor = [NSColor colorWithSRGBRed:0.08 green:0.17 blue:0.21 alpha:0.35];
    self.content = [[AGSurface alloc] initWithFrame:glass.bounds];
    glass.contentView = self.content;
    self.panel.contentView = glass;

    AGHeader *header = [[AGHeader alloc] initWithFrame:NSMakeRect(16,14,328,48)];
    [self.content addSubview:header];
    NSImageView *mark = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"sun.max" accessibilityDescription:@"Awake Glass"]];
    mark.contentTintColor = Mint();
    [self place:mark frame:NSMakeRect(3,10,27,27) parent:header];
    [self place:Label(@"Awake Glass",17,NSFontWeightSemibold) frame:NSMakeRect(40,3,170,25) parent:header];
    self.subtitle = Label(@"",10.5,NSFontWeightRegular);
    self.subtitle.textColor = NSColor.secondaryLabelColor;
    [self place:self.subtitle frame:NSMakeRect(40,27,170,17) parent:header];
    self.languageButton = [self icon:@"globe" help:@"English / العربية" frame:NSMakeRect(228,9,26,28) action:@selector(toggleLanguage:) parent:header];
    self.pinButton = [self icon:@"pin" help:@"Keep on top" frame:NSMakeRect(263,9,26,28) action:@selector(togglePin:) parent:header];
    [self icon:@"minus" help:@"Hide widget" frame:NSMakeRect(298,9,26,28) action:@selector(hidePanel:) parent:header];

    self.stateLabel = Label(@"",11,NSFontWeightMedium);
    self.stateLabel.alignment = NSTextAlignmentCenter;
    [self place:self.stateLabel frame:NSMakeRect(40,83,280,20) parent:self.content];
    self.clockLabel = Label(@"",44,NSFontWeightLight);
    self.clockLabel.font = [NSFont monospacedDigitSystemFontOfSize:44 weight:NSFontWeightLight];
    self.clockLabel.alignment = NSTextAlignmentCenter;
    [self place:self.clockLabel frame:NSMakeRect(15,111,330,61) parent:self.content];
    self.timeHint = Label(@"",11,NSFontWeightRegular);
    self.timeHint.alignment = NSTextAlignmentCenter;
    self.timeHint.textColor = NSColor.secondaryLabelColor;
    [self place:self.timeHint frame:NSMakeRect(18,176,324,21) parent:self.content];

    self.presets = [NSMutableArray array];
    NSArray *values = @[@15,@30,@60,@120,@0];
    NSArray *titles = @[@"15m",@"30m",@"1h",@"2h",@"∞"];
    for (NSUInteger i=0; i<values.count; i++) {
        NSButton *button = [NSButton buttonWithTitle:titles[i] target:self action:@selector(selectPreset:)];
        button.frame = NSMakeRect(20+i*65,211,59,34);
        button.bezelStyle = NSBezelStyleGlass;
        button.tag = [values[i] integerValue];
        button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
        button.accessibilityLabel = button.tag ? [NSString stringWithFormat:@"%ld minutes",(long)button.tag] : @"Until stopped";
        [self.content addSubview:button];
        [self.presets addObject:button];
    }
    self.customLabel = Label(@"",11,NSFontWeightRegular);
    self.customLabel.textColor = NSColor.secondaryLabelColor;
    [self place:self.customLabel frame:NSMakeRect(22,260,145,26) parent:self.content];
    self.customInput = [[NSTextField alloc] initWithFrame:NSMakeRect(174,258,81,28)];
    self.customInput.stringValue = @"60";
    self.customInput.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.customInput.alignment = NSTextAlignmentCenter;
    self.customInput.bezelStyle = NSTextFieldRoundedBezel;
    self.customInput.delegate = self;
    self.customInput.target = self;
    self.customInput.action = @selector(selectCustom:);
    self.customInput.accessibilityLabel = @"Custom duration in minutes";
    [self.content addSubview:self.customInput];
    self.unitLabel = Label(@"",11,NSFontWeightRegular);
    self.unitLabel.textColor = NSColor.secondaryLabelColor;
    [self place:self.unitLabel frame:NSMakeRect(265,260,72,26) parent:self.content];
    NSBox *divider = [[NSBox alloc] initWithFrame:NSMakeRect(22,302,316,1)];
    divider.boxType = NSBoxSeparator;
    [self.content addSubview:divider];

    self.displayTitle = Label(@"",12,NSFontWeightMedium);
    [self place:self.displayTitle frame:NSMakeRect(22,316,264,22) parent:self.content];
    self.displayDetail = Label(@"",10,NSFontWeightRegular);
    self.displayDetail.textColor = NSColor.secondaryLabelColor;
    [self place:self.displayDetail frame:NSMakeRect(22,338,264,19) parent:self.content];
    self.displaySwitch = [NSSwitch new];
    self.displaySwitch.target = self;
    self.displaySwitch.action = @selector(optionsChanged:);
    self.displaySwitch.frame = NSMakeRect(298,325,38,23);
    self.displaySwitch.accessibilityLabel = @"Keep display awake";
    [self.content addSubview:self.displaySwitch];

    self.lockTitle = Label(@"",12,NSFontWeightMedium);
    [self place:self.lockTitle frame:NSMakeRect(22,371,264,22) parent:self.content];
    self.lockDetail = Label(@"",10,NSFontWeightRegular);
    self.lockDetail.textColor = NSColor.secondaryLabelColor;
    [self place:self.lockDetail frame:NSMakeRect(22,393,264,19) parent:self.content];
    self.lockSwitch = [NSSwitch new];
    self.lockSwitch.target = self;
    self.lockSwitch.action = @selector(optionsChanged:);
    self.lockSwitch.frame = NSMakeRect(298,380,38,23);
    self.lockSwitch.accessibilityLabel = @"Delay idle screen lock";
    [self.content addSubview:self.lockSwitch];
    self.actionButton = [NSButton buttonWithTitle:@"" target:self action:@selector(toggleSession:)];
    self.actionButton.frame = NSMakeRect(20,433,320,42);
    self.actionButton.bezelStyle = NSBezelStyleGlass;
    self.actionButton.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    self.actionButton.keyEquivalent = @"\r";
    [self.content addSubview:self.actionButton];
    self.panel.initialFirstResponder = self.actionButton;
    self.footer = Label(@"",9,NSFontWeightRegular);
    self.footer.alignment = NSTextAlignmentCenter;
    self.footer.textColor = NSColor.tertiaryLabelColor;
    [self place:self.footer frame:NSMakeRect(16,481,328,16) parent:self.content];

    NSRect screen = NSScreen.mainScreen.visibleFrame;
    [self.panel setFrameOrigin:NSMakePoint(NSMaxX(screen)-384,NSMaxY(screen)-532)];
    if (![self.panel setFrameUsingName:@"AwakeGlassWidget"]) [self.panel setFrameOrigin:NSMakePoint(NSMaxX(screen)-384,NSMaxY(screen)-532)];
    BOOL intersects = NO;
    for (NSScreen *candidate in NSScreen.screens) if (NSIntersectsRect(candidate.visibleFrame,self.panel.frame)) intersects = YES;
    if (!intersects) [self.panel setFrameOrigin:NSMakePoint(NSMaxX(screen)-384,NSMaxY(screen)-532)];
    [self.panel setFrameAutosaveName:@"AwakeGlassWidget"];
}
- (void)rebuildMenu {
    NSMenu *menu = [NSMenu new];
    NSMenuItem *title = [[NSMenuItem alloc] initWithTitle:@"Awake Glass" action:NULL keyEquivalent:@""];
    title.enabled = NO;
    [menu addItem:title];
    [menu addItemWithTitle:[self ar:@"إظهار البطاقة" en:@"Show widget"] action:@selector(showPanel:) keyEquivalent:@""].target = self;
    [menu addItemWithTitle:[self ar:@"إخفاء البطاقة" en:@"Hide widget"] action:@selector(hidePanel:) keyEquivalent:@""].target = self;
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *stop = [menu addItemWithTitle:[self ar:@"إيقاف الجلسة" en:@"Stop session"] action:@selector(stopSession:) keyEquivalent:@""];
    stop.target = self;
    stop.enabled = self.session.isActive;
    [menu addItemWithTitle:[self ar:@"إعدادات قفل الشاشة…" en:@"Lock Screen settings…"] action:@selector(openLockSettings:) keyEquivalent:@""].target = self;
    [menu addItemWithTitle:[self ar:@"عن الأداة…" en:@"About…"] action:@selector(showAbout:) keyEquivalent:@""].target = self;
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItemWithTitle:[self ar:@"إنهاء Awake Glass" en:@"Quit Awake Glass"] action:@selector(quit:) keyEquivalent:@"q"].target = self;
    self.statusItem.menu = menu;
}
- (NSString *)timeString:(NSTimeInterval)interval {
    NSInteger seconds = (NSInteger)ceil(MAX(0,interval));
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld",(long)(seconds/3600),(long)((seconds/60)%60),(long)(seconds%60)];
}
- (void)refresh {
    BOOL active = self.session.isActive;
    self.lastActive = active;
    self.subtitle.stringValue = [self ar:@"خلي شغلك يكمل بهدوء" en:@"A little space for your work"];
    self.stateLabel.stringValue = active ? [self ar:@"●  الجلسة شغّالة" en:@"●  KEEPING YOUR MAC AWAKE"] : [self ar:@"الوضع الطبيعي" en:@"NATURAL SLEEP IS ON"];
    self.stateLabel.textColor = active ? Mint() : NSColor.secondaryLabelColor;
    self.customLabel.stringValue = [self ar:@"أو وقت مخصص" en:@"Or a custom duration"];
    self.unitLabel.stringValue = [self ar:@"دقيقة" en:@"minutes"];
    self.displayTitle.stringValue = [self ar:@"إبقاء الشاشة مضاءة" en:@"Keep the display awake"];
    self.displayDetail.stringValue = [self ar:@"الماك يبقى شغّال بكل الأحوال" en:@"Your Mac stays awake in either mode"];
    self.lockTitle.stringValue = [self ar:@"تأجيل القفل التلقائي" en:@"Delay idle screen lock"];
    self.lockDetail.stringValue = [self ar:@"يجدّد نشاط الشاشة أثناء الجلسة" en:@"Refreshes screen activity during the session"];
    self.lockSwitch.toolTip = [self ar:@"يؤجل قفل الخمول بدون تغيير الباسورد. القفل اليدوي وسياسات أمان الجهاز تبقى فعّالة. يتطلب إبقاء الشاشة مضاءة." en:@"Requests screen activity without changing your password settings. Manual locks and managed security policies still apply. Requires the display to stay awake."];
    self.actionButton.title = active ? [self ar:@"إيقاف الجلسة" en:@"Stop session"] : [self ar:@"ابدأ الجلسة" en:@"Start session"];
    self.actionButton.image = [NSImage imageWithSystemSymbolName:active ? @"stop.fill" : @"play.fill" accessibilityDescription:nil];
    self.actionButton.imagePosition = NSImageLeading;
    self.actionButton.contentTintColor = active ? NSColor.systemOrangeColor : Mint();
    self.actionButton.bezelColor = active ? NSColor.systemOrangeColor : Mint();
    self.footer.stringValue = [self ar:@"بلا تغيير دائم للإعدادات · القفل اليدوي يبقى فعّال" en:@"No permanent changes · manual lock still works"];
    self.pinButton.contentTintColor = self.pinned ? Mint() : NSColor.secondaryLabelColor;
    self.pinButton.toolTip = [self ar:@"تثبيت فوق النوافذ" en:@"Keep above other windows"];
    for (NSButton *button in self.presets) {
        button.contentTintColor = button.tag == self.selectedMinutes ? Mint() : NSColor.secondaryLabelColor;
        button.bezelColor = button.tag == self.selectedMinutes ? [Mint() colorWithAlphaComponent:0.35] : nil;
        button.enabled = !active;
    }
    self.customInput.enabled = !active;
    self.displaySwitch.enabled = !active;
    self.lockSwitch.enabled = !active;
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:active ? @"sun.max.fill" : @"moon.zzz" accessibilityDescription:@"Awake Glass"];
    self.statusItem.button.image.template = YES;
    [self refreshClock];
    [self rebuildMenu];
}
- (void)refreshClock {
    BOOL active = self.session.isActive;
    self.clockLabel.stringValue = self.selectedMinutes == 0 ? @"∞" : [self timeString:active ? self.session.remaining : self.selectedMinutes*60];
    self.clockLabel.textColor = active ? Mint() : NSColor.labelColor;
    if (active && self.session.endDate) {
        if (!self.timeFormatter) {
            self.timeFormatter = [NSDateFormatter new];
            self.timeFormatter.dateStyle = NSDateFormatterNoStyle;
            self.timeFormatter.timeStyle = NSDateFormatterShortStyle;
        }
        self.timeHint.stringValue = [NSString stringWithFormat:[self ar:@"يرجع السكون الطبيعي الساعة %@" en:@"Natural sleep resumes at %@"],[self.timeFormatter stringFromDate:self.session.endDate]];
    } else {
        self.timeHint.stringValue = self.selectedMinutes == 0 ? [self ar:@"تبقى شغّالة لحد ما توقفها" en:@"Stays awake until you stop it"] : [self ar:@"اختار الوقت وخلي الباقي علينا" en:@"Pick a duration. We will watch the clock."];
    }
    if (!active && self.session.stopReason.length) {
        self.timeHint.stringValue = [self.session.stopReason isEqualToString:@"expired"] ? [self ar:@"انتهى الوقت · رجع السكون الطبيعي" en:@"Time is up · natural sleep restored"] : [self.session.stopReason isEqualToString:@"stopped"] ? [self ar:@"توقفت الجلسة · رجع السكون الطبيعي" en:@"Session stopped · natural sleep restored"] : [self ar:@"توقفت الجلسة · إعداداتك الطبيعية فعّالة" en:@"Session ended · your normal settings apply"];
    }
    if (!active && self.session.lastError) {
        self.stateLabel.stringValue = [self ar:@"توقفت حماية الجلسة" en:@"SESSION PROTECTION STOPPED"];
        self.stateLabel.textColor = NSColor.systemOrangeColor;
        self.timeHint.stringValue = [self ar:@"macOS لم يكمل طلب النشاط · جرّب جلسة جديدة" en:@"macOS could not maintain activity · try again"];
        self.timeHint.toolTip = self.session.lastError.localizedDescription;
    } else {
        self.timeHint.toolTip = nil;
    }
    NSString *state = active ? [self ar:@"الجلسة شغّالة" en:@"Session active"] : [self ar:@"الوضع الطبيعي" en:@"Natural sleep"];
    self.clockLabel.accessibilityLabel = [NSString stringWithFormat:@"%@, %@",state,self.clockLabel.stringValue];
    self.statusItem.button.title = active ? (self.selectedMinutes == 0 ? @" ∞" : [NSString stringWithFormat:@" %ldm",(long)ceil(self.session.remaining/60)]) : @"";
    self.statusItem.button.toolTip = active ? [NSString stringWithFormat:@"Awake Glass · %@",self.clockLabel.stringValue] : @"Awake Glass";
}
- (void)selectPreset:(NSButton *)sender {
    self.selectedMinutes = sender.tag;
    self.customPending = NO;
    if (self.selectedMinutes) self.customInput.stringValue = [NSString stringWithFormat:@"%ld",(long)self.selectedMinutes];
    [NSUserDefaults.standardUserDefaults setInteger:self.selectedMinutes forKey:@"Minutes"];
    [self refresh];
}
- (BOOL)applyCustom {
    NSString *text = [self.customInput.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableString *normalized = [NSMutableString new];
    for (NSUInteger index = 0; index < text.length; index++) {
        unichar digit = [text characterAtIndex:index];
        if (digit >= 0x0660 && digit <= 0x0669) digit = '0' + digit - 0x0660;
        if (digit >= 0x06F0 && digit <= 0x06F9) digit = '0' + digit - 0x06F0;
        [normalized appendFormat:@"%C", digit];
    }
    text = normalized;
    NSScanner *scanner = [NSScanner scannerWithString:text];
    NSInteger minutes;
    if (![scanner scanInteger:&minutes] || !scanner.isAtEnd || minutes < 1 || minutes > 1440) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = [self ar:@"اختار من 1 إلى 1440 دقيقة" en:@"Choose 1 to 1440 minutes"];
        alert.informativeText = [self ar:@"للجلسة المفتوحة استخدم زر ∞." en:@"For an open session, use the ∞ button."];
        [alert runModal];
        return NO;
    }
    self.customPending = NO;
    self.selectedMinutes = minutes;
    [NSUserDefaults.standardUserDefaults setInteger:minutes forKey:@"Minutes"];
    return YES;
}
- (void)selectCustom:(id)sender { if ([self applyCustom]) [self refresh]; }
- (void)controlTextDidChange:(NSNotification *)notification { self.customPending = YES; }
- (void)optionsChanged:(NSSwitch *)sender {
    if (sender == self.lockSwitch && self.lockSwitch.state == NSControlStateValueOn) self.displaySwitch.state = NSControlStateValueOn;
    if (sender == self.displaySwitch && self.displaySwitch.state == NSControlStateValueOff) self.lockSwitch.state = NSControlStateValueOff;
    [NSUserDefaults.standardUserDefaults setBool:self.displaySwitch.state == NSControlStateValueOn forKey:@"DisplayAwake"];
    [NSUserDefaults.standardUserDefaults setBool:self.lockSwitch.state == NSControlStateValueOn forKey:@"IdleLock"];
    [self refresh];
}
- (void)toggleSession:(id)sender {
    if (self.session.isActive) { [self stopSession:nil]; return; }
    if (self.customPending && ![self applyCustom]) return;
    [self.panel makeFirstResponder:nil];
    NSError *error = nil;
    if (![self.session startWithDuration:self.selectedMinutes*60 keepDisplayAwake:self.displaySwitch.state == NSControlStateValueOn keepUnlocked:self.lockSwitch.state == NSControlStateValueOn error:&error]) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = [self ar:@"تعذّر بدء الجلسة" en:@"Could not start the session"];
        alert.informativeText = error.localizedDescription ?: @"Please try again.";
        [alert runModal];
    }
    [self refresh];
}
- (void)stopSession:(id)sender { [self.session stop]; [self refresh]; }
- (void)toggleLanguage:(id)sender { self.arabic = !self.arabic; [NSUserDefaults.standardUserDefaults setBool:self.arabic forKey:@"Arabic"]; [self refresh]; }
- (void)togglePin:(id)sender { self.pinned = !self.pinned; self.panel.level = self.pinned ? NSFloatingWindowLevel : NSNormalWindowLevel; [NSUserDefaults.standardUserDefaults setBool:self.pinned forKey:@"Pinned"]; [self refresh]; }
- (void)showPanel:(id)sender { [self.panel orderFrontRegardless]; }
- (void)hidePanel:(id)sender { [self.panel orderOut:nil]; }
- (void)openLockSettings:(id)sender { [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension"]]; }
- (void)showAbout:(id)sender {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Awake Glass 1.0";
    alert.informativeText = [self ar:@"بطاقة خفيفة تمنع السكون أثناء شغلك.\n\nالجلسة تنتهي بالمؤقت أو زر الإيقاف أو إنهاء الأداة. إعدادات السكون والباسورد الأصلية ما تتغير.\n\nتأجيل القفل يطلب نشاط الشاشة من macOS؛ قد تفرض سياسات أمان الجهاز قفلاً رغم ذلك. الأداة لا تفتح شاشة مقفولة.\n\nإخفاء البطاقة يبقي الجلسة شغّالة. لإنهاء الأداة استخدم أيقونتها بشريط المينو." en:@"A lightweight glass companion for uninterrupted work.\n\nSessions end with the timer, Stop, or Quit. Your sleep and password settings are never rewritten.\n\nIdle-lock delay requests screen activity from macOS; security policies may still enforce a lock. This app never unlocks a locked screen.\n\nHiding the widget keeps a session running. Quit from the menu bar to exit."];
    [alert runModal];
}
- (void)quit:(id)sender { [NSApp terminate:nil]; }
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag { [self showPanel:nil]; return YES; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return NO; }
- (void)applicationWillTerminate:(NSNotification *)notification { [self.session stop]; [self.panel saveFrameUsingName:@"AwakeGlassWidget"]; }
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        AGDelegate *delegate = [AGDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
