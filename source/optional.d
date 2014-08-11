module optional;


import std.traits : Unqual;


struct Optional(T)
{
	private
	{
		void[T.sizeof] _storage;
		bool _empty = true;

		@property ref Unqual!T _payload() const @trusted
		{
			return *cast(Unqual!T*) _storage.ptr;
		}
	}

	this(T val)
	{
		opAssign(val);
	}

	void opAssign(T val)
	{
		static if (is(T : Object))
			_empty = val is null;
		else
			_empty = false;

		_payload = val;
	}

	T get() const
	{
		assert(!_empty, "empty Optional");
		return _payload;
	}

	T getOrElse(lazy T defaultValue) const
	{
		return _empty ? defaultValue : _payload;
	}

	static if(is(T : Object))
	{
		T orNull() const
		{
			return _empty ? null : _payload;
		}
	}

	void nullify()
	{
		assert(!_empty, "empty Optional");
		_empty = true;
		static if (__traits(compiles, T.init)) _payload = T.init;
	}

	@property bool empty() const
	{
		return _empty;
	}

	alias front = get;

	alias popFront = nullify;

	@property size_t length() const
	{
		return _empty ? 0 : 1;
	}
}

///
pure @safe nothrow @nogc
unittest
{
	Optional!string val = "foo";
	assert(!val.empty);
	assert(val.get() == "foo");

	import std.range;
	static assert(isInputRange!(Optional!int));
	static assert(hasLength!(Optional!int));

	assert(val.length == 1);
	assert(val.front == "foo");
	foreach (i; val) { assert(i == "foo"); }

	import std.algorithm : equal;
	assert(equal(val, only("foo")));

	val.popFront();
	assert(val.length == 0);
	foreach (i; val) assert(false);
}

pure @safe nothrow
unittest
{
	Optional!Object obj;

	obj = null;
	assert(obj.empty);

	obj = new Object;
	assert(!obj.empty);
}

pure @safe nothrow @nogc
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

	s.nullify();
	assert(s.empty);

	Optional!(immutable S) s2 = S(100);
}

pure @safe nothrow @nogc
unittest
{
	immutable Optional!string str = "foo";
	assert(str.get() == "foo");
	static assert(!__traits(compiles, str = "bar"));
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

auto optionalSwitch(alias existFun, alias emptyFun = {}, T)(Optional!T opt)
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

	opt.optionalSwitch!(
		(int x)
		{
			assert(false);
		},
		{
			opt = 100;
		});

	assert(opt.get() == 100);

	opt.optionalSwitch!(
		(int x)
		{
			assert(x == 100);
		},
		{
			assert(false);
		});

	opt.optionalSwitch!((x) { assert(x == 100); });
}

