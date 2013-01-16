%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Atom-related utility functions.
%%% @copyright 2011 Klarna AB
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%
%%%   Copyright 2011-2013 Klarna AB
%%%
%%%   Licensed under the Apache License, Version 2.0 (the "License");
%%%   you may not use this file except in compliance with the License.
%%%   You may obtain a copy of the License at
%%%
%%%       http://www.apache.org/licenses/LICENSE-2.0
%%%
%%%   Unless required by applicable law or agreed to in writing, software
%%%   distributed under the License is distributed on an "AS IS" BASIS,
%%%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%%   See the License for the specific language governing permissions and
%%%   limitations under the License.
%%%

%%%_* Module declaration ===============================================
-module(tulib_atoms).

%%%_* Exports ==========================================================
-export([ catenate/1
        , gensym/0
        , gensym/1
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/prelude.hrl").

%%%_* Code =============================================================
-spec catenate([_]) -> atom().
%% @doc Turn a list of terms into an atom.
catenate(Args)      -> ?l2a(lists:concat(Args)).

catenate_test()     -> foo@bar = catenate([foo, '@', "bar"]).


-spec gensym() -> atom().
%% @doc Generate a fresh atom.
gensym() ->
  gensym('$gensym').

gensym(Prefix) ->
  gensym(Prefix, 1).

gensym(_Prefix, Cnt) when Cnt > 3 ->
  erlang:error(ref_overflow);
gensym(Prefix0, Cnt) ->
  Prefix       = tulib_lists:to_list(Prefix0),
  Ref          = erlang:ref_to_list(make_ref()),
  {ok, Ns, []} = io_lib:fread("#Ref<~d.~d.~d.~d>", Ref),
  Suffix       = lists:concat(Ns),
  Sym          = Prefix ++ Suffix,
  case catch list_to_existing_atom(Sym) of
    {'EXIT', {badarg, _}} -> ?l2a(Sym);
    _                     -> gensym(Prefix0, Cnt+1)
  end.

gensym0_test()      -> ?assert(gensym()    =/= gensym()).
gensym1_test()      -> ?assert(gensym(foo) =/= gensym(foo)).
gensym_cover_test() -> ?assertError(ref_overflow, gensym(foo, 4)).

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
