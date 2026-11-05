/*
 * SPDX-License-Identifier: MIT
 *
 * steamwebhelper-wrapper – Teil von Windows-Bridge
 * Basiert auf dem Wrapper aus https://github.com/notpop/steam-on-m1-wine
 * (MIT License, Copyright (c) 2026 notpop).
 *
 * Warum?
 *   Steam zeichnet seine Oberfläche mit einem eingebauten Chromium (CEF).
 *   Unter Wine auf Apple Silicon bleibt dessen Fenster schwarz, weil der
 *   Renderer-Prozess seine eigene Direct3D-Ausgabe aufmacht, und der
 *   ausgelagerte Netzwerk-Dienst scheitert an TLS über Wines Winsock
 *   (Anmeldung schlägt mit „Transport Error“ fehl).
 *
 * Was macht er?
 *   Er ersetzt bin\cef\cef.win64\steamwebhelper.exe. Das Original wird als
 *   steamwebhelper_real.exe daneben gelegt und mit diesen Zusatz-Optionen
 *   gestartet:
 *       --disable-gpu      Software-Zeichnen statt GPU
 *       --single-process   Renderer, GPU und Netzwerk im selben Prozess
 *   Alle Argumente von Steam werden unverändert weitergereicht.
 *
 * Bauen (Cross-Compile, z. B. mit llvm-mingw oder mingw-w64):
 *   x86_64-w64-mingw32-gcc -O2 -municode -DUNICODE -D_UNICODE \
 *       -o steamwebhelper.exe steamwebhelper-wrapper.c -static -mwindows
 */
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <stdlib.h>
#include <wchar.h>
#include <stdio.h>

#define EXTRA_FLAGS L"--disable-gpu --single-process"
#define REAL_BINARY L"steamwebhelper_real.exe"

/* Argumente ohne den eigenen Programmpfad zurückgeben */
static const wchar_t *args_tail(void)
{
    const wchar_t *cmd = GetCommandLineW();
    int in_quotes = 0;
    if (!cmd) return L"";
    while (*cmd) {
        if (*cmd == L'"') in_quotes = !in_quotes;
        else if (*cmd == L' ' && !in_quotes) break;
        ++cmd;
    }
    while (*cmd == L' ') ++cmd;
    return cmd;
}

int wmain(void)
{
    wchar_t real[MAX_PATH];
    DWORD len = GetModuleFileNameW(NULL, real, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) return 1;

    wchar_t *slash = wcsrchr(real, L'\\');
    if (!slash) return 1;
    slash[1] = L'\0';
    if (wcslen(real) + wcslen(REAL_BINARY) >= MAX_PATH) return 1;
    wcscat(real, REAL_BINARY);

    const wchar_t *tail = args_tail();
    size_t cap = wcslen(real) + wcslen(EXTRA_FLAGS) + wcslen(tail) + 8;
    wchar_t *cmdline = (wchar_t *)calloc(cap, sizeof(wchar_t));
    if (!cmdline) return 1;
    _snwprintf(cmdline, cap, L"\"%ls\" %ls %ls", real, EXTRA_FLAGS, tail);

    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    if (!CreateProcessW(real, cmdline, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
        free(cmdline);
        return 1;
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 0;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    free(cmdline);
    return (int)code;
}
