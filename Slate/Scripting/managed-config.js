// Resolves the managed `config` object written by the Slate configuration window
// into plain settings and bindings. Has no dependencies so it can run in any
// JSContext: the live config context (via slate.applyConfig) and the isolated
// context the configuration window uses to read and validate ~/.slate.js.
(function(root) {
  var SECTIONS = ['settings', 'modifiers', 'monitors', 'positions', 'aliases', 'bindings'];
  var ALIAS_SECTIONS = ['modifiers', 'monitors', 'positions', 'aliases'];
  var ALIAS_PATTERN = /\$\{([^}]*)\}/g;
  var MAX_ALIAS_DEPTH = 20;

  function isPlainObject(x) {
    return x !== null && typeof x === 'object' && !Array.isArray(x);
  }

  function aliasTable(config) {
    var table = {};
    ALIAS_SECTIONS.forEach(function(section) {
      var entries = config[section];
      if (entries === undefined || entries === null) return;
      if (!isPlainObject(entries)) {
        throw 'config.' + section + ' must be an object';
      }
      Object.keys(entries).forEach(function(name) {
        var value = entries[name];
        if (typeof value !== 'string' && typeof value !== 'number') {
          throw 'config.' + section + '.' + name + ' must be a string or number';
        }
        if (Object.prototype.hasOwnProperty.call(table, name)) {
          throw 'Alias "' + name + '" is defined more than once';
        }
        table[name] = String(value);
      });
    });
    return table;
  }

  // Replaces ${name} references, following aliases that reference other aliases.
  // Mirrors the legacy ~/.slate behavior of failing on an unknown alias.
  function expand(text, table, where) {
    var result = String(text);
    for (var depth = 0; result.indexOf('${') !== -1; depth++) {
      if (depth >= MAX_ALIAS_DEPTH) {
        throw 'Alias references loop forever in ' + where;
      }
      result = result.replace(ALIAS_PATTERN, function(match, name) {
        if (!Object.prototype.hasOwnProperty.call(table, name)) {
          throw 'Unrecognized alias ${' + name + '} in ' + where;
        }
        return table[name];
      });
    }
    return result;
  }

  function resolveSettings(config, table) {
    var settings = config.settings;
    if (settings === undefined || settings === null) return [];
    if (!isPlainObject(settings)) throw 'config.settings must be an object';
    return Object.keys(settings).map(function(name) {
      var value = settings[name];
      var where = 'setting "' + name + '"';
      if (Array.isArray(value)) value = value.join(';');
      if (typeof value === 'string') {
        value = expand(value, table, where);
      } else if (typeof value !== 'number' && typeof value !== 'boolean') {
        throw where + ' must be a string, number, boolean, or array';
      }
      return { name: name, value: value };
    });
  }

  function resolveBindings(config, table) {
    var bindings = config.bindings;
    if (bindings === undefined || bindings === null) return [];
    if (!Array.isArray(bindings)) throw 'config.bindings must be an array';
    var resolved = [];
    bindings.forEach(function(binding, index) {
      var where = 'binding #' + (index + 1);
      if (!isPlainObject(binding)) throw where + ' must be an object';
      if (typeof binding.key !== 'string' || binding.key.length === 0) {
        throw where + ' needs a key';
      }
      where += ' (' + binding.key + ')';
      if (typeof binding.action !== 'string' || binding.action.trim().length === 0) {
        throw where + ' needs an action';
      }
      if (binding.mods !== undefined && typeof binding.mods !== 'string') {
        throw where + ': mods must be a string';
      }
      if (binding.repeat !== undefined && binding.repeat !== null && typeof binding.repeat !== 'boolean') {
        throw where + ': repeat must be true or false';
      }
      if (binding.enabled === false) return;
      var key = expand(binding.key, table, where);
      var mods = binding.mods ? expand(binding.mods, table, where) : '';
      resolved.push({
        hotkey: mods.length > 0 ? key + ':' + mods : key,
        action: expand(binding.action, table, where).trim(),
        repeat: typeof binding.repeat === 'boolean' ? binding.repeat : undefined,
        index: index  // position in config.bindings, for error reporting
      });
    });
    return resolved;
  }

  function resolve(config) {
    if (!isPlainObject(config)) throw 'slate.applyConfig expects an object';
    Object.keys(config).forEach(function(section) {
      if (SECTIONS.indexOf(section) === -1) throw 'Unknown config section "' + section + '"';
    });
    var table = aliasTable(config);
    return {
      settings: resolveSettings(config, table),
      bindings: resolveBindings(config, table)
    };
  }

  root._slateManagedConfig = {
    SECTIONS: SECTIONS,
    ALIAS_SECTIONS: ALIAS_SECTIONS,
    expand: expand,
    resolve: resolve
  };
})(this);
