#include "WinSDKExtras.h"

#include <userenv.h>
#include <VersionHelpers.h>

HRESULT _CreateAppContainerProfile(
    _In_ PCWSTR pszAppContainerName,
    _In_ PCWSTR pszDisplayName,
    _In_ PCWSTR pszDescription,
    _In_ PSID_AND_ATTRIBUTES pCapabilities,
    _In_  DWORD dwCapabilityCount,
    _Outptr_ PSID* ppSidAppContainerSid) {
        return CreateAppContainerProfile(
            pszAppContainerName,
            pszDisplayName,
            pszDescription,
            pCapabilities,
            dwCapabilityCount,
            ppSidAppContainerSid);
}

HRESULT _DeleteAppContainerProfile(
    _In_ PCWSTR pszAppContainerName) {
    return DeleteAppContainerProfile(pszAppContainerName);
}

HRESULT _DeriveAppContainerSidFromAppContainerName(
    _In_ PCWSTR pszAppContainerName,
    _Outptr_ PSID* ppSidAppContainerSid)
{
    return DeriveAppContainerSidFromAppContainerName(
        pszAppContainerName,
        ppSidAppContainerSid);
}

BOOL _DeriveCapabilitySidsFromName(
  _In_  LPCWSTR CapName,
  _Outptr_ PSID    **CapabilityGroupSids,
  _Outptr_ DWORD   *CapabilityGroupSidCount,
  _Outptr_ PSID    **CapabilitySids,
  _Outptr_ DWORD   *CapabilitySidCount
) {
    return DeriveCapabilitySidsFromName(
        CapName,
        CapabilityGroupSids,
        CapabilityGroupSidCount,
        CapabilitySids,
        CapabilitySidCount);
}

DWORD _PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES() {
    return PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES;
}

DWORD _PROC_THREAD_ATTRIBUTE_ALL_APPLICATION_PACKAGES_POLICY() {
    return ProcThreadAttributeValue(ProcThreadAttributeAllApplicationPackagesPolicy, FALSE, TRUE, FALSE);
}

DWORD _MAKELANGID(WORD p, WORD s) {
    return MAKELANGID(p, s);
}

DWORD _SECURITY_MAX_SID_SIZE() {
    return SECURITY_MAX_SID_SIZE;
}

LPWCH _CASTSID(PSID pSid) {
    return static_cast<LPWCH>(pSid);
}

LPPROC_THREAD_ATTRIBUTE_LIST allocateAttributeList(size_t size) {
    return (LPPROC_THREAD_ATTRIBUTE_LIST)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, size);
}

BOOL _IsWindows10OrGreater() {
    return IsWindows10OrGreater();
}

// https://stackoverflow.com/a/22234308
DWORD Win32FromHResult(HRESULT hr) {
    if ((hr & 0xFFFF0000) == MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, 0)) {
        return HRESULT_CODE(hr);
    }
    if (hr == S_OK) {
        return ERROR_SUCCESS;
    }
    // Not a Win32 HRESULT so return a generic error code.
    return ERROR_CAN_NOT_COMPLETE;
}