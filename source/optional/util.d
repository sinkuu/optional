module optional.util;


import optional.type : Optional, optional;

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
		static if (is(typeof(emptyFun) == string))
		{
			return mixin(emptyFun);
		}
		else
		{
			return emptyFun();
		}
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

	// optSwitch can return the result.
	assert(optional!int().optSwitch!(x => x + 10, () => 0) == 0);
}

