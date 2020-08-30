module universal.core.coproduct;

@("EXAMPLES") unittest
{
	import std.stdio;
	import std.exception;

	auto u1 = Union!(
		q{a}, int,
		q{b}, int,
	)();

	/*
		default initializes to first constructor
	*/
	assert(u1.a == 0);

	/*
		accessing uninhabited ctor asserts
	*/
	assertThrown!Error(u1.b);

	/*
		capable of builder-like syntax
	*/
	auto u2 = typeof(u1)().a(100);
	assert(u2.a == 100);

	/*
		the inhabited ctor is conveniently checkable
	*/
	assert(u2.isCase!q{a});
	assert(! u2.isCase!q{b});
	/*
		note: the checked ctor must be a member of the union
	*/
	assert(!__traits(compiles, u2.isCase!q{none}));

	/*
		unions are writable in-place
	*/
	u1.b = 9;
	assertThrown!Error(u1.a);
	assert(u1.b == 9);

	/*
		so beware of accidental assignment
	*/
	auto u3 = u1.a(7);
	assert(u3.a == 7);
	assert(u1.a == 7);

	/*
		unions without named fields identify their injections by a numerical index.
	*/
	auto u4 = Union!(int, int, string)();
	u4.inj!0(2);
	assert(u4.isCase!0);
	u4.inj!2("hello");
	assert(u4.isCase!2);

	/*
		the generic universal coproduct function, visit
	*/
	assert(u1.visit!(
		q{a}, a => 100 * a,
		q{b}, b => 0,
	) == 700);

	/*
		unions can be visited without naming fields, in this case functions are matched to injections by declaration order
	*/
	assert(u4.visit!(
		a => 100 * a,
		a => 50 * a,
		a => 0,
	) == 0);

	/*
		for expressiveness and type safety, custom unions are easy to build
		using the Definition mixin also enables recursive data types
			note: this example is a class for expository purposes
			we could have just as easily done this with a struct and its pointer
	*/
	static class List(A) { mixin UnionInstance!(q{nil}, q{cons}, A, List); }

	/*
		functions over unions can then be declared as recursive aliases
	*/
	alias sum = visit!(
		q{nil},  () => 0,
		q{cons}, (y,ys) => y + sum(ys)
	);

	/*
		for convenience, we define helper ctors (generally a good practice in D)
	*/
	List!int nil() { return new List!int().nil; }
	List!int cons(int x, List!int xs) { return new List!int().cons(x, xs); }

	assert(sum(nil) == 0);
	assert(sum(cons(42, nil)) == 42);
	assert(sum(cons(1, cons(5, cons(7, nil)))) == 13);

	/*
		unions can also represent classification results
	*/
	with(
		2.classify!(
			q{odd}, a => a % 2,
			q{even}, _=> true,
		)
	) assert(even);

	with(
		3.classify!(
			q{odd}, a => a % 2,
			q{even}, _=> true,
		)
	) assert(odd);
}

/*
	This module implements the coproduct of normalized D types, here called Union, also known as disjoint union, tagged union, sum type, variant, Algebraic, or ADT.

	A Union is basically a portable switch. Whereas Tuple contains several values at once, Union contains one value of several possible values.

	This pattern is simple, useful, and commonplace. D doesn't quite support them out-of-the-box, though. There's the union keyword, which behaves like C's union, but it's only really useful when combined with a tag denoting which of the possible fields is actually inhabited. There's a std.variant module implementing this pattern, but it doesn't meet my needs for a number of reasons, which mainly revolve around expressiveness and introspective reasoning.

	Expressiveness is important for unions for the same reason it's important for tuples - if you use them at all, you use them a lot. And unions pair well with tuples - with the former, you encapsulate "possibility" (specifically, a branch in your program), and with the latter, "multiplicity". Between the two, they can comfortably and concisely express a lot of ideas, and their simplicity (when taken individually) allows them to compose well.

	In D, tuples are already a little awkward to use. I try to address that in the core.product module. I wanted to do the same for unions, but found that I couldn't really just add on top of Algebraic the way I did with Tuple. I want (1) unions to be as expressive as tuples, and (2) uniform expressive power with all functions involving unions and tuples.

	First, to put "expressiveness" of a "pattern" on some solid ground, let's call it the number of instances of the template encapsulating that pattern.

	In order to achieve goal (2), this implementation is based on the categorical product and coproduct. The definitions are the most minimal and generic definitions for these patterns, and so it stands to reason that, if uniform expressiveness is achieved throughout the definition, it can probably be extended to every other thing you could possibly do with it.

	Tuple is an instance of a product while Algebraic and Union are coproducts. Products and corproducts are duals, which is probably why they pair so well together. The practical upshot of this is that they have a lot of inherent symmetries, and symmetries can be exploited to save work, complexity, and lines of code.

	Looking at the diagrams in the definitions for product and coproduct on wikipedia, you can make the following identifications:
		In both diagrams, X₁,X₂,... identify the template parameters to Tuple or Algebraic.
		For the coproduct, the canonical injections are the constructors of Algebraic. f is visit, and f₁,f₂,... are the arguments to visit.
		For the product, the canonical projections are indexing each of the tuple elements, f is adjoin, and f₁,f₂,... are the arguments to adjoin.

	Again, the goal is to make those identifications to be equal in expressiveness. So, how expressive is Tuple?
	There's one type of tuple for every possible list of types, at least. But in Phobos, tuples can have named fields, which are essentially aliasing the canonical projections. While otherwise identical tuples with different field names are practically isomorphic in D in many contexts, they do still represent a different type. So the tuple's expressiveness is equal to the number of lists of types, multiplied by every possible assignment of field names to the elements of those lists.

	The templates Tuple and tuple can both be supplied named fields. But adjoin can't, and so there are less instances of adjoin than there are of tuple or Tuple. It falls short of its potential expressiveness. This is the reason for reimplementing it in core.product.

	Algebraic also doesn't take field names, and so is immediately less expressive than Tuple. In addition, visit matches on types, and does not accept two functions with the same domain. This means that Algebraic's expressiveness is equal to the number of lists of types without repetition. Still infinite, but far less than Tuple.

	So, if I were to lean heavily on Algebraic to be the union in a tuple/union combo, I wouldn't be able to propagate field name information, which hampers the scope of application for traits-based interfaces.  In the case of something like known in advance to be important, like ".length" in range, the definition is propagated from the top down. But take, say, a range representing some signal sampled in time, which has a "frequency" property. You may want to pass it through stride to perform some rough resampling, but you will lose frequency information. To handle cases like this, you either need some uniformity, an incredibly complex introspection mechanism, or to resign yourself to writing boilerplate.

	Algebraic also can't naturally support recursive data types; it uses This, a special symbol defined which signals to the implementation of Algebraic to replace it, during compilation, with typeof(this). It's not that big of a deal, but it adds a little extra weight and, if the union is implemented a different way, it is unnecessary.

	To put achieve goal (1), visit's matching behavior is completely different. For unions with unnamed fields, Union!(X1,X2...), each X represents a different case, even if some Xi == Xj. visit!(f1,f2,...) then matches f1 to case X1, and so on.
	Out-of-order matching is also possible. Unions can be given field names, which act as canonical injections when being set, and assert inhabitance upon being read. Each function argument of visit can be preceded by the injection's name, and this will override the index-based matching.
	Total Union expressiveness is the number of lists of any types, multiplied by every assignment of field names. Equal to the tuple.

	For convenience, if the fields are named, they act as delimeters for the types, meaning that n-ary injections (and by extension, cases) can be defined without repeating Tuple over and over (and then relying on the normalization system).

	To enable natural recursive data type definitions (as well as uniquely typed unions), the Union definition is available as a mixin template, UnionInstance. The custom union type (or its pointer type) can be passed as a type argument as though it were defined directly in the custom type. Functions meant to operate on unions will also operate on the custom union, while preserving its type and field names when applicable.

	PS. I think that the main reason Algebraic falls short of my needs is because it is conflating two processes that I need separated: matching functions to arguments, and representing a union type. The latter is accomplished here, while the former is accomplished in core.match.

*/
template Union(ctors...)
{
	struct Union { mixin UnionInstance!ctors; }
}
mixin template UnionInstance(ctors...)
{
	union { mixin(Union.CodeGen.declUnion); }
	ubyte tag;

	mixin(Union.CodeGen.declInjections);

	static if(is(typeof(this) == struct))
		string toString() { return Union.toString(this); }
	static if(is(typeof(this) == class))
		override string toString() { return Union.toString(this); }

	static struct Union
	{
		import std.meta;
		import universal.meta;
		import std.typetuple;
		import std.typecons;
		import std.range;
		import universal.core.product;
		import universal.core.apply;
		import std.conv : text;
		import std.format : format;

		static:

		alias ctorNames = Filter!(isString, ctors);
		enum width = ctorNames.length > 0? ctorNames.length : ctors.length;

		template Args(uint i)
		{
			static if(ctorNames.length > 0)
			{
				enum idx(uint i) = staticIndexOf!(ctorNames[i], ctors);

				static if(i == ctorNames.length-1)
					alias Args = ctors[ idx!i +1 .. $         ];
				else
					alias Args = ctors[ idx!i +1 .. idx!(i+1) ];
			}
			else
			{
				alias Args = ctors[i];

			}
		}
		alias InArg(uint i) = Tuple!(Args!i);
		alias OutArg(uint i) = Universal!(Args!i);

		template inj(uint i)
		{
			template inj(U) if(is(U.Union == Union))
			{
				auto ref U inj(auto ref U u, Args!i a)
				{
					mixin(text(q{u._}, i)) 
					= Tuple!(Args!i)(a);

					u.tag = i;

					return u;
				}
			}
		}
		template invInj(uint i)
		{
			template invInj(U) if(is(U.Union == Union))
			{
        string errMsg(uint j)
        {
          static if(ctorNames.length > 0)
            return format(
              "%s accessed %s while inhabited by %s",
              U.stringof, ctorNames[i], [ctorNames][j], 
            );
          else
            return format(
              "%s accessed case %d while inhabited by case %d",
              U.stringof, i, j
            );
        }

				auto ref OutArg!i invInj(auto ref U u) 
        in{ assert(u.tag == i, errMsg(u.tag)); }body
				{ return mixin(text(q{u._}, i))[].identity; }
			}
		}

		static string toString(U)(auto ref U u)
		if(is(U.Union == Union))
		{
			static if(ctorNames.length > 0)
				auto header = text(
					ctorNames.only[u.tag], ": ",
				);
			else
				enum header = "";
			
			return text(header, u.ulift!text); 
		}

		struct CodeGen
		{
            import std.range: iota;

			enum declUnion = declare!unionDecl;
			enum declInjections = declare!injectionDecl;

			enum declare(alias decl) = [staticMap!(decl, aliasSeqOf!(Union.width.iota))].join("\n");

			static unionDecl(uint i)()
			{
				return format(q{
					Union.InArg!%d _%d;
				}, i, i);
			}
			static injectionDecl(uint i)()
			{
				static if(ctorNames.length > 0)
					enum name = ctorNames[i];
				else
					enum name = format(q{inj(uint i : %d)}, i);

				auto injection = format(q{
					typeof(this) %s(Union.Args!%d args)
					{ return Union.inj!%d(this, args); }
				}, name, i, i);

				auto inverse = format(q{
					Union.OutArg!%d %s()
					{ return Union.invInj!%d(this); }
				}, i, name, i);

				return [ // avoid ambiguous setter definition for nullary ctors
					injection,
					InArg!i.length == 0 || is(OutArg!i == Unit)? 
						"" : inverse
				].join("\n");
			}
		}
	}
}

/*
	Canonical injection function. For structs, injection constructs a new value. For class types, it operates in place. For in-place injection on some struct `x`, use `x.inj!i`.
*/
template inject(uint i)
{
	template inject(U, A...) if(is(U.Union))
	{
		U inject(U u, A a)
		{ return U.Union.inj!i(U(), a); }
	}
}

/*
	Universal property function. Takes a set of functions and applies the one which matches the inhabited value of the union. If the arguments to `visit` are interleaved with strings, the matching is performed against the union's field names. Otherwise, the functions are matched to injections by the order of their respective declarations (NOT by type as is the case with `std.variant.visit`).
*/
template visit(dtors...)
{
  import std.typetuple;
  import std.typecons;
  import universal.meta;
  import universal.core.apply;
  import std.range;

  alias dtorNames = Filter!(isString, dtors);
  alias dtorFuncs = Filter!(isParameterized, dtors);

	template visit(U, A...) if(is(U.Union))
	{
		auto visit(U u, A args)
		{
			with(U.Union)
			foreach(i; aliasSeqOf!(width.iota))
				if(i == u.tag)
				{
					static if(dtorNames.length > 0)
						enum j = staticIndexOf!(ctorNames[i], dtorNames);
					else
						enum j = i;

					static assert(size_t(j) < width, format(
						"couldn't find %s among %s",
						ctorNames[i], [dtorNames].join(", ")
					));

					return U.Union.invInj!i(u).apply!(dtorFuncs[j])(args);
				}

			assert(0);
		}
	}
}

/*
	Classifies a value according to the first given predicate which it matches.
	The classification is represented by a union inhabited by the injection associated (either by name or declaration order) with the predicate that it passed.
	Strings can be intereleaved in the predicates to name the fields of the tuple. 
	If the value cannot be classified, an assertion is thrown. To define a default classification which cannot fail, return true from the last predicate.
*/
template classify(preds...)
{
  import std.typetuple;
  import universal.meta;
  import universal.core.apply;

  alias predNames = Filter!(isString, preds);
  alias predFuncs = Filter!(isParameterized, preds);

	template classify(A...)
	{
		alias U = Union!(DeclSpecs!(
			predNames, Repeat!(predFuncs.length, Universal!A)
		));

		U classify(A args)
		{
			U u;

			foreach(i, pred; predFuncs)
				if(pred(args))
					return u.inject!i(args);

			assert(0, "no predicates match");
		}
	}
}

/*
	Returns true if the union is inhavited by the specified injection. If the injection is identified by a number, this refers to its order of declaration in the union. Otherwise the injection can be identified by name.
*/
template isCase(uint ctor)
{
	template isCase(U) if(is(U.Union))
	{
		enum i = ctor;

		bool isCase(U u) { return u.tag == i; }
	}
}
template isCase(string ctor)
{
	import std.meta;
	import std.range;
	import std.algorithm.searching;
	import std.typecons;

	template isCase(U) if(is(U.Union) && is(typeof((){ static assert(U.Union.ctorNames.length > 0); })))
	{
		enum i = [U.Union.ctorNames].countUntil!(name => name == ctor);
		static assert(i > -1, ctor~" is not a case of "~[U.Union.ctorNames].stringof);

		bool isCase(U u) { return u.tag == i; }
	}
}

/*
	Applies a function (more likely a template) to whichever value inhabits the union.
	This helper function is useful for meta things, like diagnostic printing.
*/
template ulift(alias f)
{
  import universal.meta;
  import std.meta;

  template ulift(U, A...) if(is(U.Union))
  {
    auto ulift(U u, A a)
    { return u.visit!(Repeat!(U.Union.width, f))(a); }
  }
}
