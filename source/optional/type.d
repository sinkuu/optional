module optional.type;


import std.traits;


/// Represents 'optional' value.
struct Optional(T)
{
	private
	{
		T _payload = void;
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
	static if (isMutable!T)
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
	@property inout(T) get() inout
	{
		assert(!_empty, "empty Optional");
		return _payload;
	}

	///
	inout(T) getOrElse(lazy inout(T) defaultValue) inout
	{
		return _empty ? defaultValue : _payload;
	}

	static if(isImplicitlyConvertible!(typeof(null), T))
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
		_empty = true;
	}

	///
	@property bool empty() const
	{
		return _empty;
	}

	///
	alias front = get;
	///
	alias back = get;
	///
	alias popFront = nullify;
	///
	alias popBack = nullify;

	///
	@property size_t length() const
	{
		return _empty ? 0 : 1;
	}

	///
	alias opDollar = length;

	///
	inout(T) opIndex(size_t n) inout
	{
		assert(!empty, "empty Optional");
		assert(n == 0);

		return _payload;
	}

	///
	@property auto save()
	{
		return this;
	}

	/**
	Casts to boolean.

	Returns:
		true if Optional is not empty.
	*/
	bool opCast(T : bool)() const
	{
		return !_empty;
	}

	///
	unittest
	{
		// can be used to determine whether it's empty in if-statement.

		Optional!int opt;
		if (opt)
		{
			assert(!opt.empty);
		}
		else
		{
			assert(opt.empty);
		}
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

	Optional!(const(Object)) cobj;
}

unittest
{
	static struct S
	{
		int x;

		@disable this();
		@disable @property static S init();

		this(int num)
		{
			x = num;
		}

		this(string s)
		{
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

	Optional!(immutable Obj) obji = new immutable Obj(0);
	static assert(!__traits(compiles, obji.get.x = 100));
}

unittest
{
	import std.range;

	Optional!int num;
	static assert(isInputRange!(typeof(num)));
	static assert(isBidirectionalRange!(typeof(num)));
	static assert(isRandomAccessRange!(typeof(num)));
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

