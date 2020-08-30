module universal.extras.enums;

import std.typetuple;
import std.traits;
import universal.core.product;
import universal.core.coproduct;

/*
	for working with enums
*/

/*
	turn an enum instance into a union, whose field names follow the enum identifiers.
*/
template enumUnion(N) if(is(N == enum))
{
	alias Ns = EnumMembers!N; 
	alias U = Union!(enumDecls!N);

	U enumUnion(N a) 
	{
		foreach(i, b; Ns)
			if(a == b)
				return U().inject!i(a);

		assert(0);
	}
}

/*
	interleaves the names of enums with the type of the enum, repeated
*/
template enumDecls(N)
{
  import std.range: iota;
  import std.meta: aliasSeqOf;

  alias enumDecls = staticMap!(enumDecl, aliasSeqOf!(Ns.length.iota));

  alias Ns = EnumMembers!N; 
  alias enumDecl(uint i) = TypeTuple!(__traits(identifier, Ns[i]), N);
}
