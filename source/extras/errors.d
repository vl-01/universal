module universal.extras.errors;

import universal.core.product;
import universal.core.coproduct;
import universal.core.apply;
import universal.meta;
import std.typetuple;
import std.typecons;
import std.format;
import std.conv;
import std.array;

/*
	For executing code in nothrow, multithreaded, or failsafe contexts
*/

/*
	represents a caught throwable
	a union whose field names are the exception names, with all qualifications removed, in camelCase.
*/

struct Caught(Throwables...)
{
	mixin UnionInstance!(Interleave!(
		staticMap!(simpleName, Throwables)
			.tuple.tlift!toCamelCase[],
		Throwables
	));
}
alias Caught() = Caught!(Error, Exception);

/*
	convenience function on Caughts, useful for rethrowing exceptions passed out of nothrow environments and such
*/
template rethrow(Throwables...)
{
	void rethrow(Caught!Throwables failure)
	{
		failure.visit!( // TODO extend to handle all exceptions
			q{error}, (err) { assert(0, err.text); },
			q{exception}, (ex) { throw ex; }
		);
	}
}

alias Failure = Caught!();

/*
	Represents an operation which may have failed.
*/
struct Result(A, Throwables...)
{
	alias Failure = Caught!Throwables;
	alias Success = A;

	mixin UnionInstance!(
		q{failure}, Failure,
		q{success}, Success,
	);
}
template success(A...)
{
	Result!A success(A a) 
	{ return a.apply!(_ => Result!A().success(_)); }
}
template failure(A...)
{
	Result!A failure(Error err) 
	{ return Result!A().failure(Result!A.Failure().error(err)); }
	Result!A failure(Exception ex) 
	{ return Result!A().failure(Result!A.Failure().exception(ex)); }
}
template isSuccess(A, Throwables...)
{
	bool isSuccess(Result!(A, Throwables) result)
	{ return result.isCase!q{success}; }
}
template isFailure(A, Throwables...)
{
	bool isFailure(Result!(A, Throwables) result)
	{ return result.isCase!q{failure}; }
}
alias Result() = Result!Unit;

/*
	execute a function in a failsafe context
	by default, catches Error and Exception
	This can be overridden as template parameters following the lifted function
*/
template tryCatch(alias f, Throwables...)
{
	template tryCatch(A...)
	{
		alias B = Universal!(typeof(f(A.init)));
		alias R = Result!(B, Throwables);

		string cases()
		{
			template catchCase(uint i)
			{
				enum catchCase = format(q{
					catch(R.Failure.Union.Args!%d[0] thrown)
						return R.init.failure(R.Failure.init.%s(thrown));
				}, i, R.Failure.Union.ctorNames[i]);
			}

			return [
				q{ try return R.init.success(apply!f(args)); },
				staticMap!(catchCase, staticIota!(0, R.Failure.Union.width))
			].join("\n");
		}

		R tryCatch(A args) { mixin(cases); }
	}
}

@("EXAMPLES") unittest
{
	void err() { assert(0); }
	assert(tryCatch!err.isFailure);
	assert(tryCatch!err.failure.isCase!"error");

	void exc() { throw new Exception(""); }
	assert(tryCatch!exc.isFailure);
	assert(tryCatch!exc.failure.isCase!"exception");

	class MyExcept : Exception { this() { super(""); } }

	void exc2() { throw new MyExcept; }
	assert(tryCatch!exc2.failure.isCase!"exception");
	assert(tryCatch!(exc2, MyExcept).failure.isCase!"myExcept");

	int succ(int a) { return a+1; }
	assert(tryCatch!succ(2).success == 3);
}
