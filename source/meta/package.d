module universal.meta;
private { /* imports */
  import std.string;
  import std.algorithm;
  import std.range;
  import std.conv;
  import std.format;
	import std.traits;
	import std.typetuple;
	import std.typecons;

  alias splitter = std.algorithm.splitter;
}

string toPascalCase(string name)
{
	string nName;

	if(name == name.map!toUpper.text)
		nName = name.map!toLower.text;
	else
		nName = name;

	if(name.canFind("_"))
		return nName.splitter('_').map!capitalize.join.text;
	else 
		return nName;
}
string toCamelCase(string name)
{
  auto pc = name.toPascalCase;

  if(name == "")
    return "";
  else
    return pc[0].toLower.text ~ pc[1..$];
}
string indent(string range)
{
  return "\t" ~ range.replace("\n", "\n\t");
}

enum simpleName(A...) = simpleName!(__traits(identifier, A));
enum simpleName(string name) = name.retro.until('.').text.retro.text;

enum isString(A...) = is(typeof(A[0]) == string);
enum isType  (A...) = is(A[0]);

enum isParameterized(A...) 
= isCallable!A || __traits(isTemplate, A);

alias Instantiate(alias symbol, Args...) = symbol!Args;

template Interleave(Symbols...) if(Symbols.length % 2 == 0)
{
	alias A = Symbols[0..$/2];
	alias B = Symbols[$/2..$];

	alias Pair(uint i) = TypeTuple!(A[i], B[i]);

	alias Interleave = staticMap!(Pair, staticIota!(0, A.length));
}

template DeclSpecs(specs...)
{
  alias names = Filter!(isString, specs);
  alias Types = Filter!(isType, specs);

  static if(isString!(specs[0]))
    alias DeclSpecs = Interleave!(names, Types);
  else static if(names.length > 0)
    alias DeclSpecs = Interleave!(Types, names);
  else
    alias DeclSpecs = Types;
}
alias DeclSpecs() = TypeTuple!();

auto WIP(string f = __FUNCTION__)() 
{ return format(q{ assert(0, "unimplemented \"%s\""); }, simpleName!f); }

alias Repeat(uint n, A...) = TypeTuple!(Repeat!(n-1, A), A);
alias Repeat(uint n : 0, _...) = TypeTuple!();
