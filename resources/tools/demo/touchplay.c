// Plays touch gestures read from stdin through a virtual touch panel (uinput),
// for demos driven from another machine (see demo.sh).
//
// usage: touchplay        then one command per line on stdin:
//   tap X Y [HOLD_MS]                 one finger down and up (default hold 60)
//   swipe X Y DX DY [MS]              one finger drag (default 300 ms)
//   pinch CX CY FROM TO [MS]          two fingers, horizontal distance FROM -> TO
//   wait MS
//   # ...                             comment; empty lines are skipped
// Each command answers "ok" (or "error ...") on stdout once it is done, so a
// caller can wait for it. Coordinates are for the 1024x600 panel.
//
// Same device setup as touchload; ivi-homescreen picks it up while running.
// Build (static, no dependencies on the Pi):
//   aarch64-linux-gnu-gcc -O2 -Wall -static -o touchplay touchplay.c
#include <fcntl.h>
#include <linux/uinput.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define W 1024
#define H 600
#define FRAME_MS 16

static int fd;
static int tracking = 1;

static void emit(int type, int code, int value) {
  struct input_event ev;
  memset(&ev, 0, sizeof ev);
  ev.type = type;
  ev.code = code;
  ev.value = value;
  if (write(fd, &ev, sizeof ev) != sizeof ev) perror("write");
}

static void syn(void) { emit(EV_SYN, SYN_REPORT, 0); }

static void msleep(int ms) {
  struct timespec ts = {ms / 1000, (ms % 1000) * 1000000L};
  nanosleep(&ts, NULL);
}

static int clampi(int v, int lo, int hi) { return v < lo ? lo : v > hi ? hi : v; }

static void finger(int slot, int id, int x, int y) {
  x = clampi(x, 0, W - 1);
  y = clampi(y, 0, H - 1);
  emit(EV_ABS, ABS_MT_SLOT, slot);
  if (id >= 0) emit(EV_ABS, ABS_MT_TRACKING_ID, id);
  emit(EV_ABS, ABS_MT_POSITION_X, x);
  emit(EV_ABS, ABS_MT_POSITION_Y, y);
  if (slot == 0) {
    emit(EV_ABS, ABS_X, x);
    emit(EV_ABS, ABS_Y, y);
  }
}

static void lift(int slot) {
  emit(EV_ABS, ABS_MT_SLOT, slot);
  emit(EV_ABS, ABS_MT_TRACKING_ID, -1);
}

static void tap(int x, int y, int hold_ms) {
  finger(0, tracking++, x, y);
  emit(EV_KEY, BTN_TOUCH, 1);
  syn();
  msleep(hold_ms);
  lift(0);
  emit(EV_KEY, BTN_TOUCH, 0);
  syn();
}

static void swipe(int x, int y, int dx, int dy, int ms) {
  int steps = ms / FRAME_MS > 1 ? ms / FRAME_MS : 1;
  finger(0, tracking++, x, y);
  emit(EV_KEY, BTN_TOUCH, 1);
  syn();
  for (int i = 1; i <= steps; i++) {
    finger(0, -1, x + dx * i / steps, y + dy * i / steps);
    syn();
    msleep(FRAME_MS);
  }
  lift(0);
  emit(EV_KEY, BTN_TOUCH, 0);
  syn();
}

static void pinch(int cx, int cy, int from, int to, int ms) {
  int steps = ms / FRAME_MS > 1 ? ms / FRAME_MS : 1;
  finger(0, tracking++, cx - from, cy);
  finger(1, tracking++, cx + from, cy);
  emit(EV_KEY, BTN_TOUCH, 1);
  syn();
  for (int i = 1; i <= steps; i++) {
    int d = from + (to - from) * i / steps;
    finger(0, -1, cx - d, cy);
    finger(1, -1, cx + d, cy);
    syn();
    msleep(FRAME_MS);
  }
  lift(0);
  lift(1);
  emit(EV_KEY, BTN_TOUCH, 0);
  syn();
}

static void setup_abs(int code, int max) {
  struct uinput_abs_setup a;
  memset(&a, 0, sizeof a);
  a.code = code;
  a.absinfo.maximum = max;
  ioctl(fd, UI_ABS_SETUP, &a);
}

int main(void) {
  fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
  if (fd < 0) {
    perror("/dev/uinput");
    return 1;
  }
  ioctl(fd, UI_SET_EVBIT, EV_KEY);
  ioctl(fd, UI_SET_KEYBIT, BTN_TOUCH);
  ioctl(fd, UI_SET_EVBIT, EV_ABS);
  ioctl(fd, UI_SET_ABSBIT, ABS_X);
  ioctl(fd, UI_SET_ABSBIT, ABS_Y);
  ioctl(fd, UI_SET_ABSBIT, ABS_MT_SLOT);
  ioctl(fd, UI_SET_ABSBIT, ABS_MT_TRACKING_ID);
  ioctl(fd, UI_SET_ABSBIT, ABS_MT_POSITION_X);
  ioctl(fd, UI_SET_ABSBIT, ABS_MT_POSITION_Y);
  ioctl(fd, UI_SET_PROPBIT, INPUT_PROP_DIRECT);
  setup_abs(ABS_X, W - 1);
  setup_abs(ABS_Y, H - 1);
  setup_abs(ABS_MT_SLOT, 1);
  setup_abs(ABS_MT_TRACKING_ID, 65535);
  setup_abs(ABS_MT_POSITION_X, W - 1);
  setup_abs(ABS_MT_POSITION_Y, H - 1);
  struct uinput_setup us;
  memset(&us, 0, sizeof us);
  us.id.bustype = BUS_VIRTUAL;
  us.id.vendor = 0x1234;
  us.id.product = 0x5679;
  strcpy(us.name, "carnine touchplay");
  ioctl(fd, UI_DEV_SETUP, &us);
  if (ioctl(fd, UI_DEV_CREATE) < 0) {
    perror("UI_DEV_CREATE");
    return 1;
  }
  sleep(2);  // let libinput pick the device up
  printf("ready\n");
  fflush(stdout);

  char line[256];
  while (fgets(line, sizeof line, stdin)) {
    char cmd[16] = "";
    int a[5] = {0, 0, 0, 0, 0};
    int n = sscanf(line, "%15s %d %d %d %d %d", cmd, &a[0], &a[1], &a[2], &a[3], &a[4]);
    if (n <= 0 || cmd[0] == '#') continue;
    if (!strcmp(cmd, "tap") && n >= 3) {
      tap(a[0], a[1], n >= 4 ? a[2] : 60);
    } else if (!strcmp(cmd, "swipe") && n >= 5) {
      swipe(a[0], a[1], a[2], a[3], n >= 6 ? a[4] : 300);
    } else if (!strcmp(cmd, "pinch") && n >= 5) {
      pinch(a[0], a[1], a[2], a[3], n >= 6 ? a[4] : 320);
    } else if (!strcmp(cmd, "wait") && n >= 2) {
      msleep(a[0]);
    } else {
      printf("error %s", line);
      fflush(stdout);
      continue;
    }
    printf("ok\n");
    fflush(stdout);
  }
  ioctl(fd, UI_DEV_DESTROY);
  close(fd);
  return 0;
}
