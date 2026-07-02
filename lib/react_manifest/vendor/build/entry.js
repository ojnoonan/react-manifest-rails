// Source for lib/react_manifest/vendor/ast_extractor.js.
// Rebuild with: npm install && npx esbuild entry.js --bundle --format=iife --minify --outfile=../ast_extractor.js (see README.md in this directory).
import * as acorn from "acorn";
import jsx from "acorn-jsx";

const Parser = acorn.Parser.extend(jsx());

// Mirrors ReactManifest::SymbolExtractor::PASCAL_TOKEN_PATTERN / HOOK_TOKEN_PATTERN.
const PASCAL_OR_HOOK = /^(?:[A-Z][A-Za-z0-9_]*|use[A-Z][A-Za-z0-9_]*)$/;
// Mirrors ReactManifest::SymbolExtractor::LIB_CALL_PATTERN (lowercase function calls).
const LIB_CALL = /^[a-z][A-Za-z0-9_]{2,}$/;

// Mirrors ReactManifest::SymbolExtractor::JS_BUILTINS exactly.
const JS_BUILTINS = new Set([
  "require", "function", "return", "typeof", "instanceof", "delete", "void",
  "console", "document", "window", "location", "history", "navigator",
  "setTimeout", "setInterval", "clearTimeout", "clearInterval",
  "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI", "decodeURI",
  "fetch", "Promise", "Object", "Array", "String", "Number", "Boolean", "Math", "JSON",
  "Symbol", "Map", "Set", "WeakMap",
]);

function parse(content) {
  return Parser.parse(content, {
    ecmaVersion: "latest",
    sourceType: "module",
    locations: true,
  });
}

// Top-level const/let/var/function/class (or export variant) bindings whose
// name is PascalCase or use-prefixed. Mirrors DEFINITION_PATTERNS' intent.
function definitionsFromAst(ast) {
  const defs = [];
  const consider = (id) => {
    if (id && id.type === "Identifier" && PASCAL_OR_HOOK.test(id.name)) defs.push(id.name);
  };
  for (const node of ast.body) {
    let decl = node;
    if (node.type === "ExportNamedDeclaration" || node.type === "ExportDefaultDeclaration") {
      decl = node.declaration;
    }
    if (!decl) continue;
    if (decl.type === "VariableDeclaration") {
      for (const d of decl.declarations) consider(d.id);
    } else if (decl.type === "FunctionDeclaration") {
      consider(decl.id);
    } else if (decl.type === "ClassDeclaration") {
      consider(decl.id);
    }
  }
  return [...new Set(defs)];
}

// Real reference positions only: JSX element names, call/new callees, and
// generic identifier references (prop values, array elements, assignments,
// arguments) — explicitly excluding JSXText and StringLiteral content. This
// is what fixes the "Show" vs. "Show More" plain-text false positive.
function usagesFromAst(ast) {
  const used = new Set();
  const record = (name) => {
    if (JS_BUILTINS.has(name)) return;
    if (PASCAL_OR_HOOK.test(name)) used.add(name);
  };

  function walk(node, parent) {
    if (!node || typeof node.type !== "string") return;

    switch (node.type) {
      case "JSXIdentifier":
        record(node.name);
        break;
      case "CallExpression":
      case "NewExpression":
        if (node.callee && node.callee.type === "Identifier" && LIB_CALL.test(node.callee.name)) {
          if (!JS_BUILTINS.has(node.callee.name)) used.add(node.callee.name);
        }
        break;
      case "Identifier":
        // Skip non-computed member/property-key positions (obj.Foo, {Foo: 1})
        // where the identifier is a property name, not a symbol reference.
        if (parent && parent.type === "MemberExpression" && parent.property === node && !parent.computed) {
          break;
        }
        if (parent && parent.type === "Property" && parent.key === node && !parent.computed) {
          break;
        }
        record(node.name);
        break;
      default:
        break;
    }

    for (const key in node) {
      if (key === "loc" || key === "start" || key === "end" || key === "range") continue;
      const value = node[key];
      if (Array.isArray(value)) {
        for (const child of value) {
          if (child && typeof child.type === "string") walk(child, node);
        }
      } else if (value && typeof value.type === "string") {
        walk(value, node);
      }
    }
  }

  walk(ast, null);
  return [...used];
}

function errorInfo(e) {
  return {
    message: e.message || String(e),
    line: e.loc ? e.loc.line : null,
    column: e.loc ? e.loc.column : null,
  };
}

globalThis.__astExtractor = {
  extractDefinitions(content) {
    try {
      return { success: true, definitions: definitionsFromAst(parse(content)) };
    } catch (e) {
      return { success: false, error: errorInfo(e) };
    }
  },
  extractUsages(content) {
    try {
      const ast = parse(content);
      const defs = new Set(definitionsFromAst(ast));
      const used = usagesFromAst(ast).filter((name) => !defs.has(name));
      return { success: true, usages: used };
    } catch (e) {
      return { success: false, error: errorInfo(e) };
    }
  },
};
