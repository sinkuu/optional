module optional;


import std.traits : Unqual;


///
struct Optional(T)
{
	private
	{
		Unqual!T _payload = void;
		bool _empty = true;

	}

	this(inout(T) val) inout
	{
		static if (is(T : Object))
			_empty = val is null;
		else
			_empty = false;

		_payload = val;
	}

	///
	void opAssign(T val)
	{
		static if (is(T : Object))
			_empty = val is null;
		else
			_empty = false;

		import std.conv : emplace;
		emplace(&_payload, val);
	}

	/**
		Gets the value.

		Precondition: $(D_CODE !empty)
	*/
	inout(T) get() inout
	{
		assert(!_empty, "empty Optional");
		return _payload;
	}

	///
	inout(T) getOrElse(lazy inout(T) defaultValue) inout
	{
		return _empty ? defaultValue : _payload;
	}

	static if(is(typeof({T t = null;})))
	{
		/// Returns value if available, or returns null if not. Only available for nullable types.
		inout(T) orNull() inout
		{
			return _empty ? null : _payload;
		}
	}

	///
	void nullify()
	{
		assert(!_empty, "empty Optional");
		_empty = true;
	}

	///
	@property bool empty() const
	{
		return _empty;
	}

	alias front = get;

	alias popFront = nullify;

	///
	@property size_t length() const
	{
		return _empty ? 0 : 1;
	}

	///
	bool opCast(T : bool)() const
	{
		return !_empty;
	}
}

///
@safe pure
unittest
{
	Optional!string val = "foo";
	assert(!val.empty);
	assert(val.get() == "foo");

	val.nullify();
	assert(val.getOrElse("bar") == "bar");

	// Range interface
	val = "foo";
	assert(val.length == 1);
	assert(val.front == "foo");

	import std.algorithm : equal;
	import std.range : only;
	assert(equal(val, only("foo")));
}

@safe pure nothrow
unittest
{
	Optional!Object obj;

	obj = null;
	assert(obj.empty);
	assert(obj.orNull is null);

	obj = new Object;
	assert(!obj.empty);

	// implicit cast to bool
	if (obj) {}
	else assert(0);
}

@safe pure nothrow @nogc
unittest
{
	static struct S
	{
		int x;

		@disable this();
		@disable @property static S init();

		this(int num) pure @safe nothrow @nogc
		{
			x = num;
		}
	}

	static assert(!__traits(compiles, S()));
	static assert(!__traits(compiles, S.init));

	Optional!S s;
	assert(s.empty);

	s = S(100);
	assert(!s.empty);
	assert(s.get() == S(100));

	immutable ims = s.get();
	assert(ims == S(100));

	s.nullify();
	assert(s.empty);

	Optional!(immutable S) s2 = S(100);
	assert(s2.get == S(100));
}

@safe pure nothrow
unittest
{
	immutable Optional!string str = "foo";
	assert(str.get() == "foo");
	static assert(!__traits(compiles, str = "bar"));

	immutable Optional!(int[]) arr = [1, 2, 3].idup;
	static assert(is(typeof(arr.get()) == immutable int[]));
	assert(arr.get.length == 3);
}

@safe pure nothrow
unittest
{
	class Obj
	{
	@safe pure nothrow @nogc:

		private int _x;

		@property
		{
			void x(int n) { _x = n; }
			int x() const { return _x; }
		}

		this (int x) { _x = x; }
	}

	Optional!Obj objm = new Obj(0);
	objm.get.x = 10;
	assert(objm.get.x == 10);

	auto obj = new Obj(10);
	Optional!Obj objc = obj;
	static assert(!__traits(compiles, obji.get.x = 100));
	assert(objc.get.x == 10);

	immutable obji = new immutable Obj(0);
	static assert(!__traits(compiles, obji.get.x = 100));
}


Optional!T optional(T : Object)(T obj)
{
	return obj is null ? Optional!T() : Optional!T(obj);
}

///
pure @safe nothrow
unittest
{
	assert(!optional(new Object).empty);
	assert(optional(cast(Object)null).empty);
}

Optional!T optional(T)(T val)
{
	return Optional!T(val);
}

Optional!T optional(T)()
{
	return Optional!T();
}

///
pure @safe nothrow @nogc
unittest
{
	assert(!optional(123).empty);
	assert(optional!int().empty);
}


import std.traits : isInstanceOf;
// TODO: better name
auto bind(alias fun, Opt)(Opt opt) if (isInstanceOf!(Optional, Opt))
{
	import std.functional : unaryFun;

	static if (is(typeof(unaryFun!fun) == void))
	{
		alias ufun = unaryFun!fun;
		alias fun_ = ufun!(typeof(opt.get()));
	}
	else
	{
		alias fun_ = unaryFun!fun;
	}

	return opt.empty ?
		Optional!(typeof(fun_(opt.get).get()))() : fun_(opt.get);
}

///
unittest
{
	Optional!int func1(int x)
	{
		return x == 0 ?
			optional!int() : optional(x);
	}

	Optional!int func2(int y)
	{
		return y == 10 ?
			optional!int() : optional(y);
	}

	assert(func1(0) .bind!func2.empty);
	assert(func1(5) .bind!func2.get == 5);
	assert(func1(10).bind!func2.empty);
}

@safe pure nothrow @nogc
unittest
{
	assert(optional(10).bind!(x => optional(x == 10)).get);
}


auto optSwitch(alias existFun, alias emptyFun = {}, T)(Optional!T opt)
{
	import std.functional : unaryFun;

	if (opt.empty)
	{
		return emptyFun();
	}
	else
	{
		return unaryFun!existFun(opt.get());
	}
}

///
pure @safe nothrow @nogc
unittest
{
	Optional!int opt;

	opt.optSwitch!(
		(int x)
		{
			assert(false);
		},
		{
			opt = 100;
		});

	assert(opt.get() == 100);

	opt.optSwitch!(
		(int x)
		{
			assert(x == 100);
		},
		{
			assert(false);
		});

	opt.optSwitch!((x) { assert(x == 100); });
}

