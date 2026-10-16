#import <Cocoa/Cocoa.h>
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 1;
        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(1024,1024)];
        [image lockFocus];
        NSRect rect = NSMakeRect(60,60,904,904);
        NSBezierPath *tile = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:208 yRadius:208];
        NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithSRGBRed:.08 green:.19 blue:.22 alpha:1] endingColor:[NSColor colorWithSRGBRed:.025 green:.06 blue:.11 alpha:1]];
        [gradient drawInBezierPath:tile angle:55];
        [[NSColor colorWithWhite:1 alpha:.15] setStroke]; tile.lineWidth=3; [tile stroke];
        NSColor *mint = [NSColor colorWithSRGBRed:.52 green:.94 blue:.80 alpha:1];
        NSPoint center = NSMakePoint(512,512);
        [mint setStroke];
        NSBezierPath *sun = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(370,370,284,284)];
        sun.lineWidth=43; [sun stroke];
        for (int ray=0; ray<8; ray++) {
            CGFloat angle=ray*M_PI/4;
            NSBezierPath *path=[NSBezierPath bezierPath];
            [path moveToPoint:NSMakePoint(center.x+cos(angle)*238,center.y+sin(angle)*238)];
            [path lineToPoint:NSMakePoint(center.x+cos(angle)*298,center.y+sin(angle)*298)];
            path.lineWidth=32; path.lineCapStyle=NSLineCapStyleRound; [path stroke];
        }
        [image unlockFocus];
        NSBitmapImageRep *bitmap=[NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
        NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        [png writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES];
    }
    return 0;
}
