//
//  LXAutocompleteScope.m
//  Luax
//
//  Created by Noah Hilt on 12/17/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXAutocompleteScope.h"

@implementation LXAutocompleteScope

- (id)init {
    self = [super init];
    
    _color = [NSColor colorWithDeviceRed:(CGFloat)rand()/(CGFloat)RAND_MAX green:(CGFloat)rand()/(CGFloat)RAND_MAX blue:(CGFloat)rand()/(CGFloat)RAND_MAX alpha:1];
    return self;
}
@end
