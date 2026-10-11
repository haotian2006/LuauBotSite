// Luau VM for the playground's Run Local mode. The worker drives a small task scheduler around it:
// run_step resumes every task that is due and returns how many ms to wait before calling it again.

#include "lua.h"
#include "lualib.h"
#include "luacode.h"
#include "Luau/Common.h"

#include <emscripten/emscripten.h>

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unordered_map>
#include <vector>

EM_JS(void, emitOutput, (int kind, const char* text, size_t length), { Module.onOutput(kind, UTF8ToString(text, length)); });

namespace
{
enum OutputKind
{
    Print = 0,
    Warn = 1,
    Error = 2,
};

struct Task
{
    uint64_t id;
    int ref; // keeps the thread alive while it is queued
    lua_State* thread;
    double wakeAt;
    double queuedAt;
    int nargs; // values already on the thread's stack; -1 resumes with the seconds waited
};

const char* const kModulesKey = "playground.modules";

lua_State* globalState = nullptr;
std::vector<Task> tasks;
uint64_t nextTaskId = 0;
std::unordered_map<std::string, std::string> modules;
std::string output;
OutputKind outputKind = Print;
double lastFlush = 0;

void flushOutput()
{
    if (!output.empty())
        emitOutput(outputKind, output.data(), output.size());
    output.clear();
    lastFlush = emscripten_get_now();
}

void write(OutputKind kind, const char* text, size_t length)
{
    if (kind != outputKind)
    {
        flushOutput();
        outputKind = kind;
    }
    output.append(text, length);
    output += '\n';
    if (output.size() > 16384 || emscripten_get_now() - lastFlush > 50)
        flushOutput();
}

void writeArgs(lua_State* L, OutputKind kind)
{
    std::string line;
    int n = lua_gettop(L);
    for (int i = 1; i <= n; i++)
    {
        size_t length;
        const char* text = luaL_tolstring(L, i, &length);
        if (i > 1)
            line += '\t';
        line.append(text, length);
        lua_pop(L, 1);
    }
    write(kind, line.data(), line.size());
}

void reportError(lua_State* T)
{
    size_t length;
    const char* message = luaL_tolstring(T, -1, &length);
    write(Error, message, length);
    lua_settop(T, 0);
}

// Keeps output moving while a script loops without printing.
void interrupt(lua_State*, int)
{
    if (!output.empty() && emscripten_get_now() - lastFlush > 50)
        flushOutput();
}

bool load(lua_State* L, const std::string& name, const char* source, size_t size)
{
    lua_CompileOptions options = {};
    options.optimizationLevel = 1;
    options.debugLevel = 1;
    size_t bytecodeSize = 0;
    char* bytecode = luau_compile(source, size, &options, &bytecodeSize);
    int status = luau_load(L, ("=" + name).c_str(), bytecode, bytecodeSize, 0);
    free(bytecode);
    return status == 0;
}

void schedule(lua_State* thread, double delayMs, int nargs)
{
    lua_pushthread(thread);
    int ref = lua_ref(thread, -1);
    lua_pop(thread, 1);
    double now = emscripten_get_now();
    tasks.push_back({nextTaskId++, ref, thread, now + std::max(delayMs, 0.0), now, nargs});
}

void resume(const Task& task)
{
    lua_State* T = task.thread;
    if (lua_costatus(globalState, T) == LUA_COSUS)
    {
        int nargs = task.nargs;
        if (nargs < 0)
        {
            lua_pushnumber(T, (emscripten_get_now() - task.queuedAt) / 1000);
            nargs = 1;
        }
        int status = lua_resume(T, nullptr, nargs);
        if (status != LUA_OK && status != LUA_YIELD && status != LUA_BREAK)
            reportError(T);
    }
    lua_unref(globalState, task.ref);
}

// Turns the arguments from `first` up into a thread ready to resume: a thread argument is reused,
// a function gets a new thread. Leaves the thread on top of L.
lua_State* takeThread(lua_State* L, int first, int& nargs)
{
    nargs = lua_gettop(L) - first;
    if (lua_isthread(L, first))
    {
        lua_State* T = lua_tothread(L, first);
        lua_xmove(L, T, nargs);
        return T;
    }
    luaL_checktype(L, first, LUA_TFUNCTION);
    lua_State* T = lua_newthread(L);
    lua_insert(L, first);
    lua_xmove(L, T, nargs + 1);
    return T;
}

int luaPrint(lua_State* L)
{
    writeArgs(L, Print);
    return 0;
}

int luaWarn(lua_State* L)
{
    writeArgs(L, Warn);
    return 0;
}

int taskWait(lua_State* L)
{
    double seconds = luaL_optnumber(L, 1, 0);
    if (!lua_isyieldable(L))
        luaL_error(L, "attempt to yield across a C-call boundary (task.wait inside require or a metamethod)");
    schedule(L, seconds * 1000, -1);
    return lua_yield(L, 0);
}

int taskSpawn(lua_State* L)
{
    int nargs;
    lua_State* T = takeThread(L, 1, nargs);
    int status = lua_resume(T, L, nargs);
    if (status != LUA_OK && status != LUA_YIELD && status != LUA_BREAK)
        reportError(T);
    return 1;
}

int taskDefer(lua_State* L)
{
    int nargs;
    lua_State* T = takeThread(L, 1, nargs);
    schedule(T, 0, nargs);
    return 1;
}

int taskDelay(lua_State* L)
{
    double seconds = luaL_checknumber(L, 1);
    int nargs;
    lua_State* T = takeThread(L, 2, nargs);
    schedule(T, seconds * 1000, nargs);
    return 1;
}

int taskCancel(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TTHREAD);
    lua_State* T = lua_tothread(L, 1);
    for (auto it = tasks.begin(); it != tasks.end();)
    {
        if (it->thread == T)
        {
            lua_unref(L, it->ref);
            it = tasks.erase(it);
        }
        else
            ++it;
    }
    return 0;
}

// require("name") loads another playground file. Modules run to completion and can't yield.
int luaRequire(lua_State* L)
{
    std::string name = luaL_checkstring(L, 1);
    lua_getfield(L, LUA_REGISTRYINDEX, kModulesKey);
    lua_getfield(L, -1, name.c_str());
    if (lua_islightuserdata(L, -1))
        luaL_error(L, "Circular require: %s", name.c_str());
    if (!lua_isnil(L, -1))
        return 1;
    lua_pop(L, 1);

    auto it = modules.find(name);
    if (it == modules.end())
        luaL_error(L, "Module '%s' not found", name.c_str());

    lua_pushlightuserdata(L, &modules);
    lua_setfield(L, -2, name.c_str());

    lua_State* T = lua_newthread(L);
    luaL_sandboxthread(T);
    if (!load(T, name, it->second.data(), it->second.size()) || lua_pcall(T, 0, 1, 0) != LUA_OK)
    {
        lua_pushnil(L);
        lua_setfield(L, -3, name.c_str());
        lua_xmove(T, L, 1);
        lua_error(L);
    }
    lua_xmove(T, L, 1);
    lua_pushvalue(L, -1);
    lua_setfield(L, -4, name.c_str());
    return 1;
}

void createState()
{
    lua_State* L = luaL_newstate();
    lua_callbacks(L)->interrupt = interrupt;
    luaL_openlibs(L);

    const luaL_Reg globals[] = {
        {"print", luaPrint},
        {"warn", luaWarn},
        {"require", luaRequire},
        {"wait", taskWait},
        {nullptr, nullptr},
    };
    lua_pushvalue(L, LUA_GLOBALSINDEX);
    luaL_register(L, nullptr, globals);
    lua_pop(L, 1);

    const luaL_Reg task[] = {
        {"wait", taskWait},
        {"spawn", taskSpawn},
        {"defer", taskDefer},
        {"delay", taskDelay},
        {"cancel", taskCancel},
        {nullptr, nullptr},
    };
    luaL_register(L, "task", task);
    lua_pop(L, 1);

    lua_newtable(L);
    lua_setfield(L, LUA_REGISTRYINDEX, kModulesKey);

    luaL_sandbox(L);
    globalState = L;
}
} // namespace

extern "C"
{
    EMSCRIPTEN_KEEPALIVE void run_set_flag(const char* name, int value)
    {
        for (Luau::FValue<bool>* flag = Luau::FValue<bool>::list; flag; flag = flag->next)
            if (strcmp(flag->name, name) == 0)
                flag->value = value != 0;
    }

    // Fresh VM for every run; flags must be set before this.
    EMSCRIPTEN_KEEPALIVE void run_reset()
    {
        if (globalState)
            lua_close(globalState);
        tasks.clear();
        modules.clear();
        output.clear();
        createState();
    }

    EMSCRIPTEN_KEEPALIVE void run_add_module(const char* name, const char* source)
    {
        modules[name] = source;
    }

    EMSCRIPTEN_KEEPALIVE void run_start(const char* name, const char* source)
    {
        lua_State* T = lua_newthread(globalState);
        luaL_sandboxthread(T);
        if (load(T, name, source, strlen(source)))
            schedule(T, 0, 0);
        else
            reportError(T);
        lua_pop(globalState, 1);
        flushOutput();
    }

    // Returns ms until the next task is due, or -1 once nothing is left to run.
    EMSCRIPTEN_KEEPALIVE double run_step()
    {
        double now = emscripten_get_now();
        uint64_t limit = nextTaskId; // tasks queued during this step wait for the next one
        for (;;)
        {
            auto due = tasks.end();
            for (auto it = tasks.begin(); it != tasks.end(); ++it)
                if (it->id < limit && it->wakeAt <= now && (due == tasks.end() || it->wakeAt < due->wakeAt))
                    due = it;
            if (due == tasks.end())
                break;
            Task task = *due;
            tasks.erase(due);
            resume(task);
        }
        flushOutput();

        if (tasks.empty())
            return -1;
        double next = tasks.front().wakeAt;
        for (const Task& task : tasks)
            next = std::min(next, task.wakeAt);
        return std::max(0.0, next - emscripten_get_now());
    }
}

int main()
{
    for (Luau::FValue<bool>* flag = Luau::FValue<bool>::list; flag; flag = flag->next)
        if (strncmp(flag->name, "Luau", 4) == 0)
            flag->value = true;
    return 0;
}
