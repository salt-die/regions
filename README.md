# regions
Regions for window managers.

Regions
-------
Given a list of overlapping windows, how can they be efficiently rendered?
Ideally, areas of windows covered by other windows are never drawn:

```
    +------------+   +--------+
    |            |   |        |
    |        +-----------+    |
    |        |     a     |    |
    |        +-----------+----+
    |            |
    +------------+
```

But how to represent the above area after subtracting `a`?
```
    +------------+   +--------+
    |            |   |    c   |
    |        +---+   +---+    |
    |   b    |           |    |
    |        +---+       +----+
    |            |
    +------------+
```

One method is to divide the area into a series of mutually exclusive horizontal bands:
```
    +------------+   +--------+
    |            |   |        |
    +--------+---+   +---+----+
    | a      | b         | c  | d   <- 2nd band with walls at a, b, c, d.
    +--------+---+       +----+
    |            |
    +------------+
```

Each band is a vertical interval and a list of walls. Each contiguous pair of walls indicates a new rect in the band. A Region is a list of sorted, mutually exclusive bands.


Using `region`
--------------

To use `region`, construct an initial Region, `r`, from some rect and iteratively `+`, `-`, `&`, or `^` with other regions:
```nim
  let
    r = Rect(x: 0, y: 0, w: 60, h: 60).to_region
    s = Rect(x: 0, y: 20, w: 40, h: 20).to_region
    t = Rect(x: 0, y: 40, w: 20, h: 20).to_region

  echo r - s - t
  for rect in rects(r - s - t):
    echo rect
```
Output:
```
Region(Band(y1: 0, y2: 20, walls: @[0, 60]), Band(y1: 20, y2: 40, walls: @[40, 60]), Band(y1: 40, y2: 60, walls: @[20, 60]))
Rect(x: 0, y: 0, w: 60, h: 20)
Rect(x: 40, y: 20, w: 20, h: 20)
Rect(x: 20, y: 40, w: 40, h: 20)
```

References
----------
* https://github.com/reactos/reactos/blob/52275a92bdf3b0fb3842e9c8edcd9f8503673319/win32ss/gdi/ntgdi/region.c
* https://github.com/mirror/libX11/blob/master/src/Region.c
* https://github.com/libpixman/pixman/blob/master/pixman/pixman-region.c
