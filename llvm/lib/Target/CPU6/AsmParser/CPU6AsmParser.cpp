// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//                CPU6 Assembly Parser Logic
//===----------------------------------------------------------------------===//

#include "TargetInfo/CPU6TargetInfo.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCParser/MCAsmLexer.h"
#include "llvm/MC/MCParser/MCParsedAsmOperand.h"
#include "llvm/MC/MCParser/MCTargetAsmParser.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/Support/Casting.h"
#include "llvm/MC/TargetRegistry.h"



using namespace llvm;

#define DEBUG_TYPE "riscv-asm-parser"

namespace {

class CPU6AsmParser : public MCTargetAsmParser {
    SMLoc getLoc() const { return getParser().getTok().getLoc(); }

    bool MatchAndEmitInstruction(SMLoc IDLoc, unsigned &Opcode,
                                 OperandVector &Operands, MCStreamer &Out,
                                 uint64_t &ErrorInfo,
                                 bool MatchingInlineAsm) override;

    bool ParseRegister(unsigned &RegNo, SMLoc &StartLoc, SMLoc &EndLoc) override;
    OperandMatchResultTy tryParseRegister(unsigned &RegNo, SMLoc &StartLoc, SMLoc &EndLoc);

    bool ParseInstruction(ParseInstructionInfo &Info, StringRef Name,
                          SMLoc NameLoc, OperandVector &Operands) override;

    bool ParseDirective(AsmToken DirectiveID) override;

    bool validateInstruction(MCInst &Inst, OperandVector &Operands);

// Auto-generated instruction matching functions
#define GET_ASSEMBLER_HEADER
#include "CPU6GenAsmMatcher.inc"

    OperandMatchResultTy parseImmediate(OperandVector &Operands);
    OperandMatchResultTy parseRegister(OperandVector &Operands);
    OperandMatchResultTy parseRegOrImm(OperandVector &Operands);
    OperandMatchResultTy parseDirect(OperandVector &Operands);
    OperandMatchResultTy parseIndirect(OperandVector &Operands);
    OperandMatchResultTy parsePCOffset(OperandVector &Operands);
    

    bool parseOperand(OperandVector &Operands, StringRef Mnemonic);

public:
    enum CPU6MatchResultTy {
        Match_Dummy = FIRST_TARGET_MATCH_RESULT_TY,
    #define GET_OPERAND_DIAGNOSTIC_TYPES
    #include "CPU6GenAsmMatcher.inc"
    #undef GET_OPERAND_DIAGNOSTIC_TYPES
    };

    CPU6AsmParser(const MCSubtargetInfo &STI, MCAsmParser &Parser,
                 const MCInstrInfo &MII, const MCTargetOptions &Options)
        : MCTargetAsmParser(Options, STI, MII) {
            setAvailableFeatures(ComputeAvailableFeatures(STI.getFeatureBits()));
    }
};

// CPU6Operand - Instances of this class represent a parsed machine instruction
struct CPU6Operand: public MCParsedAsmOperand {

    enum class KindTy {
        Token,
        Register,
        Immediate,
    } Kind;

    struct RegOp {
        unsigned RegNum;
    };

    struct ImmOp {
        const MCExpr *Val;
    };

    SMLoc StartLoc, EndLoc;
    union {
        StringRef Tok;
        RegOp Reg;
        ImmOp Imm;
    };

    CPU6Operand(KindTy K) : MCParsedAsmOperand(), Kind(K) {}

public:
    CPU6Operand(const CPU6Operand &o) : MCParsedAsmOperand() {
        Kind = o.Kind;
        StartLoc = o.StartLoc;
        EndLoc = o.EndLoc;
        switch (Kind) {
        case KindTy::Register:
            Reg = o.Reg;
            break;
        case KindTy::Immediate:
            Imm = o.Imm;
            break;
        case KindTy::Token:
            Tok = o.Tok;
            break;      
        }
    }

    bool isToken() const override { return Kind == KindTy::Token; }
    bool isReg() const override { return Kind == KindTy::Register; }
    bool isImm() const override { return Kind == KindTy::Immediate; }
    bool isMem() const override { return false; }

    static bool evaluateConstantImm(const MCExpr *Expr, int32_t &Imm) {
        if (auto CE = dyn_cast<MCConstantExpr>(Expr)) {
            Imm = CE->getValue();
            return true;
        }

        return false;
    }

    bool isConstantImm() const {
        return isImm() && dyn_cast<MCConstantExpr>(getImm());
    }

    template <unsigned N> bool IsUImm() const {
        int32_t Imm;
        bool IsConstantImm = evaluateConstantImm(getImm(), Imm);
        return IsConstantImm && isUInt<N>(Imm);
    }

    template <signed N> bool IsSImm() const {
        int32_t Imm;
        bool IsConstantImm = evaluateConstantImm(getImm(), Imm);
        return IsConstantImm && isInt<N>(Imm);
    }

    bool isSImm8() { return IsSImm<8>(); }
    bool isSImm16() { return IsSImm<16>(); }
    bool isUImm4() { return IsUImm<4>(); }
    bool isUImm8() { return IsUImm<8>(); }
    bool isUImm16() { return IsUImm<16>(); }

    /// getStartLoc - Gets location of the first token of this operand
    SMLoc getStartLoc() const override { return StartLoc; }
    /// getEndLoc - Gets location of the last token of this operand
    SMLoc getEndLoc() const override { return EndLoc; }

    unsigned getReg() const override {
        assert(Kind == KindTy::Register && "Invalid type access!");
        return Reg.RegNum;
    }

    const MCExpr *getImm() const {
        assert(Kind == KindTy::Immediate && "Invalid type access!");
        return Imm.Val;
    }

    StringRef getToken() const {
        assert(Kind == KindTy::Token && "Invalid type access!");
        return Tok;
    }

    void print(raw_ostream &OS) const override {
        switch (Kind) {
        case KindTy::Immediate:
            OS << *getImm();
            break;
        case KindTy::Register:
            OS << "<register ";
            OS << getReg() << ">";
            break;
        case KindTy::Token:
            OS << "'" << getToken() << "'";
            break;
        }
    }

    static std::unique_ptr<CPU6Operand> createToken(StringRef Str, SMLoc S) {
        auto Op = std::make_unique<CPU6Operand>(KindTy::Token);
        Op->Tok = Str;
        Op->StartLoc = S;
        Op->EndLoc = S;
        return Op;
    }

    static std::unique_ptr<CPU6Operand> createReg(unsigned RegNo, SMLoc S,
                                                  SMLoc E) {
        auto Op = std::make_unique<CPU6Operand>(KindTy::Register);
        Op->Reg.RegNum = RegNo;
        Op->StartLoc = S;
        Op->EndLoc = E;
        return Op;
    }

    static std::unique_ptr<CPU6Operand> createImm(const MCExpr *Val, SMLoc S,
                                                  SMLoc E) {
        auto Op = std::make_unique<CPU6Operand>(KindTy::Immediate);
        Op->Imm.Val = Val;
        Op->StartLoc = S;
        Op->EndLoc = E;
        return Op;
    }

    // TODO: I believe this is a portion that evaulates expressions? Like (A + B), but revisit to be sure
    void addExpr(MCInst &Inst, const MCExpr *Expr) const {
        assert(Expr && "Expr shouldn't be null!");
        // TODO: Below is an ugly check to see if the expression is a const.
        // see if we can do better
        if (auto *CE = dyn_cast<MCConstantExpr>(Expr))
            Inst.addOperand(MCOperand::createImm(CE->getValue()));
        else
            Inst.addOperand(MCOperand::createExpr(Expr));
    }

    // Used by the TableGen Code
    void addRegOperands(MCInst &Inst, unsigned N) const {
        assert(N == 1 && "Invalid number of operands!");
        Inst.addOperand(MCOperand::createReg(getReg()));
    }

    void addImmOperands(MCInst &Inst, unsigned N) const {
        assert(N == 1 && "Invalid number of operands!");
        addExpr(Inst, getImm());
    }

};
} // end anonymous namespace

#define GET_REGISTER_MATCHER
#define GET_MATCHER_IMPLEMENTATION
#include "CPU6GenAsmMatcher.inc"

bool CPU6AsmParser::MatchAndEmitInstruction(SMLoc IDLoc, unsigned &Opcode, OperandVector &Operands,
                                            MCStreamer &Out, uint64_t &ErrorInfo, bool MatchingInlineAsm) {
    
    MCInst Inst;
    SMLoc ErrorLoc;

    auto Result = MatchInstructionImpl(Operands, Inst, ErrorInfo, MatchingInlineAsm);

    switch (Result) {
    default:
        break;
    case Match_Success:
        Inst.setLoc(IDLoc);
        Out.emitInstruction(Inst, getSTI());
        return false; // "false" means instruction matched successfully in LLVM, strange convention
    case Match_MissingFeature:
        return Error(IDLoc, "Instruction use requires an option to be enabled");
    case Match_MnemonicFail:
        return Error(IDLoc, "unrecognized instruction mnemonic");
    case Match_InvalidOperand:
        ErrorLoc = IDLoc;
        if (ErrorInfo != ~0ULL) {
            if (ErrorInfo >= Operands.size())
                return Error(ErrorLoc, "too few operands for instruction");
            ErrorLoc = ((CPU6Operand &)*Operands[ErrorInfo]).getStartLoc();
            if (ErrorLoc == SMLoc())
                ErrorLoc = IDLoc;
        }
        return Error(ErrorLoc, "invalid operand for instruction");
    }
    // Handle the case when the error message is of specific type
    // other than the generic Match_InvalidOperand, and the
    // corresponding operand is missing.
    if (Result > FIRST_TARGET_MATCH_RESULT_TY) {
        SMLoc ErrorLoc = IDLoc;
        if (ErrorInfo != ~0ULL && ErrorInfo >= Operands.size())
        return Error(ErrorLoc, "too few operands for instruction");
    }

    // Handle the invalid type matches for our custom type defines in CPU6InstrFormats.td
    // These are enum declared if GET_OPERAND_DIAGNOSTIC_TYPES is def'd
    switch (Result) {
    default:
        break;
    case Match_InvalidUImm4:
        return Error(((CPU6Operand &)*Operands[ErrorInfo]).getStartLoc(), 
                      "unsigned 4 bit integer must be between 0 and 15");
    case Match_InvalidUImm8:
        return Error(((CPU6Operand &)*Operands[ErrorInfo]).getStartLoc(), 
                      "unsigned 8 bit integer must be between 0 and 255");
    case Match_InvalidSImm8:
        return Error(((CPU6Operand &)*Operands[ErrorInfo]).getStartLoc(), 
                      "signed 8 bit integer must be between 127 and -128");
    }

llvm_unreachable("Unknown match type detected!");
}


// Naming convention isn't great here. the capital P ParseRegister funcs are for our class
// the lowercase p parseRegister below is for the actual parsing stuff... confusing
bool CPU6AsmParser::ParseRegister(unsigned &RegNo, SMLoc &StartLoc,
                                  SMLoc &EndLoc) {
  if (tryParseRegister(RegNo, StartLoc, EndLoc) != MatchOperand_Success)
    return Error(StartLoc, "invalid register name");
  return false;
}

OperandMatchResultTy CPU6AsmParser::tryParseRegister(unsigned &RegNo, SMLoc &StartLoc, SMLoc &EndLoc) {
    const AsmToken &Tok = getParser().getTok();
    StartLoc = Tok.getLoc();
    EndLoc = Tok.getEndLoc();
    RegNo = 0;
    StringRef Name = getLexer().getTok().getIdentifier();

    if (!MatchRegisterName(Name) || !MatchRegisterAltName(Name)) {
        return MatchOperand_NoMatch;
    }
    getParser().Lex(); // Eat the identifier token
    return MatchOperand_Success;
}

OperandMatchResultTy CPU6AsmParser::parseRegister(OperandVector &Operands) {
  SMLoc S = getLoc();
  SMLoc E = SMLoc::getFromPointer(S.getPointer() - 1);

  switch (getLexer().getKind()) {
  default:
    return MatchOperand_NoMatch;
  case AsmToken::Identifier:
    StringRef Name = getLexer().getTok().getIdentifier();
    unsigned RegNo = MatchRegisterName(Name);
    if (RegNo == 0) {
      RegNo = MatchRegisterAltName(Name);
      if (RegNo == 0)
        return MatchOperand_NoMatch;
    }
    getLexer().Lex();
    Operands.push_back(CPU6Operand::createReg(RegNo, S, E));
  }
  return MatchOperand_Success;
}

// TODO: Revisit this guy and make sure we can parse all the supported immediate expressions
OperandMatchResultTy CPU6AsmParser::parseImmediate(OperandVector &Operands) {
    SMLoc S = getLoc();
    SMLoc E;
    const MCExpr *Res;

    switch (getLexer().getKind()) {
    default:
        return MatchOperand_NoMatch;
    case AsmToken::Hash:
    case AsmToken::Minus:
    case AsmToken::Integer:
    case AsmToken::String:
        if (getParser().parseExpression(Res, E))
            return MatchOperand_ParseFail;
        break;
    }

    Operands.push_back(CPU6Operand::createImm(Res, S, E));

    return MatchOperand_Success;
}


// helper for our indirect/direct parsing functions
OperandMatchResultTy CPU6AsmParser::parseRegOrImm(OperandVector &Operands) {


    //Attempt to parse token as a register
    LLVM_DEBUG(dbgs() << "Attempting register parse\n");
    if(parseRegister(Operands) == MatchOperand_Success)
       return MatchOperand_Success;
    
    // Attempt to parse token as an immediate
    dbgs() << "Attempting immediate parse\n";
    if (parseImmediate(Operands) == MatchOperand_Success)
       return MatchOperand_Success;

    return MatchOperand_NoMatch;


}

// Parse a direct operand, e.g. (something)
OperandMatchResultTy CPU6AsmParser::parseDirect(OperandVector &Operands) {

    OperandMatchResultTy result = MatchOperand_ParseFail;

    // only proceed if we have a left paren and something else
    if ((getLexer().getKind() == AsmToken::LParen)
        && (getLexer().peekTok().getKind() != AsmToken::LParen)) {
        
        Operands.push_back(CPU6Operand::createToken("(", getLoc()));
        getParser().Lex(); // Eat '('  

        result = parseRegOrImm(Operands);
        dbgs() << "parseDirect parseRegOrImm result: " << result << "\n";
        
        Operands.push_back(CPU6Operand::createToken(")", getLoc()));
        getParser().Lex(); // Eat ')'     
    }

    return result;


}
// Parse an indirect operand, e.g. ((something))
// syntactically, this is just a direct in a direct
// TODO: Currently ((r),disp) is not a used parse-able, but it could be in the future and I did
// all this damn work before realizing I didn't need to so I'm keepig it in
OperandMatchResultTy CPU6AsmParser::parseIndirect(OperandVector &Operands) {

    OperandMatchResultTy result = MatchOperand_ParseFail;

    bool is_one_arg = true;

    // only proceed if we have two left parens
    if ((getLexer().getKind() == AsmToken::LParen)
        && (getLexer().peekTok().getKind() == AsmToken::LParen)) {
    
        Operands.push_back(CPU6Operand::createToken("((", getLoc()));
        getParser().Lex(); // Eat '('
        getParser().Lex(); // Eat '('

        result = parseRegOrImm(Operands);
        dbgs() << "parseIndirect parseRegOrImm result: " << result << "\n";

        // There are two possibilities here, a )) to end our indirect statement,
        // or ',i8imm)', we need to check and parse accordingly

        if(getLexer().getTok().is(AsmToken::RParen) && getLexer().peekTok().is(AsmToken::Comma)) {
            is_one_arg = false;
            dbgs() << "Checking next: " << getLexer().peekTok().getKind() << "\n";
            if (getLexer().peekTok().isNot(AsmToken::RParen)) {
                Operands.push_back(CPU6Operand::createToken(")", getLoc()));
                // If we don't see another paren, we have another arg, it will always be an immediate
                getLexer().Lex(); // eat what is most likely a ','
                getLexer().Lex(); // do it again so the lexer is sitting on the immediate to be parsed
                result = parseImmediate(Operands);
                dbgs() << "parseIndirect parseImmediate number 2 result: " << result << "\n";
                if (result) { // we have a parse failure, get out (result is 0 for success, "false")
                    dbgs() << "detected parse failure, leaving\n";
                    return result;
                }
            }
        }

        dbgs() << "What are we on?: " << getLexer().getKind() << "\n";
        dbgs() << "What's next?: " << getLexer().peekTok().getKind() << "\n";
        
        if (is_one_arg) {
            Operands.push_back(CPU6Operand::createToken("))", getLoc()));
            getParser().Lex(); // Eat ')' 
            getParser().Lex(); // Eat ')'
        } else {
            Operands.push_back(CPU6Operand::createToken(")", getLoc()));
            getParser().Lex(); // Eat ')' 
        }
    }
    return result;

}

OperandMatchResultTy CPU6AsmParser::parsePCOffset(OperandVector &Operands) {
    // Parsing method to extract the actual argument in the PC offset operands
    // If you're reading this I really am sorry. Just know it needs to parse and handle
    // (PC),$arg as well as ((PC),$arg)
    SMLoc Start = getLoc();
    bool OuterParens = false;

    dbgs() << "We made it to parsePCOffset!!!\n";

    // If we aren't at a left paren this isn't right
    if (getLexer().isNot(AsmToken::LParen))
        return MatchOperand_NoMatch;

    dbgs() << "Verified that we're on a left paren\n";

    // Handle the case where we're wrapped in a second pair of parens
    if (getLexer().peekTok().is(AsmToken::LParen))
        OuterParens = true;

    // paren, P, C, paren, plus
    AsmToken::TokenKind Match[] = {
        AsmToken::LParen,
        AsmToken::Identifier,
        AsmToken::RParen,
        AsmToken::Comma
    };
    AsmToken Buf[4];
    size_t ReadCount = getLexer().peekTokens(Buf);
    dbgs() << "Got a ReadCount of: " << ReadCount <<"\n";

    // If we didn't read 3 tokens, or our read tokens don't match what we expect
    if (ReadCount != 4)
        return MatchOperand_NoMatch;

    dbgs() << "About to check the token types\n";
    // Check to make sure the peeked tokens match what we want
    // if we detected a double left paren, check it against Match, otherwise, skip it
    int p = 1;
    int loop = 3;
    if (OuterParens) {
        p--;
        loop++;
    }
    for (int i = 0; i<loop; i++) {
        dbgs() << "Checking: " << Buf[i].getString() << " : " << Buf[i].getKind();
        dbgs() << " against : " << Match[i+p] << "\n";
        if (Buf[i].isNot(Match[i+p]))
            return MatchOperand_NoMatch;
    }

    dbgs() << "Checking that the string " << Buf[0+OuterParens].getString() << " we got was 'PC'\n";
    // Verify the identifiers are 'P' and 'C'
    if (Buf[0+OuterParens].getString().compare(llvm::StringRef("PC")) != 0)
        return MatchOperand_NoMatch;
    dbgs() << "Verified that we got the right string, lexing\n";
    // If we succeeded, we're confident this is where we're meant to be, so we can
    // lex our way through the expression to extract our arg
    // need a +1 because we'll need to be ON the right token to parse, not have it next
    if (!OuterParens)
        ReadCount--;
    while(ReadCount+1) {  
        getLexer().Lex();
        dbgs() << "Lexed: " << getLexer().getTok().getString() << "\n";
        ReadCount--;
    }
    // And emit our token for the matcher
    StringRef tokenstr = "(PC)";
    if (OuterParens)
        tokenstr = "((PC)";
    Operands.push_back(CPU6Operand::createToken(tokenstr, Start));

    // parse our operand, this will also eat our right paren
    dbgs() << "Attempting to parse the token we're at: " << getLexer().getTok().getString() << "\n";
    OperandMatchResultTy result = parseRegOrImm(Operands);
    dbgs() << "Result: " << result << "\n";


    // Handle the case where we're wrapped in a second pair of parens
    if (getLexer().getTok().is(AsmToken::RParen) && OuterParens) {
        Operands.push_back(CPU6Operand::createToken(")", getLoc()));
        getLexer().Lex(); // Eat ')'
    }

    dbgs() << "Checking that we have an end of statement :" << getLexer().getTok().getKind() << "\n";
    if (getLexer().getTok().isNot(AsmToken::EndOfStatement))
        return MatchOperand_ParseFail;

    dbgs() << "We matched!\n";

    // If we got this far, we're good
    return result;

}

/// Looks at a token type and creates the relevant operand from this
/// information, adding to Operands. If operand was parsed, returns false, else
/// true.
bool CPU6AsmParser::parseOperand(OperandVector &Operands, StringRef Mnemonic) {

    //dbgs() << "parseOperand running for Mnemonic " << Mnemonic << "\n";

    // Check if the current operand has a custom associated parser, if so, try to
    // custom parse the operand, or fallback to the general approach.
    // dbgs() << "Attempting MatchOperandParserImpl\n";
    // OperandMatchResultTy Result =
    //     MatchOperandParserImpl(Operands, Mnemonic, /*ParseForAllFeatures=*/true);
    // if (Result == MatchOperand_Success) {
    //     dbgs() << "Return with MatchOperand_Success";
    //     return false;
    // }
    // if (Result == MatchOperand_ParseFail) {
    //     dbgs() << "Return with MatchOperand_ParseFail";
    //     return true;
    // }
    // dbgs() << "Returned with result " << Result << "\n";

    // If we try to parse operands in this fashion, make sure that each function will
    // exit WITHOUT advancing the parser with Lex() or parsing functions, 
    // otherwise subsequent checks will not begin where indended and behavior will collapse

    dbgs() << "Attempting reg or immediate parse\n";
    if (parseRegOrImm(Operands) == MatchOperand_Success)
        return false;

    // Try a PC offset format
    dbgs() << "Attmpting PC offset parse\n";
    if (parsePCOffset(Operands) == MatchOperand_Success)
        return false;

    // Try an indirect
    dbgs() << "Attempting indirect parse\n";
    if (parseIndirect(Operands) == MatchOperand_Success)
        return false;

    // Try a direct
    dbgs() << "Attempting direct parse\n";
    if (parseDirect(Operands) == MatchOperand_Success)
        return false;

    // We've exhausted our options, declare defeat
    Error(getLoc(), "unknown operand");
    return true;
}

// full instruction parsing logic
bool CPU6AsmParser::ParseInstruction(ParseInstructionInfo &Info,
                                     StringRef Name, SMLoc NameLoc,
                                     OperandVector &Operands) {

    // First operand is token for instruction
    Operands.push_back(CPU6Operand::createToken(Name, NameLoc));

    // If there are no more operands, finish
    if (getLexer().is(AsmToken::EndOfStatement)) {
        getParser().Lex(); // Consume the EndOfStatement.
        return false;
    }

    // Parse first operand
    if (parseOperand(Operands, Name))
        return true;

    // Parse until end of statement, consuming commas between operands
    while (getLexer().is(AsmToken::Comma)) {
        // Consume comma token
        getLexer().Lex();

        // Parse next operand
        if (parseOperand(Operands, Name))
        return true;
    }

    // Toss an error if we get get anything other than an endofstatment token after operands
    if (getLexer().isNot(AsmToken::EndOfStatement)) {
        SMLoc Loc = getLexer().getLoc();
        getParser().eatToEndOfStatement();
        return Error(Loc, "unexpected token, expected end of line");
    }

    getParser().Lex(); // Consume the EndOfStatement.
    return false; 
}

// TODO: right now we just skip directives with this, revisit if we want to add them
// directives are .option, .attribute, etc
bool CPU6AsmParser::ParseDirective(AsmToken DirectiveID) { return true; }

extern "C" void LLVMInitializeCPU6AsmParser() {
    RegisterMCAsmParser<CPU6AsmParser> X(getTheCPU6Target());
}