#pragma once

// Shadows luau-lsp's src/include/Thread.hpp. Wasm has no threads: LanguageServer would start its
// message thread here, but the worker calls handleMessage directly, so the thread body never runs.
class Thread
{
public:
    Thread() = default;

    template<typename Callable>
    explicit Thread(Callable&&)
    {
    }

    bool joinable() const
    {
        return false;
    }

    void join() {}
};
