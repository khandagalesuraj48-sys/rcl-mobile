#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <flutter_windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // (3.19.0) RCL ERP on a computer: a tall window like the phone's screen, in the middle of the screen (it can be made bigger)
  RECT work{};
  ::SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
  const POINT mid{(work.left + work.right) / 2, (work.top + work.bottom) / 2};
  const double scale = FlutterDesktopGetDpiForMonitor(::MonitorFromPoint(mid, MONITOR_DEFAULTTONEAREST)) / 96.0;
  const int work_w = static_cast<int>((work.right - work.left) / scale);
  const int work_h = static_cast<int>((work.bottom - work.top) / scale);
  const int win_w = work_w - 40 < 560 ? work_w - 40 : 560;
  const int win_h = work_h - 40 < 940 ? work_h - 40 : 940;
  Win32Window::Point origin(static_cast<unsigned int>(static_cast<int>(work.left / scale) + (work_w - win_w) / 2),
                            static_cast<unsigned int>(static_cast<int>(work.top / scale) + (work_h - win_h) / 2));
  Win32Window::Size size(static_cast<unsigned int>(win_w), static_cast<unsigned int>(win_h));
  if (!window.Create(L"RCL ERP", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
