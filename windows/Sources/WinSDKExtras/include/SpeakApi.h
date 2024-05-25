#pragma once

#include <string>
#include <windows.h>
#include <memory>

class SpeakApi {
    public:
    SpeakApi();
    ~SpeakApi();
    SpeakApi(const SpeakApi& other);

    public:
    HRESULT Speak(std::wstring text, DWORD dwFlags);
    HRESULT Skip();

    private:
    // Pointer to implementation idiom, with a shared pointer so the object can be copied by swift
    class Impl; std::shared_ptr<Impl> pImpl;
};