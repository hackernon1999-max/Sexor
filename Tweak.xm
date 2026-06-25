#import <UIKit/UIKit.h>
#import <mach/mach.h>

// ======================================================================
// 🧬 چەکی نهێنیی ئەپڵ (DYLD_INTERPOSE)
// ======================================================================
#define DYLD_INTERPOSE(_replacement,_replacee) \
   __attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
   __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };

// ======================================================================
// 🖥️ شاشەی تێرمیناڵی دادوەری (The Forensic HUD)
// ======================================================================
static UITextView *spyTerminal = nil;
static NSMutableString *spyLogs = nil;

extern "C" {
    void AddLogToHUD(NSString *message) {
        if (!spyLogs) spyLogs = [[NSMutableString alloc] init];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss.SSS"];
        NSString *timeString = [formatter stringFromDate:[NSDate date]];
        
        NSString *finalMessage = [NSString stringWithFormat:@"[%@] %@\n", timeString, message];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [spyLogs insertString:finalMessage atIndex:0];
            if (spyLogs.length > 5000) {
                [spyLogs deleteCharactersInRange:NSMakeRange(5000, spyLogs.length - 5000)];
            }
            if (spyTerminal) {
                spyTerminal.text = spyLogs;
            }
        });
    }
}

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

extern "C" {
    void BuildSpyHUD() {
        // فێڵی KVC: کۆمپایلەر نازانێت ئێمە keyWindow بەکاردەهێنین، بۆیە ئێرۆر نادات!
        UIWindow *mainWindow = [[UIApplication sharedApplication] valueForKey:@"keyWindow"];
        
        if (!mainWindow) return;

        spyTerminal = [[UITextView alloc] initWithFrame:CGRectMake(20, 50, 320, 200)];
        spyTerminal.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.95];
        spyTerminal.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.2 alpha:1.0];
        spyTerminal.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:11] ?: [UIFont boldSystemFontOfSize:11];
        spyTerminal.editable = NO;
        spyTerminal.selectable = NO;
        spyTerminal.layer.cornerRadius = 8;
        spyTerminal.layer.borderWidth = 1.5;
        spyTerminal.layer.borderColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.2 alpha:0.8].CGColor;
        
        SpyHUDPanGesture *panGesture = [[SpyHUDPanGesture alloc] initWithTarget:nil action:nil];
        [spyTerminal addGestureRecognizer:panGesture];
        spyTerminal.userInteractionEnabled = YES;
        
        [mainWindow addSubview:spyTerminal];
        AddLogToHUD(@"👁️ [RAW FORENSICS] کامێراکە کارایە! چاوەڕێین...");
    }
}

// ======================================================================
// 🪝 تەڵە ڕووتەکان لەژێر قەڵغانی extern "C"
// ======================================================================
extern "C" {
    kern_return_t hooked_vm_protect(vm_map_t target_task, vm_address_t address, vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection) {
        NSString *log = [NSString stringWithFormat:@"🔓 [PROTECT] ئەدرێس: 0x%lx", address];
        AddLogToHUD(log);
        return vm_protect(target_task, address, size, set_maximum, new_protection);
    }

    kern_return_t hooked_vm_read_overwrite(vm_map_t target_task, vm_address_t address, vm_size_t size, vm_address_t data, vm_size_t *outsize) {
        NSString *log = [NSString stringWithFormat:@"✍️ [WRITE_O] ئەدرێس: 0x%lx", address];
        AddLogToHUD(log);
        return vm_read_overwrite(target_task, address, size, data, outsize);
    }

    kern_return_t hooked_vm_write(vm_map_t target_task, vm_address_t address, vm_offset_t data, mach_msg_type_number_t dataCnt) {
        NSString *log = [NSString stringWithFormat:@"🩸 [WRITE] ئەدرێس: 0x%lx", address];
        AddLogToHUD(log);
        return vm_write(target_task, address, data, dataCnt);
    }
}

DYLD_INTERPOSE(hooked_vm_protect, vm_protect);
DYLD_INTERPOSE(hooked_vm_read_overwrite, vm_read_overwrite);
DYLD_INTERPOSE(hooked_vm_write, vm_write);

// ======================================================================
// 🚀 داگیرساندنی شاشەکە
// ======================================================================
__attribute__((constructor))
static void Outlaw_Spy_Deployer() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BuildSpyHUD();
    });
}
