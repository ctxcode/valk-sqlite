
# valk-sqlite

A SQLite client for [Valk](https://valk-lang.dev). It binds the SQLite C library, so the
database runs inside your program: no server, no port, no credentials, one file.

Requires Valk 0.7.2 or newer, and SQLite 3.24 or newer on the system:

| system | install |
| --- | --- |
| Debian, Ubuntu | `apt install libsqlite3-dev` |
| Fedora, RHEL | `dnf install sqlite-devel` |
| Arch | `pacman -S sqlite` |
| macOS | already there, or `brew install sqlite` |
| Windows | `sqlite3.dll` and `sqlite3.lib` next to the build, or in the library path |

This is the one valk package with a dependency outside valk itself: SQLite is 200k lines of C,
and a database file format is not something to reimplement.

## Install

```
vman install github.com/ctxcode/valk-sqlite
```

## Example

```rust
use sqlite

let db = sqlite.open("app.db") ! panic("Cannot open: %{E.message}")
defer db.close()

db.exec("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)") ! panic("%{E.message}")

// Write. Values are bound, never pasted into the SQL
db.run("INSERT INTO users (name, age) VALUES (:name, :age)", .{ "name" => "Ada", "age" => 36 }) ! panic("%{E.message}")
println("wrote row " + db.last_insert_id)

// Read every row
let users = db.select("SELECT * FROM users WHERE age > :age", .{ "age" => 18 }) ! panic("%{E.message}")
each users as user {
    println((user["name"] ?? sqlite.Value.null()).to_string())
}

// Read one value
let count = (db.value("SELECT count(*) FROM users") ! panic("%{E.message}")).to_int()
```

`run` returns the number of rows it changed, `select` returns every row, and `value` returns
the first column of the first row. For a result too large to hold in memory, `query` and
`fetch_row` walk it a row at a time:

```rust
db.query("SELECT id, name FROM users ORDER BY id") ! panic("%{E.message}")
let row: Map[sqlite.Value] = .{}
while (db.fetch_row(row) ! panic("%{E.message}")) {
    println((row["name"] ?? sqlite.Value.null()).to_string())
}
```

One map is reused for every row, so a long result costs one allocation rather than one per row.

## Values

A row is a `Map[sqlite.Value]`. SQLite stores what it is given rather than what a column
declares, so `Value.type` says what came back and the `to_*` methods convert:

```rust
value.is_null()             // the column was NULL
value.to_string()           // the bytes; numbers are formatted
value.to_string_or_null()   // null for NULL, to tell it apart from an empty string
value.to_int()              // text is parsed, floats are truncated
value.to_float()
value.to_bool()             // SQLite has no bool: 1 and 0, or the texts true/false/yes/on
value.to_json()             // parsed as JSON
value.is_blob()
```

Binding goes the other way by itself: integers, floats, bools, text, `json.Value` and their
nullable versions all convert. Blobs are explicit, since text and bytes are both a `String`:

```rust
db.run("INSERT INTO files (name, data) VALUES (:name, :data)", .{
    "name" => "logo.png"
    "data" => sqlite.Value.of_blob(bytes)
}) ! panic("%{E.message}")
```

Text and blobs keep every byte, zero bytes included.

## Placeholders

SQLite understands `:name`, `@name`, `$name` and `?`, and all of them work here. Values come
from the map passed to the query, or from `bind` and `bindv` beforehand:

```rust
db.run("UPDATE users SET name = :name WHERE id = :id", .{ "name" => "Ada", "id" => 1 }) ! panic("%{E.message}")

db.bind("tenant", tenant_id)      // stays bound until the next query runs
db.bindv("first ?")               // fills the next `?`
```

A name the statement does not use is ignored, so a setting every query shares can be bound
once. There is no list expansion: a `IN (...)` needs one placeholder per value, and
`sqlite.placeholders(n)` writes them.

## Transactions

```rust
db.begin() ! panic("%{E.message}")
db.run("UPDATE accounts SET balance = balance - 10 WHERE id = 1") ! { db.rollback() _ panic("%{E.message}") }
db.run("UPDATE accounts SET balance = balance + 10 WHERE id = 2") ! { db.rollback() _ panic("%{E.message}") }
db.commit() ! panic("%{E.message}")
```

`begin(true)` takes the write lock at once, which is what a transaction that reads a value and
then writes it back needs: without it two such transactions can both read, and the second one
to write is thrown out with `busy`. `savepoint`, `rollback_to` and `release` roll back a part
of a transaction.

Many writes belong in one transaction. SQLite commits each statement on its own otherwise,
which means a disk flush per row.

## Opening

```rust
let db = sqlite.open("app.db", .{
    read_only: false            // writing then throws `readonly`
    create: true                // create the file when it does not exist
    busy_timeout_ms: 5000       // how long to wait for another connection before `busy`
    foreign_keys: true          // enforced; SQLite itself leaves them off
    journal: sqlite.Journal.wal // readers and one writer at the same time
}) ! panic("%{E.message}")

let memory = sqlite.open_memory() ! panic("%{E.message}")   // gone when the connection closes
```

The defaults are what a program that serves requests wants: WAL, foreign keys on, and a wait
rather than an immediate `busy`.

## Threads and coroutines

SQLite runs in your program, so a query does its work on the calling thread and blocks it,
other coroutines included, until it is done. A connection belongs to one thread: give every
thread its own, as in

```rust
global db: sqlite.Connection (sqlite.open("app.db") !! )
```

which every thread runs for itself. Several connections to one file work together through the
database's own locking; that is what `busy_timeout_ms` and WAL are for.

## Functions written in Valk

SQL can call a Valk closure, which is how a rule that is easier to write in Valk than in SQL
gets used inside a query:

```rust
db.create_function("slugify", 1, fn(args: Array[sqlite.Value]) sqlite.Value !sqlite.Error {
    let text = (args.get(0) !? sqlite.Value.null()).to_string()
    return sqlite.Value.of(text.lower().replace(" ", "-"))
}, true) ! panic("%{E.message}")

let slug = db.value("SELECT slugify(title) FROM posts WHERE id = :id", .{ "id" => 1 }) ! panic("%{E.message}")
```

`arg_count` is how many arguments the function takes, or -1 for any number. The last argument
says the function is deterministic: the same arguments always give the same answer, which lets
SQLite use it in an index, as in `CREATE INDEX posts_slug ON posts (slugify(title))`. Leave it
off for anything that reads a clock or a counter.

An error the handler throws becomes the error of the query. The handler runs while the query
runs, on the same thread, so it may not use the connection it was registered on.

## Backups

```rust
db.backup_to("backup.db") ! panic("%{E.message}")
```

This is SQLite's online backup: it can run while other connections write. Copying the file
with `fs.copy` cannot, and can give a damaged copy.

## Errors

Every method throws `sqlite.Error`. `result_code` holds SQLite's own result code, extended
where SQLite has one, and `sql` the statement that failed:

| code | when |
| --- | --- |
| `open` | the file could not be opened or created |
| `syntax` | the SQL could not be prepared: a typo, an unknown table or column |
| `constraint` | a `UNIQUE`, `NOT NULL`, `CHECK` or foreign key rule was broken |
| `busy` | another connection held the database for longer than the busy timeout |
| `readonly` | the database is read-only |
| `corrupt` | the file is not a database, or it is damaged |
| `interrupted` | `interrupt` was called from another thread while the query ran |
| `error` | any other answer from SQLite |
| `closed` | the connection is closed |

```rust
db.run("INSERT INTO users (email) VALUES (:email)", .{ "email" => email }) ! {
    if error_is(E.code, constraint) : return "that email is already taken"
    throw E
}
```

## Statement cache

A query is prepared once and kept, so running it again with other values skips the parsing.
The cache holds 64 statements per connection; `db.statement_cache_size` changes that and
`db.statements_prepared` says how many statements were prepared, to check that the cache is
doing its work.

## With valk-sql

`sqlite.database(con)` turns a connection into a `sql.Db` of the
[valk-sql](https://github.com/ctxcode/valk-sql) package, which gives every database the same
API: a query builder, migrations, connection pools, and rows read into your own classes. The
same program then runs on another database by opening it with that driver instead.

```rust
use sql
use sqlite

let db = sqlite.database(sqlite.open("app.db") ! panic("%{E.message}"))
db.exec("INSERT INTO users (name, age) VALUES (?, ?)", .{ sql.Value.of("Ada"), sql.Value.of_int(36) }) ! panic("%{E.message}")
let rows = db.all("SELECT * FROM users WHERE age > ?", .{ sql.Value.of_int(18) }) ! panic("%{E.message}")
```

The connection itself keeps working as before: the wrapper is a view of it, and the driver's own
API stays there for the paths where every allocation counts.

## Development

`make test` runs the suite, which needs nothing but SQLite; databases are written under
`tests/tmp`. `make example` builds and runs the example, `make lint` checks the sources and
`make docs` regenerates the API documentation. Override the compiler with
`make vc=/path/to/valk test`.

## Not supported

Aggregate functions (`xStep`/`xFinal`), collations and the update, commit and authorizer hooks
are not bound; scalar functions are, see above. Neither are extensions, encryption, and the
session and serialization interfaces.
