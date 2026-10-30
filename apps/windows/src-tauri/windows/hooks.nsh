; Inno Setup uninstall key of the Flutter build, which installs to the same directory (AppId from ADR 0006).
!define FLUTTER_UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\{67A8CFA2-EC79-4DD3-AB44-75CDD5C3B591}_is1"

!macro NSIS_HOOK_PREINSTALL
  Push $0
  Push $1
  ReadRegStr $0 HKLM "${FLUTTER_UNINSTALL_KEY}" "UninstallString"
  ${If} $0 != ""
    DetailPrint "Removing the Flutter build of po0-clash"
    ExecWait '$0 /VERYSILENT /SUPPRESSMSGBOXES /NORESTART' $1
    ; Its unelevated Run entry would now start this elevated app behind a UAC prompt at every sign-in.
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "po0-clash"
  ${EndIf}
  Pop $1
  Pop $0
!macroend

!macro NSIS_HOOK_POSTUNINSTALL
  ${If} $UpdateMode <> 1
    nsExec::Exec 'schtasks /Delete /TN po0-clash /F'
    Pop $0
  ${EndIf}
!macroend
