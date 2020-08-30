module universal.core.product;

import std.typecons;
import std.typetuple;
import std.conv;
import universal.core.apply;
import universal.meta;

/*
  This module extends std.typecons.Tuple functionality in various ways.
*/


/*
  std.functional.adjoin is reimplemented to support named fields
*/
template adjoin(fields...)
{
  alias fieldNames = Filter!(isString, fields);
  alias funcs = Filter!(isParameterized, fields);

  template adjoin(A...)
  {
    import std.range : iota;

    alias Proj(uint i) = Universal!(typeof(funcs[i](A.init)));
    alias Projs = staticMap!(Proj, aliasSeqOf!(funcs.length.iota));
    alias T = Tuple!(DeclSpecs!(Projs, fieldNames));
      
    T adjoin(A args) 
    {
      auto proj(uint i)() { return apply!(funcs[i])(args); }
      alias projs = staticMap!(proj, aliasSeqOf!(funcs.length.iota));

      return T(projs);
    }
  }
}

////////////////////////////////////////////////////////////////////////////////

/*
  Concatenate tuples, preserving field names
*/
auto tconcat(Tuples...)(Tuples tuples) if(Tuples.length > 1)
{
  return tconcat(
    tuple!(
      Tuples[0].fieldNames,
      Tuples[1].fieldNames
    )(tuples[0][], tuples[1][]),
    tuples[2..$]
  );
}
auto tconcat(Types...)(Tuple!Types baseCase)
{
  return baseCase;
}

/*
  Apply a function (or a template function) to every element of the tuple to produce a new tuple.
*/
template tlift(alias f)
{
  template tlift(A) if(isTuple!A)
  {
    alias B(uint i) = typeof(f(A[i].init));

    static if(text(A.fieldNames) == "")
      alias names = TypeTuple!();
    else
      alias names = A.fieldNames;

    auto tlift(A a)
    {
            import std.range : iota;

      B!i apply(uint i)(A a) { return f(a[i]); }

      return a.adjoin!(
        staticMap!(apply, aliasSeqOf!(A.Types.length.iota)),
        names
      );
    }
  }
}

/*
  Sometimes tuples come up a lot; they can be useful for visually grouping a set of arguments (particularly in UFCS chains).
  In practice, I find this symbol is the best balance of unambiguity and low visual noise. YMMV
*/
alias t_ = tuple;

@("EXAMPLES") unittest
{
  /*
    the generic universal product function, adjoin
  */
  auto t1 = 1.adjoin!(x => x*2, x => x*3);
    assert(t1[0] == 2);
    assert(t1[1] == 3);

  /*
    adjoin supports named fields.
  */
  auto t2 = 2.adjoin!(
    q{sq}, x => x^^2,
    q{cu}, x => x^^3,
  );
    assert(t2.sq == 4 && t2.cu == 8);

  ////////////////////

  /*
    This helper function attempts to strike a balance between being unambiguous and minimizing visual noise.
  */
  assert(t_(9,2)[0] == 9);
  /*
    It supports named fields.
  */
  assert(t_!(q{a}, q{b})(9,2).b == 2);
  /*
    Because of D's optional parenthesis for nullary functions, t_ is analogous to "unit" in many functional languages
    This can be handy in generic programming; for example: as a leaf in a call tree, where the parent node is a nullary function.
  */
  bool kTrue() { return true; }
    assert(kTrue(t_[]));

  /*
    Tuples form a monoid over field types where mappend = tconcat and mempty = t_
  */
  auto t3 = t2.tconcat(
    t_!(q{c},q{d})
         (9,   2)
  );
    assert(t3[0..2] == t2[]);
    assert(t3[2..$] == t_(9,2)[]);
  /*
    Field names are preserved
  */
    assert(t3.sq == 4);
    assert(t3.cu == 8);
    assert(t3.c  == 9);
    assert(t3.d  == 2);

  /*
    tlift maps a generic function over all tuple elements
  */
  auto t4 = t3.tlift!(_ => 100);
    assert(t4.sq == 100);
    assert(t4.cu == 100);
    assert(t4.c  == 100);
    assert(t4.d  == 100);

  ////////////////////

  /*
    common ops and idioms
  */

  /*
    rename fields
  */
  auto t5 = t2[].t_!(q{abc}, q{def});
    assert(t5.abc == t2.sq);
    assert(t5.def == t2.cu);

  /*
    nfunctor map over tuples
  */
  assert(
    t_(1,2).adjoin!(
      _=>_[0] - 1,
      _=>_[1] - 2,
    )
    == t_(0,0)
  );

  /*
    convert homogenously typed tuple to array
  */
  assert( 
    [ t_(1,2,3)[] ]
    == [1,2,3]
  );
  /*
    convert heterogenously typed tuple to array
  */
  import std.conv : to;
  assert( 
    [ t_(1, 2.0, "3").tlift!(to!int)[] ]
    == [1,2,3]
  );

  /*
    convert tuple to struct
  */
  struct Vec3 { float x, y, z; }
  assert(
   Vec3(t_(0, 2, -9.8)[])
    == Vec3(0, 2, -9.8)
  );
  /*
    convert struct to tuple
  */
  assert(
    Vec3(1, 4, 7).tupleof.t_
    == t_(1,4,7)
  );
}
