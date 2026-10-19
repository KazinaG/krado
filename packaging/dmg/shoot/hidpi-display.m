// CI runner only. Creates a HiDPI (2x) virtual display with CoreGraphics' CGVirtualDisplay
// (the same private class Chromium's tests use), makes it the main display so Finder opens
// windows on it, prints its id and scale, then stays alive until killed.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface CGVirtualDisplayDescriptor : NSObject
@property (retain, nonatomic) dispatch_queue_t queue;
@property (retain, nonatomic) NSString *name;
@property (nonatomic) unsigned int maxPixelsWide;
@property (nonatomic) unsigned int maxPixelsHigh;
@property (nonatomic) CGSize sizeInMillimeters;
@property (nonatomic) unsigned int productID;
@property (nonatomic) unsigned int vendorID;
@property (nonatomic) unsigned int serialNum;
@end
@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(unsigned int)width height:(unsigned int)height refreshRate:(double)rate;
@end
@interface CGVirtualDisplaySettings : NSObject
@property (retain, nonatomic) NSArray *modes;
@property (nonatomic) unsigned int hiDPI;
@end
@interface CGVirtualDisplay : NSObject
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@property (readonly, nonatomic) CGDirectDisplayID displayID;
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        unsigned int w = 1440, h = 900;
        CGVirtualDisplayDescriptor *d = [[NSClassFromString(@"CGVirtualDisplayDescriptor") alloc] init];
        d.queue = dispatch_get_main_queue();
        d.name = @"krado HiDPI test";
        d.maxPixelsWide = w * 2; d.maxPixelsHigh = h * 2;
        d.sizeInMillimeters = CGSizeMake(330, 206);
        d.productID = 0x4b72; d.vendorID = 0x4b72; d.serialNum = 1;
        CGVirtualDisplay *v = [[NSClassFromString(@"CGVirtualDisplay") alloc] initWithDescriptor:d];
        if (!v) { fprintf(stderr, "CGVirtualDisplay unavailable\n"); return 1; }
        CGVirtualDisplaySettings *s = [[NSClassFromString(@"CGVirtualDisplaySettings") alloc] init];
        s.hiDPI = 1;
        s.modes = @[[[NSClassFromString(@"CGVirtualDisplayMode") alloc] initWithWidth:w height:h refreshRate:60]];
        if (![v applySettings:s]) { fprintf(stderr, "applySettings failed\n"); return 1; }
        CGDirectDisplayID vid = v.displayID, old = CGMainDisplayID();
        [NSThread sleepForTimeInterval:2];
        CGDisplayConfigRef cfg;
        CGBeginDisplayConfiguration(&cfg);
        CGConfigureDisplayOrigin(cfg, vid, 0, 0);
        CGConfigureDisplayOrigin(cfg, old, (int32_t)w, 0);
        CGError e = CGCompleteDisplayConfiguration(cfg, kCGConfigureForSession);
        [NSThread sleepForTimeInterval:2];
        CGDisplayModeRef m = CGDisplayCopyDisplayMode(vid);
        printf("virtual %u (old main %u) config %d main now %u mode %zux%zu pt %zux%zu px\n", vid, old, e,
               CGMainDisplayID(), CGDisplayModeGetWidth(m), CGDisplayModeGetHeight(m),
               CGDisplayModeGetPixelWidth(m), CGDisplayModeGetPixelHeight(m));
        fflush(stdout);
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
