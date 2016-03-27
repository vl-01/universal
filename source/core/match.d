module universal.core.match;

import std.typetuple;
import std.typecons;
import std.functional;
import universal.meta;
import universal.core.product;
import universal.core.apply;

alias adjoin = universal.core.product.adjoin;
enum isFuncOrString(alias a) = isString!a || isParameterized!a;

/*
	This module provides 3 ways to do compile-time pattern matching on a set of arguments.
	It can function like an explicit overload set defined at the point of application
		with a few extra capabilities.

	These template functions take a compile-time list of function-like aliases (patterns)
		and attempt to apply them to the run-time arguments.

	matchOne resolves to the first pattern which compiles
	matchAny resolves to a tuple containing all patterns which compile
	canMatch resolves to a tuple containing bools stating whether each pattern compiled

	they lift the pattern with universal.apply before attempting to apply the arguments,
		so a pattern that tests true for a given set of arguments
		may require that the first argument be expanded, if its a tuple

	in matchAny and canMatch, the patterns maybe be interleaved with strings,
		resulting in the returned tuple having named fields
	canMatch can be used in this way to implement a concise, anonymous trait check

*/

template matchOne(patterns...) if(allSatisfy!(isParameterized, patterns))
{
	template matchOne(A...)
	{
		template tryPattern(uint i = 0)
		{
			static if(__traits(compiles, apply!(patterns[i])(A.init)))
				alias tryPattern = apply!(patterns[i]);
			else
				alias tryPattern = tryPattern!(i+1);
		}
		template tryPattern(uint i : patterns.length)
		{
			static assert(0,
				"couldn't match "~A.stringof
				~" to any "~patterns.stringof
			);
		}
		auto matchOne(A a) { return tryPattern(a); }
	}
}
template matchAny(patterns...) if(allSatisfy!(isFuncOrString, patterns))
{
	template matchAny(A...)
	{
		alias names = Filter!(isString, patterns);
		alias funcs = Filter!(isParameterized, patterns);

		template tryPattern(uint i)
		{
			static if(__traits(compiles, apply!(funcs[i])(A.init)))
			{
				auto pattern(A a) { return a.apply!(funcs[i]); }

				static if(names.length == funcs.length)
					alias tryPattern = TypeTuple!(names[i], pattern);
				else
					alias tryPattern = pattern;
			}
			else
				alias tryPattern = TypeTuple!();
		}
		auto matchAny(A a)
		{
			return a.adjoin!(staticMap!(
				tryPattern, staticIota!(0, patterns.length)
			));
		}
	}
}
template canMatch(patterns...) if(allSatisfy!(isFuncOrString, patterns))
{
	template canMatch(A...)
	{
		alias names = Filter!(isString, patterns);
		alias funcs = Filter!(isParameterized, patterns);

		template tryPattern(uint i)
		{
			static if(__traits(compiles, apply!(funcs[i])(A.init)))
				enum tryPattern = true;
			else
				enum tryPattern = false;
		}

		auto canMatch(A a)
		{
			return tuple!names(staticMap!(
				tryPattern, staticIota!(0, funcs.length)
			));
		}
	}
}

@("EXAMPLES") unittest
{
	assert(
		1.matchOne!(
			s => s.length,
			s => s * 3,
			s => s + 1,
		) == 3
	);

	assert(
		1.matchAny!(
			s => s.length,
			s => s * 3,
			s => s + 1,
		) == _t(3,2)
	);
	
	with(
		1.matchAny!(
			q{len}, s => s.length,
			q{mul}, s => s * 3,
			q{add}, s => s + 1,
		)
	)
		assert(
			!is(typeof(len))
			&& mul == 3
			&& add == 2
		);

	assert(
		"hi".canMatch!(
			q{len}, s => s.length,
			q{mul}, s => s * 3,
			q{add}, s => s + 1,
		) == _t(true, false, false)
	);

	with(
		"hi".canMatch!(
			q{len}, s => s.length,
			q{mul}, s => s * 3,
			q{add}, s => s + 1,
		)
	)
		assert(len && !(mul) && !(add));
}
