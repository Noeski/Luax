//
//  LXCompiler+Statement.h
//  Luax
//
//  Created by Noah Hilt on 2/3/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import "LXCompiler.h"

@interface LXContext(Statement)
- (LXBlock *)parseBlock;
- (LXBlock *)parseBlock:(NSDictionary *)closeKeywords;
- (LXStmt *)parseStatement;
- (LXClassStmt *)parseClassStatement;
- (LXIfStmt *)parseIfStatement;
- (LXElseIfStmt *)parseElseIfStatement;
- (LXWhileStmt *)parseWhileStatement;
- (LXDoStmt *)parseDoStatement;
- (LXForStmt *)parseForStatement;
- (LXRepeatStmt *)parseRepeatStatement;
- (LXStmt *)parseDeclarationStatement;
- (LXStmt *)parseExpressionStatement;
@end
