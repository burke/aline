# Aline

Aline supports associating some data with each line in a file (example:
profiling data indicating hot path / cold path), and building this into a
compressed map that can later be reapplied to a new version of the file,
preserving line associations across insertions/deletions.

This works using the [patience diff
algorithm](https://blog.jcoglan.com/2017/09/19/the-patience-diff-algorithm/)
described by Bram Cohen, and this code was derived from
[watt/ruby_patience_diff](https://github.com/watt/ruby_patience_diff).

## Example Usage

_(see example/run-example)_

Given an original source file `file.txt`:

```
line1
line2
line3
line4
```

And a `data.json`:

```
[0.8969537475692057,0.293077462817166,0.5673016517223046,0.24424795082483]
```

We run `aline build-map`...

```
bin/aline build-map file.txt data.json > file.alinemap
```

Each line and each data element is represented by a single byte so this map will
be 8 bytes long.

Later, we have a new version of the file (`new-file.txt`):

```
line1
lineFOOBAR
line4
line5
```

You can see there's been a change, an addition, and a deletion. If we run:

```
bin/aline remap file.alinemap new-file.txt
```

You'll see...

```
line1       # (in bright red)
lineFOOBAR
line4       # (in dark red)
line5
```

This is representing that line1 and line4 are present in the original file, and
correspond to relatively high and low values repectively; while lineFOOBAR and
line5 are not present in the original file.

The line association works pretty much the same as git's better diff algorithms.
