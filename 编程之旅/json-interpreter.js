function jread(v) {
  let ret = null;
  try {
    ret = JSON.parse(v);
  } catch (e) {
    ret = v;  // 解析失败就当字符串处理
  }
  return ret;
}

function jprint(v) {
  return v;
}

function interpreter(input, env) {
  let ret = null;
  for (let i = 0; i < input.length; ++i) {
    ret = jread(input[i]);
    ret = jeval(ret, env);   // 核心：求值
    ret = jprint(ret);
  }
  return ret;
}

function jeval(v, env) {
  // 原子值：直接返回（null 需单独判断，因为 typeof null === 'object'）
  if (v === null || typeof v !== 'object' || v instanceof Array) {
    return v;
  }

  let ev = null;
  switch (v.type) {
    case 'num':
    case 'str':
    case 'vec':
      // 变量定义：先求值，再存入环境
      ev = jeval(v.value, env);
      if (v.name) {
        jupdate(v.name, ev, env);
      }
      break;
    case 'var':
      // 变量引用：从环境里取
      ev = jlook(v.name, env);
      if (typeof ev === 'object' && ev !== null && !(ev instanceof Array)) {
        return '<function ' + v.name + '>';
      }
      break;
    case 'fn':
      // 函数定义：捕获当前环境，存入变量
      ev = jfn(v.value, env);
      if (v.name) {
        jupdate(v.name, ev, env);
      }
      break;
    case 'call':
      // 函数调用：查找函数，传入参数求值
      ev = jcall(jlook(v.name, env), v.args, env);
      break;
    case 'if':
      // 条件：null 为假，非 null 为真
      ev = jif(v.cond, v.then, v.else, env);
      break;
    case 'while':
      // 循环：条件为真时重复执行
      ev = jloop(v.cond, v.body, env);
      break;
    default:
      ev = null;
      break;
  }
  return ev;
}

function jlook(key, env) {
  let e = env;
  let r = undefined;
  while (r === undefined && e !== undefined) {
    r = e[key];
    if (r === undefined) e = e.__parent;  // 找不到才向父环境找
  }
  return r;
}

function jupdate(key, val, env) {
  let e = env;
  let r = undefined;
  while (r === undefined && e !== undefined) {
    r = e[key];
    if (r === undefined) e = e.__parent;  // 找到了就不再上移
  }
  if (e === undefined) e = env;  // 找不到就在当前环境创建
  e[key] = val;
  return val;
}

function jfn(v, env) {
  let f = {};
  f.env = { __parent: env };  // 捕获定义时的环境
  f.args = v.args;
  f.body = v.body;
  return f;
}

function jcall(f, args, env) {
  let e = { __parent: f.env };  // 新环境链到函数定义时捕获的环境
  for (let i = 0; i < f.args.length; ++i) {
    e[f.args[i]] = jeval(args[i], env);  // 参数在调用环境中求值
  }
  let ret = null;
  for (let i = 0; i < f.body.length; ++i) {
    ret = jeval(f.body[i], e);  // 函数体在新环境中执行
  }
  return ret;
}

function jif(cond, thenExpr, elseExpr, env) {
  let c = jeval(cond, env);
  let branch = (c === null) ? elseExpr : thenExpr;
  let ret = null;
  for (let i = 0; i < branch.length; ++i) {
    ret = jeval(branch[i], env);
  }
  return ret;
}

function jloop(cond, body, env) {
  let r = null;
  while (jeval(cond, env) !== null) {
    for (let i = 0; i < body.length; ++i) {
      r = jeval(body[i], env);
    }
  }
  return r;
}

function jadd(args, env) {
  let r = 0;
  for (let i = 0; i < args.length; ++i) {
    r = r + jeval(args[i], env);
  }
  return r;
}

function jsub(args, env) {
  if (args.length === 1) {
    return -(jeval(args[0], env));
  }
  let r = jeval(args[0], env);
  for (let i = 1; i < args.length; ++i) {
    r = r - jeval(args[i], env);
  }
  return r;
}

function jmul(args, env) {
  let r = 1;
  for (let i = 0; i < args.length; ++i) {
    r = r * jeval(args[i], env);
  }
  return r;
}

function jdiv(args, env) {
  if (args.length === 1) {
    return 1 / jeval(args[0], env);
  }
  let r = jeval(args[0], env);
  for (let i = 1; i < args.length; ++i) {
    r = r / jeval(args[i], env);
  }
  return r;
}

function jlt(args, env) {
  let m = jeval(args[0], env);
  for (let i = 1; i < args.length; ++i) {
    let n = jeval(args[i], env);
    if (!(m < n)) return null;
    m = n;
  }
  return 'true';
}

function jgt(args, env) {
  let m = jeval(args[0], env);
  for (let i = 1; i < args.length; ++i) {
    let n = jeval(args[i], env);
    if (!(m > n)) return null;
    m = n;
  }
  return 'true';
}

function jand(args, env) {
  let c = jeval(args[0], env);
  for (let i = 1; i < args.length && c !== null; ++i) {
    c = jeval(args[i], env);
  }
  return c;
}

function jor(args, env) {
  let c = jeval(args[0], env);
  for (let i = 1; i < args.length && c === null; ++i) {
    c = jeval(args[i], env);
  }
  return c;
}

function jnot(args, env) {
  return (jeval(args[0], env) === null) ? 'true' : null;
}

// 以下代码会覆盖前面的 jeval 定义，补充算术和逻辑运算的 case
function jeval(v, env) {
  if (v === null || typeof v !== 'object' || v instanceof Array) {
    return v;
  }

  let ev = null;
  switch (v.type) {
    case 'num':
    case 'str':
    case 'vec':
      ev = jeval(v.value, env);
      if (v.name) {
        jupdate(v.name, ev, env);
      }
      break;
    case 'var':
      ev = jlook(v.name, env);
      if (typeof ev === 'object' && ev !== null && !(ev instanceof Array)) {
        return '<function ' + v.name + '>';
      }
      break;
    case 'fn':
      ev = jfn(v.value, env);
      if (v.name) {
        jupdate(v.name, ev, env);
      }
      break;
    case 'call':
      ev = jcall(jlook(v.name, env), v.args, env);
      break;
    case 'if':
      ev = jif(v.cond, v.then, v.else, env);
      break;
    case 'while':
      ev = jloop(v.cond, v.body, env);
      break;
    case 'add':
      ev = jadd(v.args, env);
      break;
    case 'sub':
      ev = jsub(v.args, env);
      break;
    case 'mul':
      ev = jmul(v.args, env);
      break;
    case 'div':
      ev = jdiv(v.args, env);
      break;
    case 'lt':
      ev = jlt(v.args, env);
      break;
    case 'gt':
      ev = jgt(v.args, env);
      break;
    case 'and':
      ev = jand(v.args, env);
      break;
    case 'or':
      ev = jor(v.args, env);
      break;
    case 'not':
      ev = jnot(v.args, env);
      break;
    default:
      ev = null;
      break;
  }
  return ev;
}

console.log("(1+2)*3 - 4/2 =", interpreter([{ type: 'sub', args: [
  { type: 'mul', args: [{ type: 'add', args: [1, 2] }, 3] },
  { type: 'div', args: [4, 2] }
]}], {}));

// 比较运算
console.log("1<2<3 =", interpreter([{ type: 'lt', args: [1, 2, 3] }], {}));
console.log("1<3<2 =", interpreter([{ type: 'lt', args: [1, 3, 2] }], {}));
console.log("3>2>1 =", interpreter([{ type: 'gt', args: [3, 2, 1] }], {}));

// 逻辑运算
console.log("and(1,2,3) =", interpreter([{ type: 'and', args: [1, 2, 3] }], {}));
console.log("and(1,null,3) =", interpreter([{ type: 'and', args: [1, null, 3] }], {}));
console.log("or(null,null,42) =", interpreter([{ type: 'or', args: [null, null, 42] }], {}));
console.log("not(null) =", interpreter([{ type: 'not', args: [null] }], {}));
console.log("not(1) =", interpreter([{ type: 'not', args: [1] }], {}));

// 条件
console.log("if(null) =", interpreter([
  { type: 'if', cond: null,
    then: [{ type: 'str', value: 'yes' }],
    else: [{ type: 'str', value: 'no' }] }
], {}));
console.log("if(gt(42,0)) =", interpreter([
  { type: 'if', cond: { type: 'gt', args: [42, 0] },
    then: [{ type: 'str', value: 'positive' }],
    else: [{ type: 'str', value: 'non-positive' }] }
], {}));

// 累加 1+2+...+5
let sumExample = [
  { type: 'num', name: 'i', value: 0 },
  { type: 'num', name: 'n', value: 5 },
  { type: 'num', name: 'sum', value: 0 },
  { type: 'while',
    cond: { type: 'lt', args: [{ type: 'var', name: 'i' }, { type: 'var', name: 'n' }] },
    body: [
      { type: 'num', name: 'i', value: { type: 'add', args: [{ type: 'var', name: 'i' }, 1] } },
      { type: 'num', name: 'sum', value: { type: 'add', args: [{ type: 'var', name: 'sum' }, { type: 'var', name: 'i' }] } },
    ]
  },
  { type: 'var', name: 'sum' }
];
console.log("1+2+...+5 =", interpreter(sumExample, {}));

// 阶乘 fact(5) = 120
let factExample = [
  { type: 'fn', name: 'fact',
    value: { args: ['n'],
             body: [
               { type: 'num', name: 'result', value: 1 },
               { type: 'while',
                 cond: { type: 'gt', args: [{ type: 'var', name: 'n' }, 0] },
                 body: [
                   { type: 'num', name: 'result',
                     value: { type: 'mul', args: [{ type: 'var', name: 'result' }, { type: 'var', name: 'n' }] } },
                   { type: 'num', name: 'n',
                     value: { type: 'sub', args: [{ type: 'var', name: 'n' }, 1] } },
                 ]
               },
               { type: 'var', name: 'result' }
             ]
           }
  },
  { type: 'call', name: 'fact', args: [5] },
];
console.log("fact(5) =", interpreter(factExample, {}));

// 字符串 + 数组
console.log(interpreter([
  { type: 'str', name: 'msg', value: 'Hello World!' },
  { type: 'fn', name: 'greet', value: { args: [], body: [{ type: 'var', name: 'msg' }] } },
  { type: 'call', name: 'greet', args: [] },
], {}));
console.log(interpreter([
  { type: 'vec', name: 'xs', value: [1, 2, 3] },
  { type: 'var', name: 'xs' }
], {}));
