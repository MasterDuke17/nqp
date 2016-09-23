'use strict';

class HashIter {
  constructor(hash) {
    this.hash = hash.content;
    this.keys = Object.keys(hash.$$toObject());
    this.target = this.keys.length;
    this.idx = 0;
  }

  $$shift() {
    return new IterPair(this.hash, this.keys[this.idx++]);
  }

  $$toBool(ctx) {
    return this.idx < this.target;
  }
};

class IterPair {
  constructor(hash, key) {
    this._key = key;
    this._hash = hash;
  }

  iterval() {
    return this._hash.get(this._key);
  }

  iterkey_s() {
    return this._key;
  }

  Str(ctx, _NAMED, self) {
    return this._key;
  }

  key(ctx, _NAMED, self) {
    return this._key;
  }

  value(ctx, _NAMED, self) {
    return this._hash.get(this._key);
  }
};

class Hash {
  constructor() {
    this.content = new Map();
  }

  $$bindkey(key, value) {
    this.content.set(key, value);
    return value;
  }

  $$atkey(key) {
    return this.content.has(key) ? this.content.get(key) : null;
  }

  $$existskey(key) {
    return this.content.has(key);
  }

  $$deletekey(key) {
    this.content.delete(key);
    return this;
  }

  $$clone() {
    var clone = new Hash();
    this.content.forEach(function(value, key, map) {
      clone.content.set(key, value);
    });
    return clone;
  }

  $$elems() {
    return this.content.size;
  }

  Num() {
    return this.$$elems();
  }

  $$toObject() {
    var ret = {};
    this.content.forEach(function(value, key, map) {
      ret[key] = value;
    });
    return ret;
  }

  $$toBool() {
    return this.content.size == 0 ? 0 : 1;
  }

  $$iterator() {
    return new HashIter(this);
  }
};

module.exports = Hash;
