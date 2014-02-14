//
//  LXCompiler+Expression.h
//  Luax
//
//  Created by Noah Hilt on 2/2/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import "LXCompiler.h"

@interface LXContext(Expression)
- (LXExpr *)parseExpression;
- (LXExpr *)parseSubExpression:(NSInteger)level;
- (LXTableCtorExpr *)parseTable;
- (LXExpr *)parseSimpleExpression;
- (LXFunctionCallExpr *)parseFunctionCall:(LXExpr *)prefix;
- (LXExpr *)parseSuffixedExpression;
- (LXFunctionExpr *)parseFunction:(BOOL)anonymous;
@end
