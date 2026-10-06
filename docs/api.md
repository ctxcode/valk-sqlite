
# Documentation

Namespaces: [main](#main)

---

# main

## Errors for 'main'

```js
// Thrown by every operation of this package.
+ error Error (open, syntax, constraint, busy, readonly, corrupt, interrupted, error, closed) payload { message: String, result_code: int (0), sql: String ("") }
```

## Enums for 'main'

```js
// How hard `Connection.checkpoint` tries, the modes of `sqlite3_wal_checkpoint_v2`.
+ enum Checkpoint { passive, full, restart, truncate }
// How SQLite keeps the rollback journal, which decides how readers and writers get along.
+ enum Journal { wal, delete, truncate, persist, memory, off, keep }
// The kinds of `Value`, which are the storage classes of SQLite.
+ enum TYPE { null, int, float, string, blob }
```

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
