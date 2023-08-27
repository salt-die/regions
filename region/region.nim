import std/[macros, sequtils, strformat, strutils, sugar]

type
  Rect* = object
    x, y: int
    width, height: Positive

  Band = object
    y1, y2: int
    walls: seq[int]

  Region* = seq[Band]

proc new_band(y1, y2: int, walls: seq[int]): Band =
  if y2 <= y1:
    raise newException(ValueError, fmt"Invalid Band: y1 ({y1}) is not smaller than y2 ({y2})")
  Band(y1: y1, y2: y2, walls: walls)

proc merge(op: (bool, bool) -> bool; a, b: seq[int] = @[]): seq[int] =
  ### Merge the walls of two bands given a set operation.
  var
    inside_a = false
    inside_b = false
    inside_region = false
    i = 0
    j = 0

  template update_region(threshold: int) =
    if op(inside_a, inside_b) != inside_region:
      inside_region = not inside_region
      result.add threshold

  template update_a =
    inside_a = not inside_a
    update_region a[i]
    inc i

  template update_b =
    inside_b = not inside_b
    update_region b[j]
    inc j

  while true:
    if i < a.len:
      if j < b.len:
        if a[i] < b[j]:
          update_a
        elif b[j] < a[i]:
          update_b
        else:
          inside_a = not inside_a
          inside_b = not inside_b
          update_region a[i]
          inc i
          inc j
      else:
        update_a
    elif j < b.len:
      update_b
    else:
      break

proc coalesce(region: var Region) =
  ### Join contiguous bands with the same walls.
  var i = 0
  template r: Band = region[i]
  template s: Band = region[i + 1]

  while i < region.len - 1:
    if r.walls.len == 0:
      region.delete i
    elif s.walls.len == 0:
      region.delete i + 1
    elif s.y1 <= r.y2 and r.walls == s.walls:
      r.y2 = s.y2
      region.delete i + 1
    else:
      inc i

proc merge(op: (bool, bool) -> bool, a, b: Region = @[]): Region =
  ### Combine two regions with a given boolean operator.
  result = default(Region)

  var
    i = 0
    j = 0
    scanline = int.low

  template r: Band = a[i]
  template s: Band = b[j]

  while i < a.len and j < b.len:
    if r.y1 <= s.y1:
      if scanline < r.y1:
        scanline = r.y1
      if r.y2 < s.y1:
        ## ---------------
        ## - - - - - - - - scanline
        ##        r
        ## ---------------
        ##        ~~~~~~~~~~~~~~~
        ##               s
        ##        ~~~~~~~~~~~~~~~
        result.add new_band(scanline, r.y2, op.merge(r.walls))
        scanline = r.y2
        inc i
      elif s.y1 <= r.y2 and r.y2 < s.y2:
        if scanline < s.y1:
          ## ---------------
          ## - - - - - - - - scanline
          ##        r
          ##        ~~~~~~~~~~~~~~~
          ## ---------------
          ##               s
          ##        ~~~~~~~~~~~~~~~
          result.add new_band(scanline, s.y1, op.merge(r.walls))

        if s.y1 < r.y2:
          ## ---------------
          ##        r
          ##        ~-~-~-~-~-~-~-~ scanline
          ## ---------------
          ##               s
          ##        ~~~~~~~~~~~~~~~
          result.add new_band(s.y1, r.y2, op.merge(r.walls, s.walls))
        scanline = r.y2
        inc i
      else:  # r.y2 >= s.y2
        if scanline < s.y1:
          ## ---------------
          ## - - - - - - - - scanline
          ##        r
          ##        ~~~~~~~~~~~~~~~
          ##               s
          ##        ~~~~~~~~~~~~~~~
          ## ---------------
          result.add new_band(scanline, s.y1, op.merge(r.walls))
        ## ---------------
        ##        r
        ##        ~-~-~-~-~-~-~-~ scanline
        ##               s
        ##        ~~~~~~~~~~~~~~~
        ## ---------------
        result.add new_band(s.y1, s.y2, op.merge(r.walls, s.walls))
        scanline = s.y2
        if s.y2 == r.y2:
          inc i
        inc j
    else:  # s.y1 < r.y1
      if scanline < s.y1:
        scanline = s.y1
      if s.y2 < r.y2:
        ## ~~~~~~~~~~~~~~~
        ## - - - - - - - - scanline
        ##        s
        ## ~~~~~~~~~~~~~~~
        ##        _______________
        ##               r
        ##        _______________
        result.add new_band(scanline, s.y2, op.merge(s.walls))
        scanline = s.y2
        inc j
      elif r.y1 <= s.y2 and s.y2 < r.y2:
        if scanline < r.y1:
          ## ~~~~~~~~~~~~~~~
          ## - - - - - - - - scanline
          ##        s
          ##        ---------------
          ## ~~~~~~~~~~~~~~~
          ##               r
          ##        ---------------
          result.add new_band(scanline, r.y1, op.merge(s.walls))

        if r.y1 < s.y2:
          ## ~~~~~~~~~~~~~~~
          ##        s
          ##        --------------- scanline
          ## ~~~~~~~~~~~~~~~
          ##               r
          ##        ---------------
          result.add new_band(r.y1, s.y2, op.merge(s.walls, r.walls))
        scanline = s.y2
        inc j
      else:  # s.y2 >= r.y2
        if scanline < r.y1:
          ## ~~~~~~~~~~~~~~~
          ## - - - - - - - - scanline
          ##        s
          ##        ---------------
          ##               r
          ##        ---------------
          ## ~~~~~~~~~~~~~~~
          result.add new_band(scanline, r.y1, op.merge(s.walls))
        ## ~~~~~~~~~~~~~~~
        ##        s
        ##        --------------- scanline
        ##               r
        ##        ---------------
        ## ~~~~~~~~~~~~~~~
        result.add new_band(r.y1, r.y2, op.merge(s.walls, r.walls))
        scanline = r.y2
        if r.y2 == s.y2:
          inc j
        inc i

  while i < a.len:
    if scanline < r.y1:
      scanline = r.y1
    result.add new_band(scanline, r.y2, op.merge(r.walls))
    scanline = r.y2
    inc i

  while j < b.len:
    if scanline < s.y1:
      scanline = s.y1
    result.add new_band(scanline, s.y2, op.merge(s.walls))
    scanline = s.y2
    inc j

  coalesce result

# TODO: imerge: in-place merge

proc to_region*(rect: Rect): Region =
  result = @[
    Band(
      y1: rect.y,
      y2: rect.y + rect.height,
      walls: @[rect.x, rect.x + rect.width],
    )
  ]

proc `$`(rect: Rect): string =
  fmt"Rect(x: {rect.x}, y: {rect.y}, width: {rect.width}, height: {rect.height})"

proc `$`(band: Band): string =
  fmt"Band(y1: {band.y1}, y2: {band.y2}, walls: {band.walls})"

proc `==`(a, b: Band): bool =
  a.y1 == b.y1 and a.y2 == b.y2 and a.walls == b.walls

proc `$`*(region: Region): string =
  let s = join(region, ", ")
  fmt"Region({s})"

proc `&`*(a, b: Region): Region =
  ((a: bool, b: bool) => a and b).merge(a, b)

proc `+`*(a, b: Region): Region =
  ((a: bool, b: bool) => a or b).merge(a, b)

proc `-`*(a, b: Region): Region =
  ((a: bool, b: bool) => a and not b).merge(a, b)

proc `^`*(a, b: Region): Region =
  ((a: bool, b: bool) => a xor b).merge(a, b)

proc `==`*(a, b: Region): bool =
  allIt(zip(a, b), it[0] == it[1])

iterator rects*(region: Region): Rect =
  ### Yield all rects that make up region.
  var
    i, height: int

  for band in region:
    height = band.y2 - band.y1
    i = 0
    while i < band.walls.len:
      yield Rect(
        x: band.walls[i],
        y: band.y1,
        width: band.walls[i + 1] - band.walls[i],
        height: height,
      )
      i.inc 2

when isMainModule:
  let
    r = Rect(x: 0, y: 0, width: 60, height: 60).to_region
    s = Rect(x: 0, y: 20, width: 40, height: 20).to_region
    t = Rect(x: 0, y: 40, width: 20, height: 20).to_region

  assert r == r - s + s - t + t
  echo r - s - t
  for rect in rects(r - s - t):
    echo rect

  try:
    discard new_band(5, 3, @[1, 2, 3])
  except ValueError as e:
    echo e.msg
