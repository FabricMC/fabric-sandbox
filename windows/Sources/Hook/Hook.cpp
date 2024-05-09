#include "Runtime-Swift.h"

#include <windows.h>
#include <Detours.h>
#include <string>
#include <stdexcept>
#include <sapi.h>
#include <AtlBase.h>
#include <AtlConv.h>

using namespace std::string_literals;
#pragma clang diagnostic ignored "-Wmicrosoft-cast"

// Workaround for GetVolumeInformationW not working in a UWP application
// This is by creating a handle to a file on the drive and then using GetVolumeInformationByHandleW with that handle
static BOOL (WINAPI* TrueGetVolumeInformationW)(LPCWSTR, LPWSTR, DWORD, LPDWORD, LPDWORD, LPDWORD, LPWSTR, DWORD) = GetVolumeInformationW;
BOOL WINAPI GetVolumeInformationWPatch(
    _In_opt_ LPCWSTR lpRootPathName,
    _Out_writes_opt_(nVolumeNameSize) LPWSTR lpVolumeNameBuffer,
    _In_ DWORD nVolumeNameSize,
    _Out_opt_ LPDWORD lpVolumeSerialNumber,
    _Out_opt_ LPDWORD lpMaximumComponentLength,
    _Out_opt_ LPDWORD lpFileSystemFlags,
    _Out_writes_opt_(nFileSystemNameSize) LPWSTR lpFileSystemNameBuffer,
    _In_ DWORD nFileSystemNameSize
    ) {
    BOOL result = TrueGetVolumeInformationW(
            lpRootPathName,
            lpVolumeNameBuffer,
            nVolumeNameSize,
            lpVolumeSerialNumber,
            lpMaximumComponentLength,
            lpFileSystemFlags,
            lpFileSystemNameBuffer,
            nFileSystemNameSize);
    auto originalError = GetLastError();
    if (originalError != ERROR_DIR_NOT_ROOT && originalError != ERROR_ACCESS_DENIED) {
        // Only apply our workaround if the error is ERROR_DIR_NOT_ROOT or ERROR_ACCESS_DENIED
        return result;
    }

    std::wstring fileName;

    if (lpRootPathName == nullptr || lpRootPathName[0] == L'\0') {
        // If the root path is null or empty, use the current directory
        fileName = L".";
    } else {
        // Otherwise, use the root path
        fileName = lpRootPathName;
    }

    fileName += L"\\.fabricSandbox";

    auto hFile = CreateFileW(fileName.c_str(), 0, FILE_SHARE_READ, nullptr, OPEN_ALWAYS, 0, nullptr);
    if (hFile == INVALID_HANDLE_VALUE) {
        // Reset the last error to the original error
        SetLastError(originalError);
        return result;
    }

    // Call GetVolumeInformationByHandleW with the handle to the file
    result = GetVolumeInformationByHandleW(
        hFile,
        lpVolumeNameBuffer,
        nVolumeNameSize,
        lpVolumeSerialNumber,
        lpMaximumComponentLength,
        lpFileSystemFlags,
        lpFileSystemNameBuffer, 
        nFileSystemNameSize);

    CloseHandle(hFile);

    if (!result) {
        // If GetVolumeInformationByHandleW fails, reset the last error to the original error
        SetLastError(originalError);
    }

    return result;
}

// Forward ClipCursor and SetCursorPos, to the parnet process as these functions are not available in UWP
static BOOL (WINAPI* TrueClipCursor)(const RECT*) = ClipCursor;
BOOL WINAPI ClipCursorPatch(const RECT* lpRect) {
    if (lpRect == nullptr) {
        Runtime::clipCursor(-1, -1, -1, -1);
    } else {
        Runtime::clipCursor(lpRect->left, lpRect->top, lpRect->right, lpRect->bottom);
    }
    return true;
}

static BOOL (WINAPI* TrueSetCursorPos)(int, int) = SetCursorPos;
BOOL WINAPI SetCursorPosPatch(int x, int y) {
    Runtime::setCursorPos(x, y);
    return true;
}

HRESULT __stdcall SpeakPatch(ISpVoice* This, LPCWSTR pwcs, DWORD dwFlags, ULONG *pulStreamNumber) {
    CW2A utf8(pwcs, CP_UTF8);
    Runtime::speak(utf8.m_psz, dwFlags);
    return S_OK;
}

// Look away now, there has to be a better way to do this
void* getTrueSpeak() {
    CoInitializeEx(nullptr, 0);
    void* spvoice;
    CoCreateInstance(CLSID_SpVoice, nullptr, CLSCTX_ALL, IID_ISpVoice, &spvoice);
    void** vtable = *(void***)spvoice;
    //CoUninitialize(); // Is it that bad if we don't uninitialize?
    return vtable[20]; // Woo magic numbers
}

BOOL WINAPI DllMain(HINSTANCE hinst, DWORD dwReason, LPVOID reserved) {
    if (DetourIsHelperProcess()) {
        return true;
    }

    if (dwReason == DLL_PROCESS_ATTACH) {
        auto TrueSpeak = getTrueSpeak();
        Runtime::processAttach();
        DetourRestoreAfterWith();

        DetourTransactionBegin();
        DetourUpdateThread(GetCurrentThread());
        DetourAttach(&(PVOID&)TrueGetVolumeInformationW, GetVolumeInformationWPatch);
        DetourAttach(&(PVOID&)TrueClipCursor, ClipCursorPatch);
        DetourAttach(&(PVOID&)TrueSetCursorPos, SetCursorPosPatch);
        DetourAttach(&(PVOID&)TrueSpeak, SpeakPatch);
        DetourTransactionCommit();
    } else if (dwReason == DLL_PROCESS_DETACH) {
        auto TrueSpeak = getTrueSpeak();
        DetourTransactionBegin();
        DetourUpdateThread(GetCurrentThread());
        DetourDetach(&(PVOID&)TrueGetVolumeInformationW, GetVolumeInformationWPatch);
        DetourDetach(&(PVOID&)TrueClipCursor, ClipCursorPatch);
        DetourDetach(&(PVOID&)TrueSetCursorPos, SetCursorPosPatch);
        DetourDetach(&(PVOID&)TrueSpeak, SpeakPatch);
        DetourTransactionCommit();
        Runtime::processDetach();
    }
    return true;
}