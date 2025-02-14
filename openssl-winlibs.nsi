;-----------------------------------------------------------------------------
;
;  Copyright (c) 2025, Thierry Lelegard
;  BSD-2-Clause license, see LICENSE file
;
;  NSIS script to build the installer for the OpenSSL Libraries for Windows.
;  Do not invoke NSIS directly, use PowerShell script build.ps1 to ensure
;  that all parameters are properly passed.
;
;-----------------------------------------------------------------------------

Name "OpenSSL-WinLibs"
Caption "OpenSSL Libraries for Windows"

!verbose push
!verbose 0
!include "MUI2.nsh"
!include "Sections.nsh"
!include "TextFunc.nsh"
!include "FileFunc.nsh"
!include "WinMessages.nsh"
!include "x64.nsh"
!verbose pop

!define ProductName "OpenSSL-WinLibs"

; Installer file information.
VIProductVersion ${VersionInfo}
VIAddVersionKey ProductName "${ProductName}"
VIAddVersionKey ProductVersion "${Version}"
VIAddVersionKey Comments "OpenSSL Libraries for Windows (all architectures)"
VIAddVersionKey CompanyName "OpenSSL"
VIAddVersionKey LegalCopyright "Copyright (c) 1998-2025 The OpenSSL Project Authors"
VIAddVersionKey FileVersion "${VersionInfo}"
VIAddVersionKey FileDescription "OpenSSL WinLibs Installer"

; Name of binary installer file.
OutFile "${OutFile}"

; Generate a Unicode installer (default is ANSI).
Unicode true

; Registry key for environment variables
!define EnvironmentKey '"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"'

; Registry entry for product info and uninstallation info.
!define ProductKey "Software\${ProductName}"
!define UninstallKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ProductName}"

; Use XP manifest.
XPStyle on

; Request administrator privileges for Windows Vista and higher.
RequestExecutionLevel admin

; "Modern User Interface" (MUI) settings.
!define MUI_ABORTWARNING

; Get installation folder from registry if available from a previous installation.
InstallDirRegKey HKLM "${ProductKey}" "InstallDir"

; Installer pages.
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

; Uninstaller pages.
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Languages.
!insertmacro MUI_LANGUAGE "English"

; Installation initialization.
function .onInit
    ${If} ${RunningX64}
    ${OrIf} ${IsNativeARM64}
        SetRegView 64
        ; Default installation folder.
        StrCpy $INSTDIR "$PROGRAMFILES64\${ProductName}"
    ${Else}
        StrCpy $INSTDIR "$PROGRAMFILES\${ProductName}"
    ${EndIf}
functionEnd

; Uninstallation initialization.
function un.onInit
    ${If} ${RunningX64}
    ${OrIf} ${IsNativeARM64}
        SetRegView 64
    ${EndIf}
functionEnd

; Installation section
Section "Install"

    ; Work on "all users" context, not current user.
    SetShellVarContext all

    ; The output structure was built by the PowerShell script.
    SetOutPath "$INSTDIR"
    File /r "${InDir}\*"

    ; Add an environment variable to installation root.
    WriteRegStr HKLM ${EnvironmentKey} "OPENSSL_WINLIBS" "$INSTDIR"

    ; Store installation folder in registry.
    WriteRegStr HKLM "${ProductKey}" "InstallDir" $INSTDIR

    ; Create uninstaller
    WriteUninstaller "$INSTDIR\Uninstall.exe"
 
    ; Declare uninstaller in "Add/Remove Software" control panel
    WriteRegStr HKLM "${UninstallKey}" "DisplayName" "${ProductName}"
    WriteRegStr HKLM "${UninstallKey}" "Publisher" "OpenSSL"
    WriteRegStr HKLM "${UninstallKey}" "DisplayVersion" "${Version}"
    WriteRegStr HKLM "${UninstallKey}" "DisplayIcon" "$INSTDIR\Uninstall.exe"
    WriteRegStr HKLM "${UninstallKey}" "UninstallString" "$INSTDIR\Uninstall.exe"

    ; Get estimated size of installed files
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM "${UninstallKey}" "EstimatedSize" "$0"

    ; Notify applications of environment modifications
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000

SectionEnd

; Uninstallation section
Section "Uninstall"

    ; Work on "all users" context, not current user.
    SetShellVarContext all

    ; Get installation folder from registry
    ReadRegStr $0 HKLM "${ProductKey}" "InstallDir"

    ; Delete product registry entries
    DeleteRegKey HKCU "${ProductKey}"
    DeleteRegKey HKLM "${ProductKey}"
    DeleteRegKey HKLM "${UninstallKey}"
    DeleteRegValue HKLM ${EnvironmentKey} "OPENSSL_WINLIBS"

    ; Delete product files.
    RMDir /r "$0\Arm64"
    RMDir /r "$0\Win64"
    RMDir /r "$0\Win32"
    RMDir /r "$0\sample"
    Delete "$0\openssl*.props"
    Delete "$0\license.txt"
    Delete "$0\Uninstall.exe"
    RMDir "$0"

    ; Notify applications of environment modifications
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000

SectionEnd
