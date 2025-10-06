-- title: Fillfactor
-- publication_date:
-- summary: PostgreSQL can leave some empty space in the storage pages for tables with a high volume of updates.

PostgreSQL uses a [page-based storage system](https://www.postgresql.org/docs/current/storage-page-layout.html) to store data. A page is a fixed-size block of data that is read from and written to disk as a unit.

Pages are filled to 100% of its capacity by default, but we can ask PostgreSQL to leave some empty space by setting `fillfactor` to a value smaller than 100.

```sql
ALTER TABLE my_table SET (fillfactor = 90);
```

[As the documentation explains](https://www.postgresql.org/docs/current/sql-createtable.html): when a smaller fillfactor is specified, `INSERT` operations pack table pages only to the indicated percentage; the remaining space on each page is reserved for updating rows on that page.

### When is it useful?

I discovered this option reading Que's source code. [There is a migration that sets `fillfactor` to 90 for the jobs table](https://github.com/que-rb/que/blob/master/lib/que/migrations/4/up.sql#L1).

Job are inserted as pending and then always updated with the result from `perform`. Leaving 10% of free space in the pages makes updates very likely to touch only one page, which is faster than updating two or more pages.

However... changing `fillfactor` is not something that would make a difference for most applications. It's nice to know, though.
