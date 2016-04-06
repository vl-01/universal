module universal.extras.maybe;

import universal.meta;
import universal.core.coproduct;
import universal.core.product;
import universal.core.apply;
import std.traits;
import std.typetuple;
import std.typecons: staticIota;

/*
	a type which may or may not be inhabited
*/
struct Maybe(A)
{
  mixin UnionInstance!(
    q{nothing},
    q{just}, A,
  );
}
alias Maybe(A : void) = Maybe!(Unit);

Maybe!A just(A)(A a) { return Maybe!A().just(a); }
Maybe!A nothing(A)() { return Maybe!A().nothing; }

auto isNothing(A)(Maybe!A ma) { return ma.isCase!q{nothing}; }
auto isJust   (A)(Maybe!A ma) { return ma.isCase!q{just};    }

/*
	apply f to a Maybe if it is inhabited, otherwise return a default value.
	If f returns void, unit is returned regardless
*/
template maybe(alias f) 
{
  template maybe(A, B = typeof(A.init.apply!f))
	{
		B maybe(Maybe!A m, B b = B.init)
		{
			return m.visit!(
				q{just},    (a,_) => a.apply!f,
				q{nothing}, (b) => b,
			)(b);
		}
	}
}

/*
	fmap
*/
template maybeMap(alias f)
{
	template maybeMap(A)
	{
		alias B = typeof(A.init.apply!f);

		Maybe!B maybeMap(Maybe!A m)
		{
			if(m.isJust)
				return just(f(m.just));
			else
				return nothing!B;
		}
	}
}

/*
	like visit, but not all cases need to be accounted for. Requires named fields. If one of the supplied function matches the inhabited union, it returns wrapped in "just". If none match, it returns "nothing".
*/
template maybeVisit(dtors...)
{
  auto maybeVisit(U)(U u)
  if(is(U.Union))
  {
    alias dtorNames = Filter!(isString, dtors);
    alias dtorFuncs = Filter!(isParameterized, dtors);

    enum ctorIdx(string name) = staticIndexOf!(name, U.Union.ctorNames);
    enum dtorIdx(string name) = staticIndexOf!(name, dtorNames);

    alias DtorCod(string name)
    = typeof(dtorFuncs[dtorIdx!name](U.Union.Args!(ctorIdx!name).init));

    alias B = Universal!(CommonType!(staticMap!(DtorCod, dtorNames)));

    template doVisit(string name)
    {
      enum i = dtorIdx!name;
      enum j = ctorIdx!name;

      static if(i > -1)
        auto doVisit(U.Union.Args!j a)
        { return a.apply!(dtorFuncs[i]).apply!(just!B); }
      else
        auto doVisit(U.Union.Args!j)   
        { return nothing!B; }

    }

    return u.visit!(staticMap!(doVisit, U.Union.ctorNames));
  }
}

@("EXAMPLES") unittest
{
	Union!("a", int, "b", int) u;
	u.b = 3;

	auto m = u.maybeVisit!(q{a}, a => a);
	assert(m.isNothing);

	m = u.maybeVisit!(q{b}, b => b);
	assert(m == just(3));
}
