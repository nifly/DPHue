//
//  NSNumber+Clamp.h
//  Pods
//
//  Created by Lars Blumberg on 10/25/16.
//
//

#import <Foundation/Foundation.h>

@interface NSNumber (Clamp)
- (NSNumber *)clampFrom:(NSNumber *) min to:(NSNumber *) max;
@end
