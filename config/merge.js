.pragma library

// Pure helpers for settings: defaults (settings.default.json) + user overrides.
// Plain objects merge per key; arrays and scalars are leaves (replaced whole).
// Paths are dot-separated, e.g. "bar.left". Tested by tests/merge.test.mjs.

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

function clone(v) {
    return v === undefined ? undefined : JSON.parse(JSON.stringify(v));
}

function deepMerge(base, over) {
    const out = isObject(base) ? clone(base) : {};
    if (!isObject(over))
        return out;
    for (const k of Object.keys(over)) {
        if (isObject(over[k]) && isObject(out[k]))
            out[k] = deepMerge(out[k], over[k]);
        else
            out[k] = clone(over[k]);
    }
    return out;
}

function deepEqual(a, b) {
    return JSON.stringify(sortKeys(a)) === JSON.stringify(sortKeys(b));
}

function sortKeys(v) {
    if (Array.isArray(v))
        return v.map(sortKeys);
    if (!isObject(v))
        return v;
    const out = {};
    for (const k of Object.keys(v).sort())
        out[k] = sortKeys(v[k]);
    return out;
}

function getPath(obj, path) {
    let cur = obj;
    for (const k of path.split(".")) {
        if (!isObject(cur))
            return undefined;
        cur = cur[k];
    }
    return cur;
}

function withPath(obj, path, value) {
    const out = isObject(obj) ? clone(obj) : {};
    const keys = path.split(".");
    let cur = out;
    for (const k of keys.slice(0, -1)) {
        if (!isObject(cur[k]))
            cur[k] = {};
        cur = cur[k];
    }
    cur[keys[keys.length - 1]] = clone(value);
    return out;
}

function withoutPath(obj, path) {
    const out = isObject(obj) ? clone(obj) : {};
    const keys = path.split(".");
    const stack = [out];
    for (const k of keys.slice(0, -1)) {
        const next = stack[stack.length - 1][k];
        if (!isObject(next))
            return out;
        stack.push(next);
    }
    delete stack[stack.length - 1][keys[keys.length - 1]];
    // prune parents left empty
    for (let i = stack.length - 1; i > 0; i--) {
        if (Object.keys(stack[i]).length > 0)
            break;
        delete stack[i - 1][keys[i - 1]];
    }
    return out;
}

// New overrides after setting `path` to `value`: stored only if it differs from the default.
function overridesAfterSet(defaults, overrides, path, value) {
    if (deepEqual(getPath(defaults, path), value))
        return withoutPath(overrides, path);
    return withPath(overrides, path, value);
}
