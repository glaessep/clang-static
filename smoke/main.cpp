// Index sample.cpp with clang::index and print one line per function
// definition and per call, sorted.
#include "clang/AST/ASTContext.h"
#include "clang/AST/Decl.h"
#include "clang/Basic/SourceManager.h"
#include "clang/Frontend/FrontendAction.h"
#include "clang/Index/IndexDataConsumer.h"
#include "clang/Index/IndexSymbol.h"
#include "clang/Index/IndexingAction.h"
#include "clang/Tooling/Tooling.h"

#include <algorithm>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

namespace {

class Collector : public clang::index::IndexDataConsumer {
public:
  std::vector<std::string> Lines;

  void initialize(clang::ASTContext &Ctx) override { Context = &Ctx; }

  bool handleDeclOccurrence(
      const clang::Decl *D, clang::index::SymbolRoleSet Roles,
      llvm::ArrayRef<clang::index::SymbolRelation>, clang::SourceLocation Loc,
      ASTNodeInfo) override {
    const auto *FD = llvm::dyn_cast<clang::FunctionDecl>(D);
    if (!FD)
      return true;
    const clang::SourceManager &SM = Context->getSourceManager();
    if (!SM.isInMainFile(Loc))
      return true;
    const char *Kind = nullptr;
    if (Roles & static_cast<unsigned>(clang::index::SymbolRole::Definition))
      Kind = "def";
    else if (Roles & static_cast<unsigned>(clang::index::SymbolRole::Call))
      Kind = "call";
    if (!Kind)
      return true;
    std::ostringstream Out;
    Out << Kind << ' ' << FD->getNameAsString() << '(';
    for (unsigned I = 0; I < FD->getNumParams(); ++I) {
      if (I)
        Out << ", ";
      Out << FD->getParamDecl(I)->getType().getAsString();
    }
    Out << ") line " << SM.getSpellingLineNumber(Loc);
    Lines.push_back(Out.str());
    return true;
  }

private:
  clang::ASTContext *Context = nullptr;
};

} // namespace

int main(int argc, char **argv) {
  if (argc != 2) {
    std::cerr << "usage: smoke <source-file>\n";
    return 2;
  }
  std::ifstream In(argv[1]);
  if (!In) {
    std::cerr << "cannot read " << argv[1] << '\n';
    return 2;
  }
  std::stringstream Buffer;
  Buffer << In.rdbuf();

  auto Consumer = std::make_shared<Collector>();
  clang::index::IndexingOptions Options;
  Options.SystemSymbolFilter =
      clang::index::IndexingOptions::SystemSymbolFilterKind::None;
  std::unique_ptr<clang::FrontendAction> Action =
      clang::index::createIndexingAction(Consumer, Options);

  bool Ok = clang::tooling::runToolOnCodeWithArgs(
      std::move(Action), Buffer.str(), {"-std=c++17", "-fsyntax-only"},
      "sample.cpp");
  if (!Ok) {
    std::cerr << "indexing failed\n";
    return 1;
  }
  std::sort(Consumer->Lines.begin(), Consumer->Lines.end());
  for (const std::string &Line : Consumer->Lines)
    std::cout << Line << '\n';
  return 0;
}
