%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Counting sets.
%%% @copyright 2012 Klarna AB
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
-module(tulib_csets).

%%%_* Exports ==========================================================
-export([ add_element/2
        , cnt_element/2
        , del_element/2
        , is_cset/1
        , is_element/2
        , mode/1
        , new/0
        , new/1
        , to_list/1
        , toggle/1
        , union/2
        ]).

-export_type([ cset/0
             , mode/0
             ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").

%%%_* Code =============================================================
-type mode()                              :: cset | set.
-define(is_mode(X)                        ,  (X =:= cset orelse X =:= set)).

-record(cset,
        { m=throw('#cset.m')              :: mode()
        , xs=dict:new()                   :: dict()
        }).

-opaque cset()                            :: #cset{}.


-spec add_element(_, cset())              -> cset().
add_element(X, #cset{m=M, xs=Xs} = C)     -> C#cset{xs=add_element(M, X, Xs)}.
add_element(cset, X, Xs)                  -> dict:update(X, fun inc/1, 1, Xs);
add_element(set,  X, Xs)                  -> dict:store(X, 1, Xs).

-spec cnt_element(_, cset())              -> integer().
cnt_element(X, #cset{xs=Xs})              -> try dict:fetch(X, Xs)
                                             catch _:_ -> 0
                                             end.

-spec del_element(_, cset())              -> cset().
del_element(X, #cset{m=M, xs=Xs}= C)      -> C#cset{xs=del_element(M, X, Xs)}.
del_element(cset, X, Xs)                  -> dict:update(X, fun dec/1, -1, Xs);
del_element(set,  X, Xs)                  -> dict:erase(X, Xs).

-spec is_cset(_)                          -> boolean().
is_cset(#cset{})                          -> true;
is_cset(_)                                -> false.

-spec is_element(_, cset())               -> boolean().
is_element(X, C)                          -> cnt_element(X, C) > 0.

-spec mode(cset())                        -> mode().
mode(#cset{m=M})                          -> M.

-spec new()                               -> cset().
new()                                     -> new(cset).

-spec new(mode())                         -> cset().
new(M) when ?is_mode(M)                   -> #cset{m=M}.

-spec to_list(cset())                     -> [{_, integer()}].
to_list(#cset{xs=Xs})                     -> dict:to_list(Xs).

-spec toggle(cset())                      -> cset().
toggle(#cset{m=cset} = C)                 -> C#cset{m=set};
toggle(#cset{m=set}  = C)                 -> C#cset{m=cset}.

-spec union(cset(), cset())               -> cset().
union(#cset{m=M} = C1, #cset{m=M} = C2)   -> #cset{m=M, xs=union(M, C1, C2)};
union(#cset{}, #cset{})                   -> throw(mode).
union(cset, #cset{xs=Xs1}, #cset{xs=Xs2}) -> dict:merge(fun sum/3,  Xs1, Xs2);
union(set,  #cset{xs=Xs1}, #cset{xs=Xs2}) -> dict:merge(fun bsum/3, Xs1, Xs2).


%% @private
inc(X)                                    -> X + 1.
dec(X)                                    -> X - 1.

sum(_, N1, N2)                            -> N1 + N2.
bsum(_, N1, N2)                           -> int_to_bool(N1 + N2).
int_to_bool(N) when N =< 0                -> 0;
int_to_bool(N) when N  > 0                -> 1.

%%%_* Tests ============================================================
-ifdef(TEST).

basic_test() ->
  C0    = new(),
  true  = is_cset(C0),
  false = is_cset(to_list(C0)),
  true  = mode(C0) =:= mode(toggle(toggle(C0))),

  false = is_element(foo, C0),
  0     = cnt_element(foo, C0),

  C1    = add_element(foo, C0),
  true  = is_element(foo, C1),
  1     = cnt_element(foo, C1),

  C2    = del_element(foo, C1),
  false = is_element(foo, C2),
  0     = cnt_element(foo, C2),

  C3    = add_element(foo, add_element(foo, C2)),
  true  = is_element(foo, C3),
  2     = cnt_element(foo, C3),

  C4    = lists:foldl(fun(X, Acc) -> del_element(X, Acc) end,
                      C3,
                      [foo, foo, foo, foo]),
  false = is_element(foo, C4),
  -2    = cnt_element(foo, C4),

  C5    = union(C3, C4),
  false = is_element(foo, C5),
  0     = cnt_element(foo, C5),

  C6    = toggle(C4), %C_4_
  set   = mode(C6),
  false = is_element(foo, C6),
  -2    = cnt_element(foo, C6),

  C7    = add_element(foo, C6),
  true  = is_element(foo, C7),
  1     = cnt_element(foo, C7),

  C8    = del_element(foo, C6), %C_6_
  false = is_element(foo, C8),
  0     = cnt_element(foo, C8),

  C9    = toggle(C3), %C_3_
  true  = is_element(foo, C9),
  2     = cnt_element(foo, C9),

  C10   = add_element(foo, C9),
  true  = is_element(foo, C10),
  1     = cnt_element(foo, C10),

  C11   = del_element(foo, C9),
  false = is_element(foo, C11),
  0     = cnt_element(foo, C11),

  mode  = (catch union(C4, C6)),

  C12   = add_element(foo, add_element(bar, new())),
  C13   = del_element(foo,
                      del_element(foo,
                                  add_element(bar,
                                              add_element(bar, new())))),
  1     = cnt_element(foo, C12),
  1     = cnt_element(bar, C12),
  -2    = cnt_element(foo, C13),
  2     = cnt_element(bar, C13),

  C14   = union(C12, C13),
  false = is_element(foo, C14),
  true  = is_element(bar, C14),
  -1    = cnt_element(foo, C14),
  3     = cnt_element(bar, C14),

  C15   = union(toggle(C12), toggle(C13)),
  false = is_element(foo, C15),
  true  = is_element(bar, C15),
  0     = cnt_element(foo, C15),
  1     = cnt_element(bar, C15),

  ok.

-endif.

%%%_* Emacs =============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
