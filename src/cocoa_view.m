#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>
#import <AppKit/AppKit.h>

void *glfw_echo_cocoa_view(GLFWwindow *window)
{
    if (window == NULL) {
        return NULL;
    }

    NSWindow *ns = glfwGetCocoaWindow(window);

    if (ns == nil) {
        return NULL;
    }

    NSView *view = [ns contentView];
    return (void *)view;
}
