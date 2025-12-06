#include "flutter_window.h"

#include <optional>
#include <map>

#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"

// Global storage for channels and window handles
static std::map<flutter::FlutterEngine*, HWND> engine_window_map;
static std::map<flutter::FlutterEngine*, std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>> engine_channel_map;

// Helper to set up window_events channel for any Flutter engine
static void SetupWindowEventsChannel(
    flutter::FlutterEngine* engine,
    HWND window_handle) {
  
  OutputDebugStringA("[NATIVE] SetupWindowEventsChannel called\n");
  
  // Store the mapping
  engine_window_map[engine] = window_handle;
  
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(),
      "window_events",
      &flutter::StandardMethodCodec::GetInstance());
  
  OutputDebugStringA("[NATIVE] Channel created\n");
  
  channel->SetMethodCallHandler(
      [engine](const auto& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        OutputDebugStringA("[NATIVE] MethodCallHandler invoked\n");
        if (call.method_name() == "confirmClose") {
          OutputDebugStringA("[NATIVE] confirmClose received\n");
          // Look up the HWND for this engine
          auto it = engine_window_map.find(engine);
          if (it != engine_window_map.end()) {
            OutputDebugStringA("[NATIVE] DestroyWindow called\n");
            ::DestroyWindow(it->second);
            engine_window_map.erase(it);
            engine_channel_map.erase(engine);
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  
  // Store channel globally
  engine_channel_map[engine] = std::move(channel);
  OutputDebugStringA("[NATIVE] Channel stored in global map\n");
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  
  // Set up window events channel for this window
  auto window_handle = GetHandle();
  SetupWindowEventsChannel(flutter_controller_->engine(), window_handle);
  
  // Register callback for sub-windows
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    auto *registry = flutter_view_controller->engine();
    RegisterPlugins(registry);
    
    // TODO: Get window handle for sub-window and set up its channel
    // This requires accessing the HWND from the sub-window context
    // For now, the main window handler will work for sub-windows
  });
  
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      // Guard against null controller during teardown
      if (flutter_controller_ && flutter_controller_->engine()) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
