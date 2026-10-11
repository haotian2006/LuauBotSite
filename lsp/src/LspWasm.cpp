// luau-lsp inside the playground's web worker. There is no stdio or message thread here: the worker
// passes each JSON-RPC message to lsp_send and gets back a JSON array of everything the server sent.

#include "LSP/LanguageServer.hpp"
#include "LSP/DocumentationParser.hpp"
#include "Flags.hpp"
#include "Luau/BuiltinDefinitions.h"
#include "Luau/ConstraintSolver.h"
#include "Luau/ExperimentalFlags.h"
#include "Luau/StringUtils.h"
#include "Luau/TypeInfer.h"

#include <emscripten/emscripten.h>

#include <cstdio>
#include <cstring>

LUAU_FASTFLAG(LuauSolverV2)

namespace
{
struct BufferTransport : Transport
{
    std::string batch = "[";

    void send(const std::string& data) override
    {
        // json_rpc frames every message with a Content-Length header.
        size_t body = data.find("\r\n\r\n");
        if (batch.size() > 1)
            batch += ',';
        batch.append(data, body == std::string::npos ? 0 : body + 4, std::string::npos);
    }

    void read(char*, unsigned int) override {}

    bool readLine(std::string&) override
    {
        return false;
    }
};

// Resolves io.import("<spec>") to a package the page downloaded and the worker added to the
// sourcemap; every other require goes to luau-lsp's resolver.
struct ImportResolver : Luau::FileResolver
{
    Luau::FileResolver* inner = nullptr;
    std::unordered_map<std::string, std::string> virtualPaths; // spec → sourcemap path

    std::optional<Luau::SourceCode> readSource(const Luau::ModuleName& name) override
    {
        return inner->readSource(name);
    }

    std::optional<Luau::ModuleInfo> resolveModule(const Luau::ModuleInfo* context, Luau::AstExpr* expr, const Luau::TypeCheckLimits& limits) override
    {
        auto* call = expr->as<Luau::AstExprCall>();
        auto* func = call && !call->self && call->args.size == 1 ? call->func->as<Luau::AstExprIndexName>() : nullptr;
        auto* io = func && func->index == "import" ? func->expr->as<Luau::AstExprGlobal>() : nullptr;
        auto* spec = io && io->name == "io" ? call->args.data[0]->as<Luau::AstExprConstantString>() : nullptr;
        if (spec)
        {
            if (auto it = virtualPaths.find(std::string(spec->value.data, spec->value.size)); it != virtualPaths.end())
                return Luau::ModuleInfo{it->second};
        }
        return inner->resolveModule(context, expr, limits);
    }

    std::string getHumanReadableModuleName(const Luau::ModuleName& name) const override
    {
        return inner->getHumanReadableModuleName(name);
    }

    std::optional<std::string> getEnvironmentForModule(const Luau::ModuleName& name) const override
    {
        return inner->getEnvironmentForModule(name);
    }
};

ImportResolver importResolver;

// The instance type luau-lsp built from the sourcemap for a loaded spec, i.e. the type of
// game.PlaygroundImports.importN, children included.
std::optional<Luau::TypeId> packageType(const Luau::Scope& scope, const Luau::AstExprCall& call)
{
    auto* spec = call.args.size == 1 ? call.args.data[0]->as<Luau::AstExprConstantString>() : nullptr;
    auto it = spec ? importResolver.virtualPaths.find(std::string(spec->value.data, spec->value.size)) : importResolver.virtualPaths.end();
    auto dataModel = scope.lookupType("DataModel");
    if (it == importResolver.virtualPaths.end() || !dataModel || !Luau::startsWith(it->second, "game/"))
        return std::nullopt;

    Luau::TypeId ty = dataModel->type;
    std::string path = it->second.substr(5); // split returns views into it
    for (const auto& name : Luau::split(path, '/'))
    {
        auto* instance = Luau::get<Luau::ExternType>(Luau::follow(ty));
        auto prop = instance ? instance->props.find(std::string(name)) : Luau::ExternType::Props::iterator{};
        if (!instance || prop == instance->props.end() || !prop->second.readTy)
            return std::nullopt;
        ty = *prop->second.readTy;
    }
    return ty;
}

// io.import("<spec>") returns that package's instance type instead of a plain Instance.
struct MagicImport final : Luau::MagicFunction
{
    std::optional<Luau::WithPredicate<Luau::TypePackId>> handleOldSolver(
        Luau::TypeChecker& typeChecker, const Luau::ScopePtr& scope, const Luau::AstExprCall& expr, Luau::WithPredicate<Luau::TypePackId>) override
    {
        if (auto ty = packageType(*scope, expr))
            return Luau::WithPredicate<Luau::TypePackId>{typeChecker.currentModule->internalTypes->addTypePack({*ty})};
        return std::nullopt;
    }

    bool infer(const Luau::MagicFunctionCallContext& context) override
    {
        auto ty = packageType(*context.constraint->scope, *context.callSite);
        if (!ty)
            return false;
        asMutable(context.result)->ty.emplace<Luau::BoundTypePack>(context.solver->arena->addTypePack({*ty}));
        return true;
    }
};

void attachImportMagic(Luau::GlobalTypes& globals)
{
    auto binding = globals.globalScope->bindings.find(globals.globalNames.names->getOrAdd("io"));
    if (binding == globals.globalScope->bindings.end())
        return;
    if (auto* io = Luau::getMutable<Luau::TableType>(Luau::follow(binding->second.typeId)))
        if (auto import = io->props.find("import"); import != io->props.end() && import->second.readTy)
            Luau::attachMagicFunction(*import->second.readTy, std::make_shared<MagicImport>());
}

BufferTransport* transport = nullptr;
LSPClient* client = nullptr;
LanguageServer* server = nullptr;
std::string reply;

void logFlagMessage(const std::string& message)
{
    fprintf(stderr, "%s\n", message.c_str());
}

const char* flush()
{
    reply = std::move(transport->batch);
    reply += ']';
    transport->batch = "[";
    return reply.c_str();
}
} // namespace

extern "C"
{
    // options: { fflags: {name: value}, definitions: {"@roblox": path}, settings: ClientConfiguration }
    EMSCRIPTEN_KEEPALIVE void lsp_start(const char* optionsJson)
    {
        json options = json::parse(optionsJson);

        // Same defaults as the luau-lsp CLI: every non-experimental Luau flag on, then overrides.
        for (Luau::FValue<bool>* flag = Luau::FValue<bool>::list; flag; flag = flag->next)
            if (strncmp(flag->name, "Luau", 4) == 0 && !Luau::isAnalysisFlagExperimental(flag->name))
                flag->value = true;
        auto fflags = options.value("fflags", std::unordered_map<std::string, std::string>{});
        registerFastFlags(fflags, logFlagMessage, logFlagMessage);
        applyRequiredFlags();

        auto bufferTransport = std::make_unique<BufferTransport>();
        transport = bufferTransport.get();
        client = new LSPClient(std::move(bufferTransport));
        client->definitionsFiles = options.value("definitions", std::unordered_map<std::string, std::string>{});
        client->globalConfig = options.value("settings", json::object()).get<ClientConfiguration>();
        server = new LanguageServer(client, std::nullopt);
    }

    EMSCRIPTEN_KEEPALIVE const char* lsp_send(const char* message)
    {
        try
        {
            server->handleMessage(json_rpc::parse(message));
        }
        catch (const json::exception& e)
        {
            client->sendError(std::nullopt, JsonRpcException(lsp::ErrorCode::ParseError, e.what()));
        }
        return flush();
    }

    // imports: { spec: "game/..." }, replacing the previous set. Every module is rechecked.
    EMSCRIPTEN_KEEPALIVE const char* lsp_set_imports(const char* importsJson)
    {
        auto workspace = server->findWorkspace(Uri::parse("file:///workspace"));
        Luau::Frontend& frontend = workspace->frontend;
        if (frontend.fileResolver != &importResolver)
        {
            importResolver.inner = frontend.fileResolver;
            importResolver.requireSuggester = frontend.fileResolver->requireSuggester;
            frontend.fileResolver = &importResolver;
            attachImportMagic(frontend.globals);
            if (!FFlag::LuauSolverV2)
                attachImportMagic(frontend.globalsForAutocomplete);
        }
        importResolver.virtualPaths = json::parse(importsJson).get<std::unordered_map<std::string, std::string>>();
        frontend.clear();
        return flush();
    }

    // Documentation only feeds hovers and completion details, so it can load after the types.
    EMSCRIPTEN_KEEPALIVE const char* lsp_load_documentation(const char* path)
    {
        parseDocumentation({path}, client->documentation, client);
        return flush();
    }
}
