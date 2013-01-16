%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Vector clocks.
%%% @reference citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.142.3682
%%% @reference ieeexplore.ieee.org/xpl/freeabs_all.jsp?arnumber=1703051
%%% @reference citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.47.7435
%%% @reference github.com/basho/riak_core/blob/master/src/vclock.erl
%%% @reference github.com/cliffmoon/dynomite/blob/master/elibs/vector_clock.erl
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
-module(tulib_vclocks).

%%%_* Exports ==========================================================
-export([ compare/2
        , increment/2
        , is_vclock/1
        , merge/2
        , new/0
        , prune/2
        , size/1
        ]).

-export_type([ clock/0
             , index/0
             , relation/0
             ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
-opaque clock()    :: alist(index(), non_neg_integer()).
-type   index()    :: _.
-type   relation() :: equal | less_than | greater_than | concurrent.


-spec compare(clock(), clock()) -> relation().
%% @doc Indicate C1's relation to C2.
compare(C1, C2) -> compare(C1, C2, equal).

compare([_|_], [],    Rel) -> rel(Rel, greater_than);
compare([],    [_|_], Rel) -> rel(Rel, less_than);
compare([],    [],    Rel) -> Rel;
compare([First|Rest], Clock0, Rel0) ->
  {Clock, Rel} = do_compare(First, Clock0, Rel0),
  compare(Rest, Clock, Rel).

do_compare({S, N1}, C2, Rel) ->
  case lists:keytake(S, 1, C2) of
    {value, {S, N2}, Rest} -> {Rest, rel(Rel, do_compare(N1, N2))};
    false                  -> {C2,   rel(Rel, greater_than)}
  end.

do_compare(N1, N2) when N1  <  N2 -> less_than;
do_compare(N1, N2) when N1 =:= N2 -> equal;
do_compare(N1, N2) when N1  >  N2 -> greater_than.

rel(equal, Rel)   -> Rel;
rel(Rel,   equal) -> Rel;
rel(Rel,   Rel)   -> Rel;
rel(_,     _)     -> concurrent.


-spec increment(clock(), index()) -> clock().
%% @doc Increment site S's counter by one.
increment([{S, N}|Rest], S) -> [{S, N+1}|Rest];
increment([First|Rest],  S) -> [First|increment(Rest, S)];
increment([],            S) -> [{S, 1}].


-spec new() -> clock().
%% @doc Return a fresh vector clock.
new() -> [].


-spec is_vclock(_) -> boolean().
is_vclock(X)       -> is_list(X).


-spec merge(clock(), clock()) -> clock().
%% @doc Return the supremum of C1 and C2.
merge(C1, []) -> C1;
merge([], C2) -> C2;
merge([{S, N1}|C1], C2) ->
  case lists:keytake(S, 1, C2) of
    {value, {S, N2}, Rest} -> [{S, erlang:max(N1, N2)}|merge(C1, Rest)];
    false                  -> [{S, N1}|merge(C1, C2)]
  end.


-spec prune(clock(), fun((index()) -> boolean())) -> clock().
%% @doc Remove entries for sites for which Pred returns true from VC.
prune(C, Pred) -> [X || {S, _} = X <- C, not Pred(S)].


-spec size(clock()) -> non_neg_integer().
%% @doc Return the number of entries in C.
size(C) -> length(C).

%%%_* Tests ============================================================
-ifdef(TEST).

mk(N)        -> [{I, 0} || I <- lists:seq(0, N-1)].

incr(C, Is)  -> lists:foldl(fun(I, C) -> increment(C, I) end, C, Is).

print(C)     -> tulib_strings:fmt("~p", [[N || {_, N} <- C]]).

pp(C)        -> "[" ++ pp1(C) ++ "]".
pp1({S,N})   -> tulib_lists:to_list(S) ++ ":" ++ tulib_lists:to_list(N);
pp1([])      -> "";
pp1([X])     -> pp1(X);
pp1([X|Xs])  -> pp1(X) ++ "," ++ pp1(Xs).


basic_test() ->
  C1           = mk(2),
  C2           = mk(2),
  equal        = compare(C1, C2),
  equal        = compare(C2, C1),
  C11          = increment(C1, 0),
  C21          = increment(C2, 1),
  less_than    = compare(C1,  C11),
  less_than    = compare(C2,  C11),
  less_than    = compare(C1,  C21),
  less_than    = compare(C2,  C21),
  concurrent   = compare(C11, C21),
  concurrent   = compare(C21, C11),
  greater_than = compare(C11, C1),
  greater_than = compare(C11, C2),
  greater_than = compare(C21, C1),
  greater_than = compare(C21, C2),
  C            = merge(C11, C21),
  equal        = compare(C, C),
  less_than    = compare(C1,  C),
  less_than    = compare(C2,  C),
  less_than    = compare(C11, C),
  less_than    = compare(C21, C),
  greater_than = compare(C,   C1),
  greater_than = compare(C,   C2),
  greater_than = compare(C,   C11),
  greater_than = compare(C,   C21),
  C12          = increment(C11, 1),
  C22          = increment(C21, 0),
  equal        = compare(C12, C22),
  equal        = compare(C22, C12),
  equal        = compare(C12, C),
  equal        = compare(C22, C),
  equal        = compare(C,   C12),
  equal        = compare(C,   C22),
  less_than    = compare(C1,  C12),
  less_than    = compare(C2,  C12),
  less_than    = compare(C11, C12),
  less_than    = compare(C21, C12),
  less_than    = compare(C1,  C22),
  less_than    = compare(C2,  C22),
  less_than    = compare(C11, C22),
  less_than    = compare(C21, C22),
  greater_than = compare(C12, C1),
  greater_than = compare(C12, C2),
  greater_than = compare(C12, C11),
  greater_than = compare(C12, C21),
  greater_than = compare(C22, C1),
  greater_than = compare(C22, C2),
  greater_than = compare(C22, C11),
  greater_than = compare(C22, C21),
  ok.

print_test() ->
  C0          = mk(4),
  C1          = increment(C0, 1),
  C2          = increment(C1, 3),
  "[0,0,0,0]" = print(C0),
  "[0,1,0,0]" = print(C1),
  "[0,1,0,1]" = print(C2),
  less_than   = compare(C0, C1),
  less_than   = compare(C1, C2),
  less_than   = compare(C0, C2),
  ok.

mattern_test() ->
  P11          = incr(mk(4), [0, 1]),
  P12          = incr(mk(4), [0, 0, 1]),
  "[1,1,0,0]"  = print(P11),
  "[2,1,0,0]"  = print(P12),

  P21          = incr(mk(4), [1]),
  P22          = incr(mk(4), [1, 1]),
  P23          = incr(mk(4), [0, 0, 1, 1, 1, 2, 2, 2, 3]),
  "[0,1,0,0]"  = print(P21),
  "[0,2,0,0]"  = print(P22),
  "[2,3,3,1]"  = print(P23),

  P31          = incr(mk(4), [2, 3]),
  P32          = incr(mk(4), [0, 0, 1, 2, 2, 3]),
  P33          = incr(mk(4), [0, 0, 1, 2, 2, 2, 3]),
  "[0,0,1,1]"  = print(P31),
  "[2,1,2,1]"  = print(P32),
  "[2,1,3,1]"  = print(P33),

  P41          = incr(mk(4), [3]),
  P42          = incr(mk(4), [3, 3]),
  "[0,0,0,1]"  = print(P41),
  "[0,0,0,2]"  = print(P42),

  equal        = compare(P11, P11),
  less_than    = compare(P11, P12),
  greater_than = compare(P11, P21),
  concurrent   = compare(P11, P22),
  less_than    = compare(P11, P23),
  concurrent   = compare(P11, P31),
  less_than    = compare(P11, P32),
  less_than    = compare(P11, P33),
  concurrent   = compare(P11, P41),
  concurrent   = compare(P11, P42),

  greater_than = compare(P12, P11),
  equal        = compare(P12, P12),
  greater_than = compare(P12, P21),
  concurrent   = compare(P12, P22),
  less_than    = compare(P12, P23),
  concurrent   = compare(P12, P31),
  less_than    = compare(P12, P32),
  less_than    = compare(P12, P33),
  concurrent   = compare(P12, P41),
  concurrent   = compare(P12, P42),

  less_than    = compare(P21, P11),
  less_than    = compare(P21, P12),
  equal        = compare(P21, P21),
  less_than    = compare(P21, P22),
  less_than    = compare(P21, P23),
  concurrent   = compare(P21, P31),
  less_than    = compare(P21, P32),
  less_than    = compare(P21, P33),
  concurrent   = compare(P21, P41),
  concurrent   = compare(P21, P42),

  concurrent   = compare(P22, P11),
  concurrent   = compare(P22, P12),
  greater_than = compare(P22, P21),
  equal        = compare(P22, P22),
  less_than    = compare(P22, P23),
  concurrent   = compare(P22, P31),
  concurrent   = compare(P22, P32),
  concurrent   = compare(P22, P33),
  concurrent   = compare(P22, P41),
  concurrent   = compare(P22, P42),

  greater_than = compare(P23, P11),
  greater_than = compare(P23, P12),
  greater_than = compare(P23, P21),
  greater_than = compare(P23, P22),
  equal        = compare(P23, P23),
  greater_than = compare(P23, P31),
  greater_than = compare(P23, P32),
  greater_than = compare(P23, P33),
  greater_than = compare(P23, P41),
  concurrent   = compare(P23, P42),

  concurrent   = compare(P31, P11),
  concurrent   = compare(P31, P12),
  concurrent   = compare(P31, P21),
  concurrent   = compare(P31, P22),
  less_than    = compare(P31, P23),
  equal        = compare(P31, P31),
  less_than    = compare(P31, P32),
  less_than    = compare(P31, P33),
  greater_than = compare(P31, P41),
  concurrent   = compare(P31, P42),

  greater_than = compare(P32, P11),
  greater_than = compare(P32, P12),
  greater_than = compare(P32, P21),
  concurrent   = compare(P32, P22),
  less_than    = compare(P32, P23),
  greater_than = compare(P32, P31),
  equal        = compare(P32, P32),
  less_than    = compare(P32, P33),
  greater_than = compare(P32, P41),
  concurrent   = compare(P32, P42),

  greater_than = compare(P33, P11),
  greater_than = compare(P33, P12),
  greater_than = compare(P33, P21),
  concurrent   = compare(P33, P22),
  less_than    = compare(P33, P23),
  greater_than = compare(P33, P31),
  greater_than = compare(P33, P32),
  equal        = compare(P33, P33),
  greater_than = compare(P33, P41),
  concurrent   = compare(P33, P42),

  concurrent   = compare(P41, P11),
  concurrent   = compare(P41, P12),
  concurrent   = compare(P41, P21),
  concurrent   = compare(P41, P22),
  less_than    = compare(P41, P23),
  less_than    = compare(P41, P31),
  less_than    = compare(P41, P32),
  less_than    = compare(P41, P33),
  equal        = compare(P41, P41),
  less_than    = compare(P41, P42),

  concurrent   = compare(P42, P11),
  concurrent   = compare(P42, P12),
  concurrent   = compare(P42, P21),
  concurrent   = compare(P42, P22),
  concurrent   = compare(P42, P23),
  concurrent   = compare(P42, P31),
  concurrent   = compare(P42, P32),
  concurrent   = compare(P42, P33),
  greater_than = compare(P42, P41),
  equal        = compare(P42, P42),

  ok.

var_size_test() ->
  C1           = new(),
  C2           = new(),
  equal        = compare(C1, C2),
  C11          = increment(C1, foo),
  C21          = increment(C2, bar),
  less_than    = compare(C1,  C11),
  concurrent   = compare(C11, C21),
  C12          = increment(C11, bar),
  C22          = increment(C21, baz),
  greater_than = compare(C12, C21),
  concurrent   = compare(C12, C22),
  C0           = merge(C12, C22),
  C            = increment(C0, foo),
  C13          = increment(C12, baz),
  less_than    = compare(C13, C),
  C14          = increment(C13, foo),
  equal        = compare(C14, C),
  C15          = increment(C14, quux),
  less_than    = compare(C, C15),
  ok.

parker_test() ->
  %% p. 243
  C1                  = incr(new(), [a,b,b,c,c,c,c,d,d,d]),
  C2                  = incr(new(), [b,b,c,c,d,d,d]),
  C3                  = incr(new(), [a,b,b,c,c,c,d,d,d,d]),
  C4                  = incr(new(), [a,b,b,c,c,c,c,d,d,d,d]),
  "[a:1,b:2,c:4,d:3]" = pp(C1),
  "[b:2,c:2,d:3]"     = pp(C2),
  "[a:1,b:2,c:3,d:4]" = pp(C3),
  "[a:1,b:2,c:4,d:4]" = pp(C4),
  greater_than        = compare(C1, C2),
  concurrent          = compare(C1, C3),
  greater_than        = compare(C4, C1),
  greater_than        = compare(C4, C3),
  %% p. 244
  C5                  = new(),
  C6                  = incr(new(), [a,a]),
  C7                  = incr(new(), [a,a,c]),
  C8                  = incr(new(), [a,a,a]),
  "[]"                = pp(C5),
  "[a:2]"             = pp(C6),
  "[a:2,c:1]"         = pp(C7),
  "[a:3]"             = pp(C8),
  less_than           = compare(C5, C6),
  less_than           = compare(C6, C7),
  less_than           = compare(C5, C7),
  less_than           = compare(C6, C8),
  concurrent          = compare(C7, C8),
  ok.

prune_test() ->
  Clock0 = mk(10),
  true   = is_vclock(Clock0),
  10     = ?MODULE:size(Clock0),
  Clock  = prune(Clock0, fun(X) -> X rem 2 =:= 0 end),
  5      = ?MODULE:size(Clock),
  ok.

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
