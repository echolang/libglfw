# libglfw

libglfw gives your Echo program a window, an OpenGL context, and keyboard and mouse input. GLFW 3.4 is vendored and compiled into your module, so you add it with epm and nothing else.

The surface is GLFW's, with Echo names. If you know `glfwCreateWindow`, you know `glfw::createWindow`. GLFW's own documentation still applies.

## Getting started

From your project directory:

```bash
epm add echolang/libglfw --git https://github.com/echolang/libglfw --range ^0.1
```

That writes a `#[requires:]` line and vendors the sources. Echo sees the `glfw` namespace as soon as the module loads.

libglfw does not depend on [libopengl](https://github.com/echolang/libopengl). Add that one too if you draw:

```bash
epm add echolang/libopengl --git https://github.com/echolang/libopengl --range ^0.1
```

The module builds on Darwin, Linux (X11), and Windows. On Linux you need the X11 and GL headers to compile. Wayland is not supported.

## Opening a window

Let's look at a complete example. The sequence is GLFW's: initialize, hint, create, make current, loop, tear down.

```echo
if (glfw::init() != glfw::TRUE) {
    die(glfw::error_message());
}

glfw::windowHint(glfw::CONTEXT_VERSION_MAJOR, 3);
glfw::windowHint(glfw::CONTEXT_VERSION_MINOR, 3);
glfw::windowHint(glfw::OPENGL_PROFILE, glfw::OPENGL_CORE_PROFILE);
glfw::windowHint(glfw::OPENGL_FORWARD_COMPAT, glfw::TRUE);

ptr<glfw::Window> $window = glfw::createWindow(800, 600, 'libglfw', null, null);

if ($window:$ == null) {
    glfw::terminate();
    die(glfw::error_message());
}

glfw::makeContextCurrent($window);
glfw::swapInterval(1);
gl::load(&glfw::getProcAddress);

while (glfw::windowShouldClose($window) == glfw::FALSE) {
    gl::ClearColor(0.25, 0.25, 0.25, 1.0);
    gl::Clear(gl::COLOR_BUFFER_BIT);
    glfw::swapBuffers($window);
    glfw::pollEvents();
}

glfw::destroyWindow($window);
glfw::terminate();
```

`gl::load` goes after `makeContextCurrent`. Loading before a context is current resolves nothing.

You can run that program from `examples/`:

```bash
cd examples
echoc run -- --frames 120
```

A window opens, clears dark grey, and closes itself after 120 swaps.

### Checking success

`glfw::TRUE` and `glfw::FALSE` are `int32` constants, not `bool`. Every GLFW constant is an `int32`. This will not compile:

```echo
if (!glfw::init()) {
    // will not compile: init() is int32, not bool
}
```

Compare against the constant. `error_message()` is a `string`, never null, and empty when GLFW has nothing to say.

A failed `createWindow` is a null handle. `:$` names the address rather than the thing at it, which is the `$window:$ == null` check above.

GLFW will abort if you pass a null monitor into calls that require one. `getPrimaryMonitor` returns null whenever GLFW is not initialized, so check the handle.

## Naming

Most of the surface is a rename. The prefix comes off, the rest stays:

| C | Echo | Rule |
|---|---|---|
| `GLFW_KEY_ESCAPE` | `glfw::KEY_ESCAPE` | `GLFW_` off the front |
| `glfwCreateWindow` | `glfw::createWindow` | `glfw` off the front, first byte lowercased |
| `GLFWvidmode` | `glfw::Vidmode` | `GLFW` off the front, first byte uppercased |

If you know the C name, you know the Echo name. The rest of this page is the places Echo and C actually disagree.

## Strings

You may pass a real Echo `string` wherever GLFW takes a C string:

```echo
glfw::setWindowTitle($window, 'a real Echo string');
glfw::setClipboardString($window, "frame {$frame}");
```

String returns are Echo strings too. A null char pointer from C arrives as `''`, so you never need a null guard.

The one exception is `glfw::getProcAddress`, which keeps C's pointer signature so `&glfw::getProcAddress` fits `gl::load`.

## Vulkan and native handles

The generator reads `glfw3.h` under no extra include. That skips the `VK_VERSION_1_0` block and all of `glfw3native.h`, so those entry points are hand-written. They take handle words, not `vk::` types — libglfw does not depend on libvulkan.

Hand GLFW the same ICD you opened, **before** `glfw::init`. On Darwin that is MoltenVK; skip it and GLFW opens `libvulkan.1.dylib` (or nothing) and the surface does not match the instance:

```echo
glfw::initVulkanLoader(vk::getInstanceProcAddrPtr());
glfw::windowHint(glfw::CLIENT_API, glfw::NO_API);
```

`createWindowSurface` writes a `VkSurfaceKHR` as `uint64`. `$instance` is the instance handle word; `$allocator` is null for the default:

```echo
uint64 $surface = 0;
int32 $code = glfw::createWindowSurface($instance->handle, $window, null, &$surface);
```

On Darwin, `getCocoaWindow` is the `NSWindow*` as `ptr<uint8>`. Hand it to Metal:

```echo
mtl::Layer $layer = mtl::Layer(attachView: glfw::getCocoaWindow($window), $device);
```

`getInstanceProcAddress` takes an instance plus a name. That will not compile as `vk::load`'s getproc, which is the point: `initVulkanLoader` is the GLFW hook, not a signature lie.

## Handles

Windows, monitors, and cursors stay opaque. GLFW hands them to you as `ptr<glfw::Window>` (and the same for `Monitor` and `Cursor`) and GLFW frees them. The compiler will not let you pass a monitor where a window belongs.

When a call writes two values, take the address of a local:

```echo
int32 $width = 0;
int32 $height = 0;
glfw::getWindowSize($window, &$width, &$height);
```

Count-plus-array is the same idea. The pointer is GLFW's, and it is only valid until the monitor configuration changes:

```echo
int32 $count = 0;
ptr<ptr<glfw::Monitor>> $monitors = glfw::getMonitors(&$count);
int32 $i = 0;

while ($i < $count) {
    std::io::println(glfw::getMonitorName($monitors:$[$i]));
    $i = $i + 1;
}
```

Copy it if you need it longer than that.

## Callbacks

A closure carries an environment GLFW cannot hold, so registration takes a named function. Pass `&name`:

```echo
function on_key(ptr<glfw::Window> $window, int32 $key, int32 $scancode, int32 $action, int32 $mods) : void
{
    if ($key == glfw::KEY_ESCAPE && $action == glfw::PRESS) {
        glfw::setWindowShouldClose($window, glfw::TRUE);
    }
}

glfw::setKeyCallback($window, &on_key);
```

State a callback needs is a static, or it comes in through the parameters, or it comes in through `glfw::getWindowUserPointer($window)`. Passing `null` unregisters.

Callback parameters are not wrapped. A `const char *` arriving through a callback is still a `ptr<const uint8>`. Convert it with `str::from`:

```echo
function on_error(int32 $code, ptr<const uint8> $description) : void
{
    string $message = '';

    if ($description:$ != null) {
        $message = str::from($description:$);
    }

    std::io::println("glfw error {$code}: {$message}");
}

glfw::setErrorCallback(&on_error);
```

## Gamepad

`glfw::Gamepadstate` uses Echo arrays so you can index with the `GAMEPAD_` constants:

```echo
glfw::Gamepadstate $state = glfw::Gamepadstate();

if (glfw::getGamepadState(0, $state) == glfw::TRUE) {
    if ($state->buttons[glfw::GAMEPAD_BUTTON_A] == glfw::PRESS) {
        // jump
    }

    float32 $x = $state->axes[glfw::GAMEPAD_AXIS_LEFT_X];
}
```
