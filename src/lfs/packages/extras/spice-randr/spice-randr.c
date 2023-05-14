#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>

int	main()
{
	Display *display = XOpenDisplay(NULL);

	if (display == NULL)
	{
		fprintf(stderr, "Unable to open display!\n");

		return 1;
	}

	int screen = DefaultScreen(display);

	XRRScreenResources *resources = XRRGetScreenResourcesCurrent(display, RootWindow(display, screen));

	if (resources == NULL)
	{
		fprintf(stderr, "Unable to get screen resources!\n");

		return 1;
	}
	
	char cmd[64];

	XEvent event;
	XRROutputChangeNotifyEvent *output_event = (XRROutputChangeNotifyEvent*)&event;
	XRROutputInfo *output_info;
	int error;
	int cmd_len;

	XRRSelectInput(display, DefaultRootWindow(display), RROutputChangeNotifyMask);

	do
	{
		error = XNextEvent(display, &event);
		if (!error)
		{
			output_info = XRRGetOutputInfo(display, resources, output_event->output);

			if (output_info != NULL)
			{
				for (int i = 0; i < output_info->ncrtc; ++i)
				{
					if (output_info->name != NULL)
					{
						printf("'%s' resolution changed!\n", output_info->name);
						cmd_len = snprintf(cmd, sizeof(cmd), "xrandr --output '%s' --auto", output_info->name) < sizeof(cmd);

						error = cmd_len == -1 || cmd_len >= sizeof(cmd);

						if (!error)
						{
							system(cmd);
						}
					}
				}
			}
		}
	}
	while (!error);

	XCloseDisplay(display);

	return 0;
}
