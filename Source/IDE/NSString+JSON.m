#import "NSString+JSON.h"

@implementation NSString(JSON)

- (NSDictionary *)JSONValue {
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary *obj = nil;
    NSError *error = nil;
    
    obj = [NSJSONSerialization JSONObjectWithData:data
                                          options:NSJSONReadingMutableContainers
                                            error:&error];
#if DEBUG
    if (error) {
        NSString *str = [[NSString alloc] initWithData:data
                                               encoding:NSUTF8StringEncoding];
        NSLog(@"NSJSONSerialization error %@ parsing %@",
              error, str);
    }
#endif
    
    return obj;
}

@end