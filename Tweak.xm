#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import "fishhook.h" // بزوێنەری سیخوڕییەکە لە فەیسبووکەوە

// ======================================================================
// 🖥️ شاشەی تێرمیناڵی دادوەری (The Forensic HUD)
// ======================================================================
static UITextView *spyTerminal = nil;
static NSMutableString *spyLogs = nil;

// فەنکشنی ناردنی ڕاپۆرت بۆ سەر شاشەکە
void AddLogToHUD(NSString *message) {
    if (!spyLogs) spyLogs = [[NSMutableString alloc] init];
    
    // کاتژمێری دروستبوونی ڕووداوەکە
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSS"];
    NSString *timeString = [formatter stringFromDate:[NSDate date]];
    
    NSString *finalMessage = [NSString stringWithFormat:@"[%@] %@\n", timeString, message];
    
    // دەبێت لەسەر مێشکی سەرەکی (Main Thread) شاشەکە نوێ بکرێتەوە بۆ ئەوەی کڕاش نەکات
    dispatch_async(dispatch_get_main_queue(), ^{
        [spyLogs insertString:finalMessage atIndex:0]; // نامە نوێیەکان دەچنە سەرەوە
        if (spyLogs.length > 5000) { // پاراستنی ڕام نەوەک شاشەکە زۆر پڕ ببێت
            [spyLogs deleteCharactersInRange:NSMakeRange(5000, spyLogs.length - 5000)];
        }
        if (spyTerminal) {
            spyTerminal.text = spyLogs;
        }
    });
}

// جوڵاندنی شاشەکە بە پەنجە (Draggable)
@interface SpyHUDPanGesture : UIPanGestureRecognizer
@end
@implementation SpyHUDPanGesture
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    UIView *view = self.view;
    CGPoint translation = [self translationInView:view.superview];
    CGPoint center = view.center;
    center.x += translation.x;
    center.y += translation.y;
    view.center = center;
    [self setTranslation:CGPointZero inView:view.superview];
}
@end

// دروستکردنی شاشەی مەتريکس
void BuildSpyHUD() {
    UIWindow *mainWindow = nil;
    
    // دۆزینەوەی شاشەی سەرەکیی یارییەکە بە سەلامەترین ڕێگە (دژە-کڕاش)
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                mainWindow = scene.windows.firstObject;
                break;
            }
        }
    } else {
        mainWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    if (!mainWindow) return;

    spyTerminal = [[UITextView alloc] initWithFrame:CGRectMake(20, 50, 320, 200)];
    spyTerminal.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.95];
    spyTerminal.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.2 alpha:1.0]; // سەوزی لێزەری
    spyTerminal.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:11] ?: [UIFont boldSystemFontOfSize:11];
    spyTerminal.editable = NO;
    spyTerminal.selectable = NO;
    spyTerminal.layer.cornerRadius = 8;
    spyTerminal.layer.borderWidth = 1.5;
    spyTerminal.layer.borderColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.2 alpha:0.8].CGColor;
    
    // زیادکردنی توانای جوڵاندن
    SpyHUDPanGesture *panGesture = [[SpyHUDPanGesture alloc] initWithTarget:nil action:nil];
    [spyTerminal addGestureRecognizer:panGesture];
    spyTerminal.userInteractionEnabled = YES;
    
    [mainWindow addSubview:spyTerminal];
    
    AddLogToHUD(@"👁️ [FORENSICS] کامێرای سیخوڕی کارایە! چاوەڕێی دایلیبی دوژمنین...");
}

// ======================================================================
// 🪝 تەڵەکانی سیخوڕی (Zero Hack - Only Observation)
// ======================================================================

// ١. چاودێریکردنی فەرمانی شکاندنی قفڵی مێمۆری
static kern_return_t (*original_vm_protect)(vm_map_t, vm_address_t, vm_size_t, boolean_t, vm_prot_t);
kern_return_t hooked_vm_protect(vm_map_t target_task, vm_address_t address, vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection) {
    
    NSString *log = [NSString stringWithFormat:@"🔓 [PROTECT] کابرا قفڵی ئەدرێسی 0x%lx ی شکاند! (قەبارە: %lu)", address, size];
    AddLogToHUD(log);
    
    return original_vm_protect(target_task, address, size, set_maximum, new_protection);
}

// ٢. چاودێریکردنی فەرمانی نووسینەوەی هێکس بە _vm_read_overwrite
static kern_return_t (*original_vm_read_overwrite)(vm_map_t, vm_address_t, vm_size_t, vm_address_t, vm_size_t *);
kern_return_t hooked_vm_read_overwrite(vm_map_t target_task, vm_address_t address, vm_size_t size, vm_address_t data, vm_size_t *outsize) {
    
    NSString *log = [NSString stringWithFormat:@"✍️ [WRITE] کابرا هێکسی خستە ئەدرێسی 0x%lx (قەبارە: %lu)", address, size];
    AddLogToHUD(log);
    
    return original_vm_read_overwrite(target_task, address, size, data, outsize);
}

// ٣. چاودێریکردنی فەرمانی نووسینی ڕاستەوخۆ بە mach_vm_write
static kern_return_t (*original_mach_vm_write)(vm_map_t, mach_vm_address_t, vm_offset_t, mach_msg_type_number_t);
kern_return_t hooked_mach_vm_write(vm_map_t target_task, mach_vm_address_t address, vm_offset_t data, mach_msg_type_number_t dataCnt) {
    
    NSString *log = [NSString stringWithFormat:@"🩸 [MACH_WRITE] دایلیبەکە پاتچی کرد لە: 0x%llx", address];
    AddLogToHUD(log);
    
    return original_mach_vm_write(target_task, address, data, dataCnt);
}

// ======================================================================
// 🚀 داگیرساندنی کامێراکە بەبێ دەستکاریکردنی یارییەکە
// ======================================================================
__attribute__((constructor))
static void Outlaw_Spy_Deployer() {
    // ڕێکخستنی کامێراکان تەنیا لەسەر فەرمانەکانی سیستەم، نەک یارییەکە!
    struct rebinding rebindings[] = {
        {"vm_protect", (void *)hooked_vm_protect, (void **)&original_vm_protect},
        {"vm_read_overwrite", (void *)hooked_vm_read_overwrite, (void **)&original_vm_read_overwrite},
        {"mach_vm_write", (void *)hooked_mach_vm_write, (void **)&original_mach_vm_write}
    };
    
    rebind_symbols(rebindings, 3);
    
    // چاوەڕێ دەکەین ٥ چرکە تا یارییەکە بە سەلامەتی دەکرێتەوە و شاشەکە دروست دەبێت
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BuildSpyHUD();
    });
}
