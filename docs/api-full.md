
# Documentation

Namespaces: [main](#main)

---

# main

## Errors for 'main'

```js
// Thrown by every operation of this package.
+ error Error (open, syntax, constraint, busy, readonly, corrupt, interrupted, error, closed) payload { message: String, result_code: int (0), sql: String ("") }
```

### Error

Thrown by every operation of this package.

- `open`: the database file could not be opened or created.
- `syntax`: the SQL could not be prepared: a typo, an unknown table or column, or a
  placeholder that was not bound.
- `constraint`: a `UNIQUE`, `NOT NULL`, `CHECK` or foreign key rule was broken.
- `busy`: another connection held the database for longer than the busy timeout.
- `readonly`: the database was opened read-only, or the file cannot be written.
- `corrupt`: the file is not a database, or it is damaged.
- `interrupted`: `interrupt` was called from another thread while the query ran.
- `error`: any other answer from SQLite.
- `closed`: the connection is closed.

`result_code` holds the SQLite result code, extended where SQLite has one, so a caller that needs
the exact reason can look it up; `message` is the text SQLite gave.

## Enums for 'main'

```js
// How hard `Connection.checkpoint` tries, the modes of `sqlite3_wal_checkpoint_v2`.
+ enum Checkpoint { passive, full, restart, truncate }
// How SQLite keeps the rollback journal, which decides how readers and writers get along.
+ enum Journal { wal, delete, truncate, persist, memory, off, keep }
// The kinds of `Value`, which are the storage classes of SQLite.
+ enum TYPE { null, int, float, string, blob }
```

### Checkpoint

How hard `Connection.checkpoint` tries, the modes of `sqlite3_wal_checkpoint_v2`.

### Journal

How SQLite keeps the rollback journal, which decides how readers and writers get along.

### TYPE

The kinds of `Value`, which are the storage classes of SQLite.

## Functions for 'main'

```js
// Converts any supported value (integers, floats, bools, text, json values, and nullable versions of those) into a `Value`.
+ fn convert(ndata: $T) Value
// Returns the connection as a `sql.Db`, the database type of the `valk-sql` package.
+ fn database(con: Connection) Db
// Opens a database file, creating it when it does not exist.
+ fn open(path: String, options: OpenOptions (.{})) Connection !Error
// Opens a database that lives in memory and disappears when the connection closes.
+ fn open_memory(options: OpenOptions (.{})) Connection !Error
// Returns `?, ?, ?` for `count` values, to write an `IN (...)` list.
+ fn placeholders(count: uint) String
// The SQLite version the program is linked against, such as `3.45.1`.
+ fn version() String
```

### convert

Converts any supported value (integers, floats, bools, text, json values, and nullable
versions of those) into a `Value`.

### database

Returns the connection as a `sql.Db`, the database type of the `valk-sql` package.

Everything `valk-sql` offers — the query builder, migrations, pools, rows read into your own
classes — then works on this database, and the same code runs on MySQL or Postgres by
opening it with their driver instead.

The connection itself stays usable: this is a view of it, not a replacement.

```valk
use sql
use sqlite

let db = sqlite.database(sqlite.open("app.db") ! panic("%{E.message}"))
db.exec("INSERT INTO users (name) VALUES (?)", .{ sql.Value.of("Ada") }) ! panic("%{E.message}")
```

### open

Opens a database file, creating it when it does not exist.

The directories above it are not created. `:memory:` opens a database that lives in memory
and disappears with the connection; `open_memory` says that more clearly.

```valk
let db = sqlite.open("app.db") ! panic("Cannot open: %{E.message}")
defer db.close()
```

### open_memory

Opens a database that lives in memory and disappears when the connection closes.

Every connection gets its own: two of them never see the same data.

### placeholders

Returns `?, ?, ?` for `count` values, to write an `IN (...)` list.

SQLite binds one value per placeholder, so a list needs as many as it has values. The values
themselves go in with `bindv`, in the same order.

```valk
let ids = Array[uint]{ 1, 2, 3 }
each ids as id : db.bindv(id)
let rows = db.select("SELECT * FROM users WHERE id IN (" + sqlite.placeholders(ids.length) + ")") ! panic("%{E.message}")
```

### version

The SQLite version the program is linked against, such as `3.45.1`.

## Classes for 'main'

```js
// What an aggregate function does with the rows it is given.
+ interface Aggregate {
    // Returns the result, after the last row.
    + fn finish() Value !Error
    // Takes one row into the result.
    + fn step(args: Array[Value]) void !Error
}
```

### Aggregate

What an aggregate function does with the rows it is given.

One of these is made for every aggregation: `step` is called once per row and `finish`
returns the answer. An error thrown by either reaches the query.

#### finish

Returns the result, after the last row.

#### step

Takes one row into the result.

```js
// What a checkpoint did. After `truncate` both counts are 0, since the WAL is then empty.
+ class CheckpointResult {
    // Whether a `full`, `restart` or `truncate` checkpoint gave up waiting, after the busy timeout, and copied only what it could.
    + busy: bool
    // The pages of the WAL that are now in the database file.
    + checkpointed_pages: uint
    // The pages in the WAL.
    + wal_pages: uint
}
```

### CheckpointResult

What a checkpoint did. After `truncate` both counts are 0, since the WAL is then empty.

#### busy

Whether a `full`, `restart` or `truncate` checkpoint gave up waiting, after the busy
timeout, and copied only what it could.

#### checkpointed_pages

The pages of the WAL that are now in the database file.

#### wal_pages

The pages in the WAL.

```js
// One connection to one database.
+ class Connection {
    // Rows changed by the last `INSERT`, `UPDATE` or `DELETE`; for a `SELECT` the number of rows that were read, known once every row has been fetched.
    ~+ affected_rows: uint
    // Whether the connection was closed.
    ~ closed: bool
    // The column names of the running query, in order.
    ~+ column_names: Array[String]
    // Prints every statement before it runs.
    + debug: bool
    // Whether the database lives in memory.
    + in_memory: bool
    // The rowid the last `INSERT` on this connection wrote.
    ~+ last_insert_id: int
    // The path the database was opened with.
    + path: String
    // Counts the statements that have run, so that the rows of a query can tell whether another statement took the connection from under them.
    ~+ query_serial: uint
    // How many prepared statements are kept. A query that is run again is prepared once and then reused while it stays in the cache.
    + statement_cache_size: uint
    // How many statements were prepared on this connection. A query that hits the cache does not raise it, so this tells whether the cache is doing its work.
    ~+ statements_prepared: uint

    // Copies the whole database into a file, while other connections keep using it.
    + fn backup_to(path: String) void !Error
    // Starts a transaction.
    + fn begin(immediate: bool (false)) void !Error
    // Binds a value to the `:name` placeholder of the next query.
    + fn bind(name: String, value: $T) void
    // Binds a value to the next `?` placeholder of the next query.
    + fn bindv(value: $T) void
    // Copies the pages of the WAL into the database file, as a commit does on its own every 1000 pages unless `set_wal_autocheckpoint` changed that.
    + fn checkpoint(mode: Checkpoint (Checkpoint.passive)) CheckpointResult !Error
    // Removes the values bound with `bind` and `bindv`.
    + fn clear_binds() void
    // Closes the connection and releases every prepared statement. Further calls throw `closed`.
    + fn close() void
    // Returns column `index` as a bool, like `Value.to_bool`.
    + fn col_bool(index: uint) bool
    // Returns the number of columns of the current result.
    + fn col_count() uint
    // Returns column `index` as a float; text is parsed, NULL is 0.
    + fn col_float(index: uint) float
    // Like `col_float`, but null for NULL.
    + fn col_float_or_null(index: uint) ?float
    // Returns the index of the column named `name`.
    + fn col_index(name: String) uint !LookupError
    // Returns column `index` as an integer, converted the way SQLite converts: text is parsed, floats are truncated, NULL is 0.
    + fn col_int(index: uint) int
    // Like `col_int`, but null for NULL.
    + fn col_int_or_null(index: uint) ?int
    // Returns whether column `index` of the current row is NULL (or missing).
    + fn col_is_null(index: uint) bool
    // Returns the name of column `index`, or "" when there is no such column.
    + fn col_name(index: uint) String
    // Returns column `index` as a new string, "" for NULL; numbers are formatted.
    + fn col_string(index: uint) String
    // Like `col_string`, but null for NULL.
    + fn col_string_or_null(index: uint) ?String
    // Returns the kind of value in column `index` of the current row; `null` when there is no row or no such column.
    + fn col_type(index: uint) TYPE
    // Returns column `index` as a `Value`, as `fetch_row` would put it in the map.
    + fn col_value(index: uint) Value
    // Returns the bytes of column `index`, text or blob, without allocating; numbers come as text and NULL as empty. The view is valid until the next row is read.
    + fn col_view(index: uint) &[u8]
    // Commits the open transaction.
    + fn commit() void !Error
    // Registers an aggregate function, which SQL can use like `count` or `sum`.
    + fn create_aggregate(name: String, arg_count: int, new_state: fn()(Aggregate), deterministic: bool (false)) void !Error
    // Registers a collation: a way of ordering text, used with `COLLATE` and by an index.
    + fn create_collation(name: String, compare: fn(String, String)(int)) void !Error
    // Registers a function that SQL on this connection can call.
    + fn create_function(name: String, arg_count: int, handler: fn(Array[Value])(Value !Error), deterministic: bool (false)) void !Error
    // Runs one or more statements and reads no rows, for schema changes and scripts.
    + fn exec(sql: String) void !Error
    // Returns every row that is left.
    + fn fetch_all() Array[Map[Value]] !Error
    // Returns the next row, or null when there is none left.
    + fn fetch_one() ?Map[Value] !Error
    // Reads the next row into `row` and returns whether there was one.
    + fn fetch_row(row: Map[Value]) bool !Error
    // Returns the first column of the next row, or NULL when there is no row left.
    + fn fetch_value() Value !Error
    // Ends the running query: the rows it did not read are dropped and SQLite lets go of the statement, and of the read lock it holds. A query that was read to the end needs no call; this is for stopping early, such as after the first row.
    + fn finish() void
    // Returns the value of `PRAGMA name`, or "" when it has none.
    + fn get_pragma(name: String) String !Error
    // The `sqlite3*` of the connection, for calling a SQLite function this package does not wrap. Unsafe: it is invalid once the connection is closed, and it belongs to the thread of the connection like the connection itself.
    + fn handle() ptr
    // Returns whether a transaction is open.
    + fn in_transaction() bool
    // Stops the query that is running on this connection from another thread.
    + fn interrupt() void
    // Returns whether the database can only be read.
    + fn is_read_only() bool
    // Moves to the next row without building a map, and returns false when there is none left. Its columns are read with the `col_*` methods by index, from 0.
    + fn next_row() bool !Error
    // Prepares a statement to run many times, with other values each time.
    + fn prepare(sql: String) Statement !Error
    // Runs one statement. Rows, if any, are read with `fetch_row`, `fetch_one`, `fetch_all` or `fetch_value`.
    + fn query(sql: String, binds: ?Map[?Value] (null)) void !Error
    // Forgets a savepoint, keeping everything that was done since.
    + fn release(name: String) void !Error
    // Removes a function that was registered with `create_function`.
    + fn remove_function(name: String, arg_count: int) void !Error
    // Removes the hook set with `wal_hook`. The automatic checkpoint stays off until `set_wal_autocheckpoint` turns it on again.
    + fn remove_wal_hook() void
    // Rolls the open transaction back.
    + fn rollback() void !Error
    // Rolls back to a savepoint, keeping the transaction itself open.
    + fn rollback_to(name: String) void !Error
    // Runs a statement that reads no rows, such as an `INSERT`, and returns how many rows it changed.
    + fn run(sql: String, binds: ?Map[?Value] (null)) uint !Error
    // Names a point inside a transaction that can be rolled back to on its own.
    + fn savepoint(name: String) void !Error
    // Runs a statement and returns the rows it answered with, in one call.
    + fn select(sql: String, binds: ?Map[?Value] (null)) Array[Map[Value]] !Error
    // Runs `PRAGMA name = value`, for a setting this package has no option for.
    + fn set_pragma(name: String, value: String) void !Error
    // Sets after how many pages in the WAL a commit checkpoints it; 0 turns the automatic checkpoint off, so that only `checkpoint` does it. SQLite's default is 1000.
    + fn set_wal_autocheckpoint(pages: uint) void !Error
    // Runs a statement that answers with one value, and returns it.
    + fn value(sql: String, binds: ?Map[?Value] (null)) Value !Error
    // Calls `handler` after every commit to the WAL, with the number of pages the WAL then holds. That is the moment to tell a checkpoint thread that the WAL grew past a limit.
    + fn wal_hook(handler: fn(uint)()) void !Error
}
```

### Connection

One connection to one database.

SQLite runs in the program itself, so a call does its work on the calling thread and blocks
it, coroutines included, until it is done. A connection belongs to one thread; give every
thread its own.

#### affected_rows

Rows changed by the last `INSERT`, `UPDATE` or `DELETE`; for a `SELECT` the number of
rows that were read, known once every row has been fetched.

#### closed

Whether the connection was closed.

#### column_names

The column names of the running query, in order.

#### debug

Prints every statement before it runs.

#### in_memory

Whether the database lives in memory.

#### last_insert_id

The rowid the last `INSERT` on this connection wrote.

#### path

The path the database was opened with.

#### query_serial

Counts the statements that have run, so that the rows of a query can tell whether
another statement took the connection from under them.

#### statement_cache_size

How many prepared statements are kept. A query that is run again is prepared once and
then reused while it stays in the cache.

#### statements_prepared

How many statements were prepared on this connection. A query that hits the cache does
not raise it, so this tells whether the cache is doing its work.

#### backup_to

Copies the whole database into a file, while other connections keep using it.

This is SQLite's online backup: copying the file with `fs.copy` while a write is going
on can give a damaged copy, and this cannot. An existing file at `path` is overwritten.

```valk
db.backup_to("backup-" + time.DateTime.now().format("Y-m-d") + ".db") ! panic("%{E.message}")
```

#### begin

Starts a transaction.

`immediate` takes the write lock at once instead of at the first write, which is what a
transaction that reads a value and then writes it back wants: without it, two such
transactions can both read, and the second one to write is thrown out with `busy`.

#### bind

Binds a value to the `:name` placeholder of the next query.

The value stays bound until the query runs, and a name that the query does not use is
ignored, so settings that every query shares can be bound once.

#### bindv

Binds a value to the next `?` placeholder of the next query.

#### checkpoint

Copies the pages of the WAL into the database file, as a commit does on its own every
1000 pages unless `set_wal_autocheckpoint` changed that.

A program that writes a lot can turn the automatic checkpoint off on its writers and run
this from a connection of its own on another thread, so that no commit has to wait for
one. Any running query on this connection is ended first.

```valk
let result = db.checkpoint(sqlite.Checkpoint.truncate) ! panic("%{E.message}")
```

#### clear_binds

Removes the values bound with `bind` and `bindv`.

#### close

Closes the connection and releases every prepared statement. Further calls throw
`closed`.

#### col_bool

Returns column `index` as a bool, like `Value.to_bool`.

#### col_count

Returns the number of columns of the current result.

#### col_float

Returns column `index` as a float; text is parsed, NULL is 0.

#### col_float_or_null

Like `col_float`, but null for NULL.

#### col_index

Returns the index of the column named `name`.

#### col_int

Returns column `index` as an integer, converted the way SQLite converts: text is
parsed, floats are truncated, NULL is 0.

#### col_int_or_null

Like `col_int`, but null for NULL.

#### col_is_null

Returns whether column `index` of the current row is NULL (or missing).

#### col_name

Returns the name of column `index`, or "" when there is no such column.

#### col_string

Returns column `index` as a new string, "" for NULL; numbers are formatted.

#### col_string_or_null

Like `col_string`, but null for NULL.

#### col_type

Returns the kind of value in column `index` of the current row; `null` when there is
no row or no such column.

#### col_value

Returns column `index` as a `Value`, as `fetch_row` would put it in the map.

#### col_view

Returns the bytes of column `index`, text or blob, without allocating; numbers come as
text and NULL as empty. The view is valid until the next row is read.

#### commit

Commits the open transaction.

#### create_aggregate

Registers an aggregate function, which SQL can use like `count` or `sum`.

`new_state` is called once per aggregation and returns the object that collects the
rows; `arg_count` is how many arguments the function takes, or -1 for any number.

```valk
class Median is sqlite.Aggregate {
    values: Array[float] (.{})
    + fn step(args: Array[sqlite.Value]) !sqlite.Error {
        this.values.append((args.get(0) !? sqlite.Value.null()).to_float())
    }
    + fn finish() sqlite.Value !sqlite.Error {
        if this.values.length == 0 : return sqlite.Value.null()
        this.values.sort()
        return sqlite.Value.of_float(this.values.get(this.values.length / 2) !? 0)
    }
}

db.create_aggregate("median", 1, fn() sqlite.Aggregate { return Median {} }) ! panic("%{E.message}")
let middle = db.value("SELECT median(score) FROM results") ! panic("%{E.message}")
```

#### create_collation

Registers a collation: a way of ordering text, used with `COLLATE` and by an index.

`compare` returns a negative number when `left` sorts first, 0 when they are equal, and a
positive number when `right` sorts first. It must be consistent, or the ordering of a
query becomes unpredictable: equal arguments always 0, and the same pair always the same
answer.

```valk
db.create_collation("nocase_unicode", fn(left: String, right: String) int {
    let a = left.lower()
    let b = right.lower()
    if a == b : return 0
    return a < b ? -1 : 1
}) ! panic("%{E.message}")

db.query("SELECT name FROM users ORDER BY name COLLATE nocase_unicode") ! panic("%{E.message}")
```

#### create_function

Registers a function that SQL on this connection can call.

`arg_count` is how many arguments it takes, or -1 for any number. The handler is given
the arguments and returns the result; an error it throws reaches the query as a SQLite
error, so `db.query` throws `error` with that message.

`deterministic` says that the same arguments always give the same answer, which lets
SQLite use the function in an index or a `WHERE` clause it optimizes. Leave it off for a
function that reads a clock, a counter or anything else that changes.

```valk
db.create_function("slugify", 1, fn(args: Array[sqlite.Value]) sqlite.Value !sqlite.Error {
    let text = (args.get(0) !? sqlite.Value.null()).to_string()
    return sqlite.Value.of(text.lower().replace(" ", "-"))
}, true) ! panic("%{E.message}")

let slug = db.value("SELECT slugify(title) FROM posts WHERE id = 1") ! panic("%{E.message}")
```

The handler runs while the query runs, on the same thread, so it may not use the
connection it was registered on.

#### exec

Runs one or more statements and reads no rows, for schema changes and scripts.

The statements are separated by `;`. Placeholders cannot be used here; `query` is for
statements with values in them.

#### fetch_all

Returns every row that is left.

#### fetch_one

Returns the next row, or null when there is none left.

#### fetch_row

Reads the next row into `row` and returns whether there was one.

The map is cleared first, so one map can be reused for every row of a query, which saves
an allocation per row.

```valk
let row: Map[sqlite.Value] = .{}
while db.fetch_row(row) ! panic("%{E.message}") {
    println(row["name"] ?? "")
}
```

#### fetch_value

Returns the first column of the next row, or NULL when there is no row left.

This is for the queries that answer with one value, such as `SELECT count(*) FROM users`.

#### finish

Ends the running query: the rows it did not read are dropped and SQLite lets go of the
statement, and of the read lock it holds. A query that was read to the end needs no
call; this is for stopping early, such as after the first row.

```valk
db.query("SELECT id FROM users WHERE name = :name", .{ "name" => name }) ! panic("%{E.message}")
let found = db.next_row() ! panic("%{E.message}")
let id = found ? db.col_int(0) : 0
db.finish()
```

Starting another query ends the running one as well.

#### get_pragma

Returns the value of `PRAGMA name`, or "" when it has none.

#### handle

The `sqlite3*` of the connection, for calling a SQLite function this package does not
wrap. Unsafe: it is invalid once the connection is closed, and it belongs to the thread
of the connection like the connection itself.

#### in_transaction

Returns whether a transaction is open.

#### interrupt

Stops the query that is running on this connection from another thread.

The call that is waiting throws `interrupted`. Nothing else uses it, since a statement
blocks the thread that runs it.

#### is_read_only

Returns whether the database can only be read.

#### next_row

Moves to the next row without building a map, and returns false when there is none
left. Its columns are read with the `col_*` methods by index, from 0.

```valk
db.query("SELECT id, name, email FROM users") ! panic("%{E.message}")
while db.next_row() ! panic("%{E.message}") {
    let id = db.col_int(0)
    let name = db.col_string(1)
    let email = db.col_string_or_null(2)
}
```

#### prepare

Prepares a statement to run many times, with other values each time.

The SQL is parsed once, here; running the statement only binds its values. Values go in
by name from a map, for `:name`, `@name` and `$name`, or by position with
`Statement.bind`, which also fills `?`.

```valk
let find = db.prepare("SELECT * FROM users WHERE id = :id") ! panic("%{E.message}")
defer find.close()
let users = find.select(.{ "id" => 1 }) ! panic("%{E.message}")
```

#### query

Runs one statement. Rows, if any, are read with `fetch_row`, `fetch_one`, `fetch_all` or
`fetch_value`.

Values in `binds` are bound to the `:name` placeholders of the statement, next to what
`bind` and `bindv` bound earlier. SQLite understands `:name`, `@name`, `$name` and `?`,
and this package binds them all; a `?` takes the next value given to `bindv`.

The statement is prepared once and kept, so running it again with other values is
cheaper. Use `exec` for several statements at once.

```valk
db.query("SELECT * FROM users WHERE age > :age", .{ "age" => 18 }) ! panic("%{E.message}")
let users = db.fetch_all() ! panic("%{E.message}")
```

#### release

Forgets a savepoint, keeping everything that was done since.

#### remove_function

Removes a function that was registered with `create_function`.

#### remove_wal_hook

Removes the hook set with `wal_hook`. The automatic checkpoint stays off until
`set_wal_autocheckpoint` turns it on again.

#### rollback

Rolls the open transaction back.

#### rollback_to

Rolls back to a savepoint, keeping the transaction itself open.

#### run

Runs a statement that reads no rows, such as an `INSERT`, and returns how many rows it
changed.

#### savepoint

Names a point inside a transaction that can be rolled back to on its own.

#### select

Runs a statement and returns the rows it answered with, in one call.

#### set_pragma

Runs `PRAGMA name = value`, for a setting this package has no option for.

#### set_wal_autocheckpoint

Sets after how many pages in the WAL a commit checkpoints it; 0 turns the automatic
checkpoint off, so that only `checkpoint` does it. SQLite's default is 1000.

SQLite does this with the WAL hook, so this removes a hook set with `wal_hook`, and
`wal_hook` turns the automatic checkpoint off.

#### value

Runs a statement that answers with one value, and returns it.

```valk
let total = (db.value("SELECT count(*) FROM users") ! panic("%{E.message}")).to_int()
```

#### wal_hook

Calls `handler` after every commit to the WAL, with the number of pages the WAL then
holds. That is the moment to tell a checkpoint thread that the WAL grew past a limit.

The handler runs inside the commit, on the thread of this connection, and may not use
the connection; keep it short, such as sending to a channel. Setting a hook turns the
automatic checkpoint off, and replaces an earlier hook.

```valk
db.wal_hook(fn(pages: uint) {
    if pages > 4000 : checkpoints.send(pages)
}) ! panic("%{E.message}")
```

```js
// The settings a database is opened with.
+ class OpenOptions {
    // How long a statement waits for another connection to let go of the database, in milliseconds, before it throws `busy`.
    + busy_timeout_ms: uint
    // Creates the database when the file does not exist yet.
    + create: bool
    // Whether foreign keys are enforced. SQLite leaves them off; this package turns them on, since a foreign key that is not enforced is usually a surprise.
    + foreign_keys: bool
    // The journal mode to set. Left alone for a database in memory.
    + journal: Journal
    // Opens the database for reading only. Writing then throws `readonly`.
    + read_only: bool
    // Whether the path may be a `file:` URI with settings of its own.
    + uri: bool
    // After how many pages in the WAL a commit checkpoints it, see `Connection.set_wal_autocheckpoint`; 0 turns that off. Null keeps SQLite's 1000.
    + wal_autocheckpoint: ?uint
}
```

### OpenOptions

The settings a database is opened with.

#### busy_timeout_ms

How long a statement waits for another connection to let go of the database, in
milliseconds, before it throws `busy`.

#### create

Creates the database when the file does not exist yet.

#### foreign_keys

Whether foreign keys are enforced. SQLite leaves them off; this package turns them on,
since a foreign key that is not enforced is usually a surprise.

#### journal

The journal mode to set. Left alone for a database in memory.

#### read_only

Opens the database for reading only. Writing then throws `readonly`.

#### uri

Whether the path may be a `file:` URI with settings of its own.

#### wal_autocheckpoint

After how many pages in the WAL a commit checkpoints it, see
`Connection.set_wal_autocheckpoint`; 0 turns that off. Null keeps SQLite's 1000.

```js
// A statement prepared once and run as often as needed, made by `Connection.prepare`.
+ class Statement {
    // The SQL the statement was prepared from.
    ~+ sql: String

    // Binds `value` to placeholder `index`, counted from 1 in the order the placeholders first appear, as in SQL's `?1`. Integers, floats, bools, text, `Value`, `json.Value` and their nullable versions are taken.
    + fn bind(index: uint, value: $T) void
    // Binds bytes as a blob to placeholder `index`, see `bind`.
    + fn bind_blob(index: uint, data: String) void
    // Binds a float to placeholder `index`, see `bind`.
    + fn bind_float(index: uint, value: float) void
    // Binds an integer to placeholder `index`, see `bind`.
    + fn bind_int(index: uint, value: int) void
    // Binds NULL to placeholder `index`, see `bind`.
    + fn bind_null(index: uint) void
    // Binds text to placeholder `index`, see `bind`.
    + fn bind_text(index: uint, text: String) void
    // Binds a `Value` to placeholder `index`, see `bind`.
    + fn bind_value(index: uint, value: Value) void
    // Releases the statement. Running it afterwards throws `closed`.
    + fn close() void
    // The `sqlite3_stmt*` of the statement, for calling a SQLite function this package does not wrap. Unsafe: it is invalid once the statement is closed, and stepping or resetting it directly confuses the connection.
    + fn handle() ptr
    // Runs the statement with `values` bound to its `:name` placeholders. Rows, if any, are read with `next_row`, `fetch_row`, `fetch_one`, `fetch_all` or `fetch_value` of the connection.
    + fn query(values: ?Map[?Value] (null)) void !Error
    // Stops the statement when it is running, dropping the rows that were not read, so that SQLite lets go of what it holds. Its bound values stay. Running it again resets it as well, so this is only needed to let go early.
    + fn reset() void
    // Runs the statement and returns how many rows it changed.
    + fn run(values: ?Map[?Value] (null)) uint !Error
    // Runs the statement and returns every row it answered with.
    + fn select(values: ?Map[?Value] (null)) Array[Map[Value]] !Error
    // Runs the statement and returns the first column of its first row, NULL when there is none.
    + fn value(values: ?Map[?Value] (null)) Value !Error
}
```

### Statement

A statement prepared once and run as often as needed, made by `Connection.prepare`.

Its values go in by name from a map, as with `Connection.query`, or by position with `bind`.
Its rows are read with `next_row` or the fetch methods of the connection. `close` releases it; a statement that is dropped without that is
released when it is collected.

```valk
let insert = db.prepare("INSERT INTO users (name, age) VALUES (:name, :age)") ! panic("%{E.message}")
defer insert.close()
each people as person {
    insert.run(.{ "name" => person.name, "age" => person.age }) ! panic("%{E.message}")
}
```

#### sql

The SQL the statement was prepared from.

#### bind

Binds `value` to placeholder `index`, counted from 1 in the order the placeholders first
appear, as in SQL's `?1`. Integers, floats, bools, text, `Value`, `json.Value` and
their nullable versions are taken.

A value stays bound until it is bound again, over any number of runs; a placeholder
that never got one is NULL. An index the statement does not have throws `syntax` on the
next run.

```valk
let find = db.prepare("SELECT id, name FROM users WHERE age > ? AND city = ?") ! panic("%{E.message}")
find.bind(1, 18)
find.bind(2, "Ghent")
find.query() ! panic("%{E.message}")
```

#### bind_blob

Binds bytes as a blob to placeholder `index`, see `bind`.

#### bind_float

Binds a float to placeholder `index`, see `bind`.

#### bind_int

Binds an integer to placeholder `index`, see `bind`.

#### bind_null

Binds NULL to placeholder `index`, see `bind`.

#### bind_text

Binds text to placeholder `index`, see `bind`.

#### bind_value

Binds a `Value` to placeholder `index`, see `bind`.

#### close

Releases the statement. Running it afterwards throws `closed`.

#### handle

The `sqlite3_stmt*` of the statement, for calling a SQLite function this package does not
wrap. Unsafe: it is invalid once the statement is closed, and stepping or resetting it
directly confuses the connection.

#### query

Runs the statement with `values` bound to its `:name` placeholders. Rows, if any, are
read with `next_row`, `fetch_row`, `fetch_one`, `fetch_all` or `fetch_value` of the
connection.

With `values`, every placeholder needs a value; a name without one throws `syntax`.
Without, the statement runs with what `bind` and the other bind methods bound.

#### reset

Stops the statement when it is running, dropping the rows that were not read, so that
SQLite lets go of what it holds. Its bound values stay. Running it again resets it as
well, so this is only needed to let go early.

#### run

Runs the statement and returns how many rows it changed.

#### select

Runs the statement and returns every row it answered with.

#### value

Runs the statement and returns the first column of its first row, NULL when there is
none.

```js
// A value read from a row, or bound to a query.
+ class Value {
    // Which of the kinds this value is.
    + type: TYPE

    // Returns whether the value is a blob.
    + fn is_blob() bool
    // Returns whether the value is NULL.
    + fn is_null() bool
    // Returns a NULL value.
    + static fn null() Value
    // Returns a text value.
    + static fn of(text: String) Value
    // Returns a blob value; the bytes are stored as they are.
    + static fn of_blob(data: String) Value
    // Returns a floating point value.
    + static fn of_float(number: float) Value
    // Returns an integer value.
    + static fn of_int(number: int) Value
    // Returns the value as a bool: any number other than 0, and the texts `1`, `true`, `t`, `yes` and `on`, are true.
    + fn to_bool() bool
    // Returns the value as a float; text is parsed, NULL is 0.
    + fn to_float() float
    // Returns the value as an integer; text is parsed, floats are truncated, NULL is 0.
    + fn to_int() int
    // Parses the value as JSON. Returns json null when the text is not valid JSON.
    + fn to_json() Value
    // Returns the value as text; numbers are formatted, NULL becomes "".
    + fn to_string() String
    // Like `to_string`, but null for NULL, which tells an empty value apart from a missing one.
    + fn to_string_or_null() ?String
    // Returns the value as an unsigned integer; negative numbers become 0.
    + fn to_uint() uint
}
```

### Value

A value read from a row, or bound to a query.

SQLite stores what it is given rather than what a column declares, so a column declared
`INTEGER` can hold text. `type` says what came back and the `to_*` methods convert.

#### type

Which of the kinds this value is.

#### is_blob

Returns whether the value is a blob.

#### is_null

Returns whether the value is NULL.

#### null

Returns a NULL value.

#### of

Returns a text value.

#### of_blob

Returns a blob value; the bytes are stored as they are.

#### of_float

Returns a floating point value.

#### of_int

Returns an integer value.

#### to_bool

Returns the value as a bool: any number other than 0, and the texts `1`, `true`, `t`,
`yes` and `on`, are true.

SQLite has no boolean type of its own; `true` and `false` in SQL are the numbers 1 and 0.

#### to_float

Returns the value as a float; text is parsed, NULL is 0.

#### to_int

Returns the value as an integer; text is parsed, floats are truncated, NULL is 0.

#### to_json

Parses the value as JSON. Returns json null when the text is not valid JSON.

#### to_string

Returns the value as text; numbers are formatted, NULL becomes "".

#### to_string_or_null

Like `to_string`, but null for NULL, which tells an empty value apart from a missing one.

#### to_uint

Returns the value as an unsigned integer; negative numbers become 0.
