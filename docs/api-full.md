
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
// How SQLite keeps the rollback journal, which decides how readers and writers get along.
+ enum Journal { wal, delete, truncate, persist, memory, off, keep }
// The kinds of `Value`, which are the storage classes of SQLite.
+ enum TYPE { null, int, float, string, blob }
```

### Journal

How SQLite keeps the rollback journal, which decides how readers and writers get along.

### TYPE

The kinds of `Value`, which are the storage classes of SQLite.

## Functions for 'main'

```js
// Converts any supported value (integers, floats, bools, text, json values, and nullable versions of those) into a `Value`.
+ fn convert(ndata: $T) Value
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
    // Removes the values bound with `bind` and `bindv`.
    + fn clear_binds() void
    // Closes the connection and releases every prepared statement. Further calls throw `closed`.
    + fn close() void
    // Commits the open transaction.
    + fn commit() void !Error
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
    // Returns the value of `PRAGMA name`, or "" when it has none.
    + fn get_pragma(name: String) String !Error
    // Returns whether a transaction is open.
    + fn in_transaction() bool
    // Stops the query that is running on this connection from another thread.
    + fn interrupt() void
    // Returns whether the database can only be read.
    + fn is_read_only() bool
    // Runs one statement. Rows, if any, are read with `fetch_row`, `fetch_one`, `fetch_all` or `fetch_value`.
    + fn query(sql: String, binds: ?Map[?Value] (null)) void !Error
    // Forgets a savepoint, keeping everything that was done since.
    + fn release(name: String) void !Error
    // Removes a function that was registered with `create_function`.
    + fn remove_function(name: String, arg_count: int) void !Error
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
    // Runs a statement that answers with one value, and returns it.
    + fn value(sql: String, binds: ?Map[?Value] (null)) Value !Error
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

#### clear_binds

Removes the values bound with `bind` and `bindv`.

#### close

Closes the connection and releases every prepared statement. Further calls throw
`closed`.

#### commit

Commits the open transaction.

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

#### get_pragma

Returns the value of `PRAGMA name`, or "" when it has none.

#### in_transaction

Returns whether a transaction is open.

#### interrupt

Stops the query that is running on this connection from another thread.

The call that is waiting throws `interrupted`. Nothing else uses it, since a statement
blocks the thread that runs it.

#### is_read_only

Returns whether the database can only be read.

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

#### value

Runs a statement that answers with one value, and returns it.

```valk
let total = (db.value("SELECT count(*) FROM users") ! panic("%{E.message}")).to_int()
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
