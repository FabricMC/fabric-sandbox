#pragma once

#include <windows.h>
#include <sddl.h>
#include <userenv.h>

DWORD _PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES();

DWORD _PROC_THREAD_ATTRIBUTE_ALL_APPLICATION_PACKAGES_POLICY();

DWORD _MAKELANGID(WORD p, WORD s);

DWORD _SECURITY_MAX_SID_SIZE();

// TODO - again how to do this nicely in swift
LPPROC_THREAD_ATTRIBUTE_LIST allocateAttributeList(size_t dwAttributeCount);

BOOL _IsWindows10OrGreater();

DWORD Win32FromHResult(HRESULT hr);

PSID SidFromAccessAllowedAce(LPVOID ace, DWORD sidStart);

PSID SidFromAccessDeniedAce(LPVOID ace, DWORD sidStart);