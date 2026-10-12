#import <Foundation/Foundation.h>
typedef NSString *CalculateKey NS_TYPED_EXTENSIBLE_ENUM;
typedef NS_OPTIONS(NSInteger, CalculateFormat) { CalculateFormatNone = 0 };
@interface CalculateResult : NSObject
@property (readonly) NSString *formattedResult;
@property (readonly) NSString *formattedExpression;
@end
