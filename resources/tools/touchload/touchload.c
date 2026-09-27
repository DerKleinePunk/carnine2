// Reproducible map load through a virtual multitouch panel (uinput).
//
// usage: touchload SECONDS [SEED] [PAUSE_MS]
// Each round: 6 swipes with random direction and length inside the map area,
// then 3 two-finger pinches (in, out), then PAUSE_MS (default 1000). The same
// SEED gives the same gestures, so two builds can be compared. Coordinates
// are for the 1024x600 panel; the map area leaves the top bar and the left
// rail out. Prints one line per round with the UTC time.
//
// ivi-homescreen picks the virtual panel up while it runs; no restart needed.
// See docs/25-demo-and-touch-tools.md.
// Build (static, no dependencies on the Pi) and run:
//   aarch64-linux-gnu-gcc -O2 -Wall -static -o touchload touchload.c -lm
//   scp touchload pi@carnine-pc:  &&  ssh pi@carnine-pc sudo ./touchload 45 1 500
#include <fcntl.h>
#include <linux/uinput.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define W 1024
#define H 600
#define X0 200
#define X1 1000
#define Y0 90
#define Y1 560

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

static void finger(int slot, int id, int x, int y) {
  emit(EV_ABS, ABS_MT_SLOT, slot);
  if (id >= 0) emit(EV_ABS, ABS_MT_TRACKING_ID, id);
  emit(EV_ABS, ABS_MT_POSITION_X, x);
  emit(EV_ABS, ABS_MT_POSITION_Y, y);
}

static void lift(int slot) {
  emit(EV_ABS, ABS_MT_SLOT, slot);
  emit(EV_ABS, ABS_MT_TRACKING_ID, -1);
}

static int clampi(int v, int lo, int hi) { return v < lo ? lo : v > hi ? hi : v; }

static void swipe(int x, int y, int dx, int dy, int steps) {
  finger(0, tracking++, x, y);
  emit(EV_KEY, BTN_TOUCH, 1);
  emit(EV_ABS, ABS_X, x);
  emit(EV_ABS, ABS_Y, y);
  syn();
  for (int i = 1; i <= steps; i++) {
    int px = clampi(x + dx * i / steps, 0, W - 1), py = clampi(y + dy * i / steps, 0, H - 1);
    finger(0, -1, px, py);
    emit(EV_ABS, ABS_X, px);
    emit(EV_ABS, ABS_Y, py);
    syn();
    msleep(16);
  }
  lift(0);
  emit(EV_KEY, BTN_TOUCH, 0);
  syn();
  msleep(120);
}

static void pinch(int cx, int cy, int from, int to, int steps) {
  finger(0, tracking++, cx - from, cy);
  finger(1, tracking++, cx + from, cy);
  emit(EV_KEY, BTN_TOUCH, 1);
  syn();
  for (int i = 1; i <= steps; i++) {
    int d = from + (to - from) * i / steps;
    finger(0, -1, cx - d, cy);
    finger(1, -1, cx + d, cy);
    syn();
    msleep(16);
  }
  lift(0);
  lift(1);
  emit(EV_KEY, BTN_TOUCH, 0);
  syn();
  msleep(200);
}

static void setup_abs(int code, int max) {
  struct uinput_abs_setup a;
  memset(&a, 0, sizeof a);
  a.code = code;
  a.absinfo.maximum = max;
  ioctl(fd, UI_ABS_SETUP, &a);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: %s SECONDS [SEED] [PAUSE_MS]\n", argv[0]);
    return 2;
  }
  double seconds = atof(argv[1]);
  srand(argc > 2 ? atoi(argv[2]) : 1);
  int pause_ms = argc > 3 ? atoi(argv[3]) : 1000;

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
  us.id.product = 0x5678;
  strcpy(us.name, "carnine touchload");
  ioctl(fd, UI_DEV_SETUP, &us);
  if (ioctl(fd, UI_DEV_CREATE) < 0) {
    perror("UI_DEV_CREATE");
    return 1;
  }
  sleep(2);  // let libinput pick the device up

  struct timespec start, now;
  clock_gettime(CLOCK_MONOTONIC, &start);
  int cx = (X0 + X1) / 2, cy = (Y0 + Y1) / 2;
  for (int round = 1;; round++) {
    clock_gettime(CLOCK_MONOTONIC, &now);
    if (now.tv_sec - start.tv_sec + (now.tv_nsec - start.tv_nsec) / 1e9 >= seconds) break;
    time_t t = time(NULL);
    char ts[32];
    strftime(ts, sizeof ts, "%F %T", gmtime(&t));
    printf("%s round %d\n", ts, round);
    fflush(stdout);
    for (int i = 0; i < 6; i++) {
      double a = (rand() % 360) * M_PI / 180.0;
      int len = 150 + rand() % 250;
      int dx = (int)(cos(a) * len), dy = (int)(sin(a) * len);
      int x = clampi(cx - dx / 2, X0, X1), y = clampi(cy - dy / 2, Y0, Y1);
      swipe(x, y, dx, dy, 18);
    }
    for (int i = 0; i < 3; i++) {
      pinch(cx, cy, 60, 220, 20);
      pinch(cx, cy, 220, 60, 20);
    }
    msleep(pause_ms);
  }
  ioctl(fd, UI_DEV_DESTROY);
  close(fd);
  return 0;
}
