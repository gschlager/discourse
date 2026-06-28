# Benchmark Results

Here are the latest benchmark results. All benchmarks ran with `ruby 3.2.3 (2024-01-18 revision 52bb2ac0a6) [x86_64-linux]`

## database_write.rb

Compares the INSERT speed of SQLite and DuckDB

| Database  | User Time | System Time | Total Time |  Real Time |
|-----------|----------:|------------:|-----------:|-----------:|
| SQLite3   | 99.212731 |    4.883932 | 104.096663 | 104.233575 |
| Extralite | 45.396666 |    4.457247 |  49.853913 |  50.065680 |
| DuckDB    | 49.012140 |   10.210994 |  59.223134 |  52.095679 |

## multi_row_insert.rb

Compares ways of encoding bulk INSERTs into the IntermediateDB. All variants use
the same connection pragmas and transaction batching (1000 rows) as
`Migrations::Database::Connection`; only the statement encoding differs. Ran with
`ruby 3.3.6` and `extralite-bundle 2.14` (SQLite 3.51.2), 4,000,000 rows.

```
per_row (status quo)            4.8196 s         829,943 rows/s   (baseline)
batch_execute                   3.3347 s       1,199,521 rows/s   1.45x faster
multi_row(5)                    2.2204 s       1,801,507 rows/s   2.17x faster
multi_row(10)                   1.7659 s       2,265,196 rows/s   2.73x faster
multi_row(25)                   1.4990 s       2,668,453 rows/s   3.22x faster
multi_row(50)                   1.8542 s       2,157,257 rows/s   2.60x faster
multi_row(100)                  2.2147 s       1,806,143 rows/s   2.18x faster
multi_row(500)                  2.4382 s       1,640,582 rows/s   1.98x faster
multi_row(8191)                 2.4938 s       1,603,950 rows/s   1.93x faster
multi_row_batch(25)             1.5137 s       2,642,516 rows/s   3.19x faster
multi_row_batch(100)            2.4163 s       1,655,451 rows/s   1.99x faster
```

Takeaways:

- Multi-row `VALUES` is a clear win: **~3.2x** over the per-row prepared statement
  at the sweet spot of **~25 rows per statement**.
- The sweet spot is small. Throughput peaks around 10–50 rows/statement and then
  declines — large batches pay more for binding/copying parameters and building
  bigger statements than they save on SQLite steps, and they erode the prepared
  statement cache's effectiveness. Filling the 8191-row parameter limit is one of
  the *worst* options.
- Extralite's native `batch_execute` (re-binding the single-row statement N times
  in C) helps on its own (~1.45x) but is dominated by multi-row `VALUES`. Layering
  `batch_execute` on top of multi-row `VALUES` adds nothing measurable over a plain
  Ruby loop at the same rows-per-statement.

## hash_vs_data.rb

Compares the INSERT speed when the data is bound as Hash or Data class

```
   Extralite regular    868.703k (± 2.2%) i/s -      8.744M in  10.070511s
      Extralite hash    579.753k (± 1.2%) i/s -      5.838M in  10.071266s
      Extralite data    672.752k (± 0.8%) i/s -      6.790M in  10.093191s
Extralite data/array    826.296k (± 0.9%) i/s -      8.318M in  10.067518s
     SQLite3 regular    362.037k (± 0.7%) i/s -      3.628M in  10.021699s
        SQLite3 hash    308.647k (± 1.1%) i/s -      3.111M in  10.081159s
   SQLite3 data/hash    288.747k (± 2.7%) i/s -      2.890M in  10.018335s

Comparison:
   Extralite regular:   868702.8 i/s
Extralite data/array:   826295.7 i/s - 1.05x  slower
      Extralite data:   672752.0 i/s - 1.29x  slower
      Extralite hash:   579753.5 i/s - 1.50x  slower
     SQLite3 regular:   362037.0 i/s - 2.40x  slower
        SQLite3 hash:   308646.7 i/s - 2.81x  slower
   SQLite3 data/hash:   288747.1 i/s - 3.01x  slower
```

## parameter_binding.rb

A similar benchmark that looks at various parameter binding styles, especially in Extralite

```
   Extralite regular    825.159 (± 0.6%) i/s -      8.316k in  10.078450s
     Extralite named    571.135 (± 0.4%) i/s -      5.742k in  10.053796s
     Extralite index    769.273 (± 1.0%) i/s -      7.742k in  10.065238s
     Extralite array    860.549 (± 0.5%) i/s -      8.624k in  10.021749s
     SQLite3 regular    361.745 (± 0.6%) i/s -      3.636k in  10.051588s
       SQLite3 named    307.875 (± 0.6%) i/s -      3.090k in  10.036954s

Comparison:
     Extralite array:      860.5 i/s
   Extralite regular:      825.2 i/s - 1.04x  slower
     Extralite index:      769.3 i/s - 1.12x  slower
     Extralite named:      571.1 i/s - 1.51x  slower
     SQLite3 regular:      361.7 i/s - 2.38x  slower
       SQLite3 named:      307.9 i/s - 2.80x  slower
```

## time_formatting.rb

Fastest way of converting `Time` into `String`?

```
        Time#iso8601      1.084M (± 0.9%) i/s -     10.875M in  10.033905s
       Time#strftime      1.213M (± 1.4%) i/s -     12.200M in  10.056764s
    DateTime#iso8601      2.419M (± 1.8%) i/s -     24.296M in  10.046295s

Comparison:
    DateTime#iso8601:  2419162.1 i/s
       Time#strftime:  1213390.0 i/s - 1.99x  slower
        Time#iso8601:  1083922.8 i/s - 2.23x  slower
```

## write.rb

Compares writing lots of data into a single SQLite database.

```
single writer               43.9766 seconds
forked writer - same DB     53.5112 seconds
forked writer - multi DB     3.0815 seconds
```
