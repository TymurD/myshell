// Unit tests for config/merge.js (a QML `.pragma library` JS file).
// Run: node --test tests/
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const src = readFileSync(new URL("../config/merge.js", import.meta.url), "utf8").replace(/^\.pragma library.*$/m, "");
const ctx = {};
vm.runInNewContext(src, ctx);
// Objects from the vm context have that realm's prototypes; round-trip them through
// JSON so deepStrictEqual compares plain data.
const M = Object.fromEntries(Object.entries(ctx).map(([k, f]) => [k, (...a) => {
    const r = f(...a);
    return r !== null && typeof r === "object" ? JSON.parse(JSON.stringify(r)) : r;
}]));

test("deepMerge replaces arrays and keeps sibling keys", () => {
    assert.deepEqual(M.deepMerge({ bar: { left: ["a", "b"], height: 34 } }, { bar: { left: ["b"] } }), { bar: { left: ["b"], height: 34 } });
});

test("deepMerge merges nested objects per key", () => {
    assert.deepEqual(M.deepMerge({ a: { b: 1 } }, { a: { c: 2 } }), { a: { b: 1, c: 2 } });
});

test("deepMerge with empty overrides copies without mutating", () => {
    const d = { a: { b: [1] } };
    const out = ctx.deepMerge(d, {});
    assert.deepEqual(JSON.parse(JSON.stringify(out)), d);
    out.a.b.push(2);
    assert.deepEqual(d, { a: { b: [1] } });
});

test("getPath reads dotted paths", () => {
    assert.equal(M.getPath({ a: { b: 2 } }, "a.b"), 2);
    assert.equal(M.getPath({ a: {} }, "a.b.c"), undefined);
});

test("withPath sets a dotted path on a copy", () => {
    const o = { a: { x: 1 } };
    assert.deepEqual(M.withPath(o, "a.b", 2), { a: { x: 1, b: 2 } });
    assert.deepEqual(o, { a: { x: 1 } });
});

test("withoutPath prunes empty parents", () => {
    assert.deepEqual(M.withoutPath({ bar: { left: [1] } }, "bar.left"), {});
    assert.deepEqual(M.withoutPath({ bar: { left: [1], h: 2 } }, "bar.left"), { bar: { h: 2 } });
});

test("deepEqual compares structurally", () => {
    assert.equal(M.deepEqual({ a: [1, { b: 2 }] }, { a: [1, { b: 2 }] }), true);
    assert.equal(M.deepEqual(["a", "b"], ["b", "a"]), false);
    assert.equal(M.deepEqual({ a: 1 }, { a: 1, b: 2 }), false);
});

test("overridesAfterSet stores a value that differs from the default", () => {
    assert.deepEqual(M.overridesAfterSet({ bar: { left: ["a", "b"] } }, {}, "bar.left", ["b", "a"]), { bar: { left: ["b", "a"] } });
});

test("overridesAfterSet drops a value equal to the default", () => {
    assert.deepEqual(M.overridesAfterSet({ bar: { left: ["a", "b"] } }, { bar: { left: ["b", "a"] } }, "bar.left", ["a", "b"]), {});
});
