
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
