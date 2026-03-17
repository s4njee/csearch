'use strict';

/**
 * Lightweight mock for the knex query builder.
 *
 * Usage:
 *   const mock = createMockKnex({
 *     tables: {
 *       bills: [{ billid: 1, ... }],
 *       bill_actions: [{ acted_at: '...' }],
 *     },
 *     raw: (sql, bindings) => ({ rows: [{ exists: true }] }),
 *   });
 *
 * The mock supports the two main knex calling conventions:
 *   1. knex("table").where(...).select(...)           -> resolves to tables[table]
 *   2. knex.select(...).from("table as t").where(...) -> resolves to tables[table]
 *
 * .first() causes the chain to resolve to the first element (or null).
 * .insert() resolves to undefined.
 * knex.raw() invokes the raw handler (or returns { rows: [] }).
 */
function createMockKnex({ tables = {}, raw } = {}) {
  function stripAlias(name) {
    return name.replace(/^public\./, '').replace(/ as .*$/i, '').trim();
  }

  function resolveRows(name) {
    return name ? (tables[stripAlias(name)] ?? []) : [];
  }

  /**
   * Returns a chainable object that resolves to `rows` when awaited.
   * .from() updates the row source; .first() narrows to a single row.
   */
  function builder(rows) {
    let firstOnly = false;

    function resolveValue() {
      return firstOnly ? (rows[0] ?? null) : rows;
    }

    const self = {
      select:     () => self,
      from:       (name) => { rows = resolveRows(name); return self; },
      where:      () => self,
      whereRaw:   () => self,
      andWhere:   () => self,
      orWhere:    () => self,
      orderBy:    () => self,
      orderByRaw: () => self,
      groupBy:    () => self,
      leftJoin:   () => self,
      rightJoin:  () => self,
      innerJoin:  () => self,
      join:       () => self,
      limit:      () => self,
      offset:     () => self,
      first:      () => { firstOnly = true; return self; },
      insert:     async () => undefined,
      update:     async () => undefined,
      del:        async () => undefined,
      count:      () => self,
      // Thenable interface so the chain can be awaited
      then:  (resolve, reject) => Promise.resolve(resolveValue()).then(resolve, reject),
      catch: (fn)              => Promise.resolve(resolveValue()).catch(fn),
    };

    return self;
  }

  // The raw handler returns a thenable that doubles as a column expression
  const rawFn = raw || (() => ({ rows: [] }));

  function rawCall(sql, bindings) {
    const result = rawFn(sql, bindings);
    // Must be thenable (for `await knex.raw(...)`) and usable as a value
    // (for `knex.raw("COUNT(...)") passed inside .select(...)`)
    if (result && typeof result.then === 'function') {
      return result;
    }
    return {
      then:  (resolve, reject) => Promise.resolve(result).then(resolve, reject),
      catch: (fn)              => Promise.resolve(result).catch(fn),
    };
  }

  // knex("tableName") -> chain seeded with that table's rows
  const knex = (tableName) => builder(resolveRows(tableName));

  // knex.select(...).from("tableName") -> chain starts empty, from() sets rows
  knex.select = () => builder([]);
  knex.raw    = rawCall;

  return knex;
}

module.exports = { createMockKnex };
