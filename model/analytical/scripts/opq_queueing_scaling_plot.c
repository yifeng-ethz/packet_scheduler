#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

typedef struct {
  int nx;
  int ny;
  float *x;
  float *y;
  float *z;
} scaling_grid_t;

static void trim_ascii(char *text) {
  size_t start = 0;
  size_t end = strlen(text);

  while (start < end && isspace((unsigned char) text[start])) {
    start++;
  }
  while (end > start && isspace((unsigned char) text[end - 1])) {
    end--;
  }
  if (start != 0) {
    memmove(text, text + start, end - start);
  }
  text[end - start] = '\0';
}

static const char *output_format_from_path(const char *path) {
  const char *dot = strrchr(path, '.');

  if (dot == NULL) {
    return "PNG";
  }
  dot++;
  if (strcasecmp(dot, "svg") == 0) {
    return "SVG";
  }
  if (strcasecmp(dot, "pdf") == 0) {
    return "PDF";
  }
  return "PNG";
}

static int read_grid(const char *path, scaling_grid_t *grid) {
  FILE *handle = fopen(path, "r");

  if (handle == NULL) {
    fprintf(stderr, "Failed to open scaling grid %s\n", path);
    return 0;
  }
  if (fscanf(handle, "%d %d", &grid->nx, &grid->ny) != 2 ||
      grid->nx < 1 || grid->ny < 1) {
    fprintf(stderr, "Invalid scaling grid header in %s\n", path);
    fclose(handle);
    return 0;
  }
  grid->x = (float *) calloc((size_t) grid->nx, sizeof(float));
  grid->y = (float *) calloc((size_t) grid->ny, sizeof(float));
  grid->z = (float *) calloc((size_t) grid->nx * (size_t) grid->ny, sizeof(float));
  if (grid->x == NULL || grid->y == NULL || grid->z == NULL) {
    fprintf(stderr, "Out of memory while reading %s\n", path);
    fclose(handle);
    return 0;
  }
  for (int ix = 0; ix < grid->nx; ix++) {
    if (fscanf(handle, "%f", &grid->x[ix]) != 1) {
      fclose(handle);
      return 0;
    }
  }
  for (int iy = 0; iy < grid->ny; iy++) {
    if (fscanf(handle, "%f", &grid->y[iy]) != 1) {
      fclose(handle);
      return 0;
    }
  }
  for (int ix = 0; ix < grid->nx; ix++) {
    for (int iy = 0; iy < grid->ny; iy++) {
      float value;

      if (fscanf(handle, "%f", &value) != 1) {
        fclose(handle);
        return 0;
      }
      if (value < 1.0f) {
        value = 1.0f;
      }
      if (value > 1.0e6f) {
        value = 1.0e6f;
      }
      grid->z[(size_t) ix * (size_t) grid->ny + (size_t) iy] = log10f(value);
    }
  }
  fclose(handle);
  return 1;
}

static void free_grid(scaling_grid_t *grid) {
  free(grid->x);
  free(grid->y);
  free(grid->z);
  grid->x = NULL;
  grid->y = NULL;
  grid->z = NULL;
}

static float clamp_unit(float value) {
  if (value < 0.0f) {
    return 0.0f;
  }
  if (value > 1.0f) {
    return 1.0f;
  }
  return value;
}

static void init_scaling_palette(void) {
  float red[256];
  float green[256];
  float blue[256];

  for (int idx = 0; idx < 256; idx++) {
    float t = (float) idx / 255.0f;

    if (idx == 0) {
      red[idx] = 1.0f;
      green[idx] = 1.0f;
      blue[idx] = 1.0f;
    } else {
      red[idx] = 1.00f - 0.96f * t;
      green[idx] = 0.98f - 0.94f * t;
      blue[idx] = 0.70f - 0.54f * t;
    }
  }
  myvlt(red, green, blue, 256);
}

static int scaling_color_index(float log_ratio) {
  float t = clamp_unit(log_ratio / 6.0f);

  return 1 + (int) floorf((253.0f * t) + 0.5f);
}

static void format_ratio_label(float log_ratio, char *label, size_t label_size) {
  float ratio = powf(10.0f, log_ratio);

  if (log_ratio >= 5.995f) {
    snprintf(label, label_size, "1e6x");
  } else if (ratio >= 1000.0f) {
    snprintf(label, label_size, "%.1fe3x", ratio / 1000.0f);
  } else if (ratio >= 100.0f) {
    snprintf(label, label_size, "%.0fx", ratio);
  } else {
    snprintf(label, label_size, "%.1fx", ratio);
  }
}

static void render_plot(const scaling_grid_t *scaling_grid, const char *output_path) {
  const char *output_format = output_format_from_path(output_path);
  const char *plot_title = getenv("OPQ_SCALING_TITLE");
  const char *plot_note = getenv("OPQ_SCALING_NOTE");

  metafl(output_format);
  setfil(output_path);
  filmod("delete");
  setpag("da4l");
  if (strcasecmp(output_format, "PNG") == 0) {
    winsiz(4096, 2400);
  }
  scrmod("reverse");
  disini();
  pagera();
  complx();
  init_scaling_palette();
  if (plot_title == NULL || plot_title[0] == '\0') {
    plot_title = "OPQ vs Time-Merger Feature-Scaling Loss Ratio";
  }
  titlin(plot_title, 2);
  name("OPQ egress width [36-bit words / beat]", "x");
  name("N_LANE", "y");
  labels("none", "x");
  labels("none", "y");
  axspos(480, 1580);
  axslen(1800, 900);
  graf(0.5f, (float) scaling_grid->nx + 0.5f, 1.0f, 1.0f,
       0.5f, (float) scaling_grid->ny + 0.5f, 1.0f, 1.0f);

  for (int ix = 0; ix < scaling_grid->nx; ix++) {
    for (int iy = 0; iy < scaling_grid->ny; iy++) {
      float x0 = xposn((float) ix + 0.5f);
      float x1 = xposn((float) ix + 1.5f);
      float y0 = yposn((float) iy + 0.5f);
      float y1 = yposn((float) iy + 1.5f);
      int nx0 = (int) floorf(fminf(x0, x1));
      int nx1 = (int) ceilf(fmaxf(x0, x1));
      int ny0 = (int) floorf(fminf(y0, y1));
      int ny1 = (int) ceilf(fmaxf(y0, y1));
      float log_ratio = scaling_grid->z[(size_t) ix * (size_t) scaling_grid->ny + (size_t) iy];
      char label[32];
      int x_center = (int) floorf(xposn((float) ix + 1.0f) + 0.5f);
      int y_center = (int) floorf(yposn((float) iy + 1.0f) + 0.5f);

      recfll(nx0, ny0, nx1 - nx0 + 1, ny1 - ny0 + 1, scaling_color_index(log_ratio));
      format_ratio_label(log_ratio, label, sizeof(label));
      height(24);
      if (log_ratio >= 3.0f) {
        setrgb(0.96f, 0.96f, 0.96f);
      } else {
        setrgb(0.08f, 0.08f, 0.08f);
      }
      txtjus("CENT");
      messag(label, x_center, y_center - 12);
    }
  }

  color("fore");
  linwid(2);
  grid(1, 1);
  txtjus("CENT");
  height(18);
  for (int ix = 0; ix < scaling_grid->nx; ix++) {
    char label[16];
    snprintf(label, sizeof(label), "%.0fx", scaling_grid->x[ix]);
    messag(label, (int) floorf(xposn((float) ix + 1.0f) + 0.5f), 1718);
  }
  txtjus("RIGHT");
  for (int iy = 0; iy < scaling_grid->ny; iy++) {
    char label[16];
    snprintf(label, sizeof(label), "%.0f", scaling_grid->y[iy]);
    messag(label, 440, (int) floorf(yposn((float) iy + 1.0f) + 0.5f) - 8);
  }
  txtjus("LEFT");

  height(44);
  color("fore");
  title();
  height(14);
  if (plot_note == NULL || plot_note[0] == '\0') {
    plot_note = "analytical stress point; darker cells indicate stronger OPQ advantage";
  }
  messag(plot_note, 480, 1888);
  messag("cell fill and text show clipped time-merger/OPQ loss ratio from 1x to 1e6x", 480, 1930);
  messag("rows sweep N_LANE; columns sweep OPQ egress width", 480, 1972);
  disfin();
}

int main(int argc, char **argv) {
  scaling_grid_t grid;
  char output_path[4096];

  if (argc != 3) {
    fprintf(stderr, "Usage: %s <feature_scaling.dat> <output.{png|svg|pdf}>\n", argv[0]);
    return 1;
  }
  memset(&grid, 0, sizeof(grid));
  if (!read_grid(argv[1], &grid)) {
    free_grid(&grid);
    return 1;
  }
  snprintf(output_path, sizeof(output_path), "%s", argv[2]);
  trim_ascii(output_path);
  if (output_path[0] == '\0') {
    fprintf(stderr, "Output path is empty\n");
    free_grid(&grid);
    return 1;
  }
  render_plot(&grid, output_path);
  free_grid(&grid);
  return 0;
}
