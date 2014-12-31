module optional;


import std.traits : Unqual;


struct Optional(T)
{
	private
	{
		static if (!is(typeof({T t;})) && !is(typeof(T.init == T)))
		{
			ubyte[T.sizeof] _storage;

			@property ref Unqual!T _payload() inout @trusted
			{
				return *cast(Unqual!T*) _storage.ptr;
			}
		}
		else
		{
			T _payload;
		}

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

	void opAssign(T val)
	{
		static if (is(T : Object))
			_empty = val is null;
		else
			_empty = false;

		_payload = val;
	}

	inout(T) get() inout
	{
		assert(!_empty, "empty Optional");
		return _payload;
	}

	inout(T) getOrElse(lazy inout(T) defaultValue) inout
	{
		return _empty ? defaultValue : _payload;
	}

	static if(is(typeof({T t = null;})))
	{
		inout(T) orNull() inout
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
@safe pure nothrow @nogc
unittest
{
	Optional!string val = "foo";
	assert(!val.empty);
	assert(val.get() == "foo");

	import std.range : isInputRange, hasLength;
	static assert(isInputRange!(Optional!int));
	static assert(hasLength!(Optional!int));

	assert(val.length == 1);
	assert(val.front == "foo");
	foreach (i; val) { assert(i == "foo"); }

	import std.range : only;
	import std.algorithm : equal;
	assert(equal(val, only("foo")));

	val.popFront();
	assert(val.length == 0);
	foreach (i; val) assert(false);
}

@safe pure nothrow
unittest
{
	Optional!Object obj;

	obj = null;
	assert(obj.empty);

	obj = new Object;
	assert(!obj.empty);
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

