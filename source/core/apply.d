module universal.core.apply;

import std.typecons;

/*
	Transform symbols into a form usable within `universal`.

	The reason that symbols need to be normalized is because D functions don't compose.
		example 1: `void f(){}`: there is no symbol `g` for which either `g(f())` or `f(g())` exists.
		example 2: `auto f(A a, B b)` : there is no symbol `g` for which `f(g())` exists.

	To work around these inconsistencies, the following assumptions are made by the internals of `universal`:
		1) All functions return some value.
		2) Any `tuple(a,b,c)` is alpha-equivalent to its expansion `a,b,c` if it is passed as the first argument to a function.

	Assumption (2) allows us to emulate multiple return values, solving example 2.
	Both assumptions together solve example 1. In fact, `f` itself satisfies `g`.
		
	To support these assumptions, a function `f` is normalized by being lifted through `apply` as a template argument.
	If `f` returns `void`, `apply!f` calls `f` and returns the empty `Tuple!()`, aka `Unit`.
	`apply!f` may transform its arguments before passing them to `f`, either by expanding the first argument into multiple arguments (if it is a tuple) or by packing multiple arguments into a tuple. Preference is given to passing the arguments through untouched.

	As a coincidental convenience, `apply` can be useful for performing a function on a range in a UFCS chain, in which some range-level information is needed (like `$` does for `.length` in the context of `opIndex`).
*/
template apply(alias f, string file = __FILE__, size_t line = __LINE__)
{
  template apply(A...)
  {
		static if(is(typeof(f(A.init)) == B, B))
			enum pass;
		else static if(is(typeof(f(A.init[0][], A.init[1..$])) == B, B))
			enum expand;
		else static if(is(typeof(f(A.init.tuple)) == B, B))
			enum enclose;
		else 
		{
			pragma(msg, typeof(f(A.init)));

			alias B = void;

			static assert(0,
				"couldn't apply "~__traits(identifier, f)~A.stringof
			);
		}

		static if(is(B == void))
			alias C = Unit;
		else
			alias C = B;

		C apply(A a)
		{
			auto applied()
			{
				static if(is(pass))
				{ return f(a); }
				else static if(is(expand))
				{ return f(a[0][], a[1..$]); }
				else static if(is(enclose))
				{ return f(tuple(a)); }
			}

			static if(is(typeof(applied()) == void))
			{ applied; return unit; }
			else
			{ return applied; }
		}
  }
}

/*
	In various places in this library, its more useful to think of the empty tuple, void, and "no parameters" as being the same thing. All of those things are converted to Unit on their way into the system.
*/
alias Unit = Tuple!();
auto unit() { return tuple; }

/*
	Convenience function, equivalent to lifting the identity function through apply, but doesn't waste the extra time attempting various compilations.
*/
auto identity(A)(A a) { return a; }
auto identity(A...)(A a) { return a.tuple; }

/*
	Represents the normalized form of the given types.
*/
alias Universal(A...) = typeof(A.init.identity);
alias Universal(_: void) = Universal!();

@("EXAMPLES") unittest
{
	static int add(int a, int b) { return a + b; }
	assert(apply!add(tuple(1,2)) == apply!add(1,2));

	static void f() {}
	assert(apply!f == unit);

	assert( !__traits(compiles, f(f)));
	assert(__traits(compiles, apply!f(apply!f)));
}
