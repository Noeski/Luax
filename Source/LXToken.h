//
//  LXToken.h
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXVariable.h"
#import "LXClass.h"
#import "LXNode.h"

#define FIRST_RESERVED 257

typedef enum {
    /* terminal symbols denoted by reserved words */
    LX_TK_AND = FIRST_RESERVED, LX_TK_BREAK,
    LX_TK_DO, LX_TK_ELSE, LX_TK_ELSEIF, LX_TK_END, LX_TK_FALSE, LX_TK_FOR, LX_TK_FUNCTION,
    LX_TK_GOTO, LX_TK_IF, LX_TK_IN, LX_TK_LOCAL, LX_TK_GLOBAL, LX_TK_NIL, LX_TK_NOT, LX_TK_OR, LX_TK_REPEAT,
    LX_TK_RETURN, LX_TK_THEN, LX_TK_TRUE, LX_TK_UNTIL, LX_TK_WHILE,
    LX_TK_TYPE_VAR, LX_TK_TYPE_BOOL, LX_TK_TYPE_NUMBER, LX_TK_TYPE_STRING, LX_TK_TYPE_TABLE, LX_TK_TYPE_FUNCTION,
    LX_TK_CLASS, LX_TK_EXTENDS, LX_TK_STATIC, LX_TK_SUPER,
    /* other terminal symbols */
    LX_TK_CONCAT, LX_TK_DOTS, LX_TK_EQ, LX_TK_PLUS_EQ, LX_TK_MINUS_EQ, LX_TK_MULT_EQ, LX_TK_DIV_EQ, LX_TK_POW_EQ, LX_TK_MOD_EQ, LX_TK_CONCAT_EQ, LX_TK_GE, LX_TK_LE, LX_TK_NE, LX_TK_DBCOLON, LX_TK_EOS,
    LX_TK_NUMBER, LX_TK_NAME, LX_TK_STRING,
    LX_TK_COMMENT, LX_TK_LONGCOMMENT,
    LX_TK_ERROR
} LXTokenType;

typedef enum {
    LXTokenCompletionFlagsTypes = 1,
    LXTokenCompletionFlagsVariables = 2,
    LXTokenCompletionFlagsMembers = 4,
    LXTokenCompletionFlagsFunction = 8,
    LXTokenCompletionFlagsControlStructures = 16,
    LXTokenCompletionFlagsClass = LXTokenCompletionFlagsFunction | LXTokenCompletionFlagsTypes,
    LXTokenCompletionFlagsBlock = LXTokenCompletionFlagsControlStructures | LXTokenCompletionFlagsVariables | LXTokenCompletionFlagsTypes
} LXTokenCompletionFlags;

@interface LXToken : NSObject 
@property (nonatomic) LXTokenType type;
@property (nonatomic) NSRange range;
@property (nonatomic) NSInteger startLine;
@property (nonatomic) NSInteger endLine;
@property (nonatomic) NSInteger column;
@property (nonatomic) NSInteger endColumn;
@property (nonatomic, strong) LXVariable *variable;
@property (nonatomic, strong) LXClass *variableType;
@property (nonatomic, strong) LXScope *scope;
@property (nonatomic) BOOL isMember;
@property (nonatomic, assign) LXTokenCompletionFlags completionFlags;

- (BOOL)isKeyword;
- (BOOL)isType;
- (BOOL)isAssignmentOperator;
@end