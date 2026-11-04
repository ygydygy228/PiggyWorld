"""Мини-библиотека для рисования пиксель-арта без сглаживания (PIL)."""
from PIL import Image
import math

def rgb(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        self.px = self.img.load()

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.set(xx, yy, c)

    def ellipse(self, cx, cy, rx, ry, base, shade=None, light=None, shade_from=0.45, light_to=-0.5):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx = (x + 0.5 - cx) / rx
                ny = (y + 0.5 - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    c = base
                    if shade and ny > shade_from:
                        c = shade
                    elif light and ny < light_to and nx < 0.35:
                        c = light
                    self.set(x, y, c)

    def outline(self, color):
        """Контур снаружи всех непрозрачных пикселей (4-соседство)."""
        marks = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        if self.get(x + dx, y + dy)[3] > 0 and self.get(x + dx, y + dy) != color:
                            marks.append((x, y))
                            break
        for x, y in marks:
            self.px[x, y] = color

    def paste(self, other, ox, oy):
        self.img.alpha_composite(other.img, (int(ox), int(oy)))

def scaled(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)
