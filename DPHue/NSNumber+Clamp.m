//
//  NSNumber+Clamp.m
//  Pods
//
//  Created by Lars Blumberg on 10/25/16.
//
//

#import "NSNumber+Clamp.h"

@implementation NSNumber (Clamp)
- (NSNumber *)clampFrom:(NSNumber *) min to:(NSNumber *) max {
    if (self.doubleValue > max.doubleValue) return max;
    if (self.doubleValue < min.doubleValue) return min;
    return self;
}
@end
