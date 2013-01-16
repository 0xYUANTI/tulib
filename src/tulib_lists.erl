%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc List-related utility functions.
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
-module(tulib_lists).

%%%_* Exports ==========================================================
%% Quantifiers
-export([ all/1
        , exists/1
        ]).

%% Alists
-export([ assoc/2
        , assoc/3
        , assoc_delete/2
        , assoc_update/3
        , assoc_update/4
        , keyfilter/2
        , multikeyfilter/2
        ]).

%% Sublists
-export([ butlast/1
        , drop/2
        , take/2
        , partition/2
        , pickwith/2
        , strict_partition/2
        ]).

%% Constructors
-export([ cons/1
        , cons/2
        , ensure/1
        , to_list/1
        , repeatedly/2
        , seq/1
        ]).

%% Search
-export([ find/2
        , find_result/2
        , max/1
        , min/1
        ]).

%% Misc
-export([ flatrev/1
        , intersperse/2
        , join/1
        , numbered/1
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
%%%_ * Quantifiers -----------------------------------------------------
-spec all(Xs::[_])    -> boolean().
%% @doc Indicate whether Xs contains only `true'.
all([])               -> true;
all([true|Xs])        -> all(Xs);
all(_)                -> false.

-spec exists(Xs::[_]) -> boolean().
%% @doc Indicate whether Xs contains at least one `true'.
exists([])            -> false;
exists([true|_])      -> true;
exists([_|Xs])        -> exists(Xs).

quantifier_test() ->
  false = all([true, false, true]),
  true  = exists([false, true]),
  false = exists([]).

%%%_ * Alists ----------------------------------------------------------
-spec assoc(A, alist(A, B)) -> maybe(B, notfound).
%% @doc Lookup Key in Alist.
assoc(_, [])                -> {error, notfound};
assoc(K, [{K, V}|_])        -> {ok, V};
assoc(K, [{_, _}|T])        -> assoc(K, T).

assoc(K, Alist, Default) ->
  case assoc(K, Alist) of
    {ok, V}           -> V;
    {error, notfound} -> Default
  end.

assoc_test() ->
  {ok, bar}         = assoc(foo, [{foo,bar}]),
  {error, notfound} = assoc(foo, []).


-spec assoc_delete(A, alist(A, _)) -> alist(A, _).
%% @doc Remove all entries associated with Key from Alist.
assoc_delete(Key, Alist) -> lists:filter(fun({K, _}) -> K =/= Key end, Alist).

assoc_delete_test() ->
  Alist = [{foo,1},{bar,2},{baz,3},{bar,0}],
  [{foo,1},{baz,3}] = assoc_delete(bar, Alist).


-spec assoc_update(A, fun((B) -> B), alist(A, B)) -> alist(A, B).
%% Replace the newest Val associated with Key by F(Val).
assoc_update(Key, F, [{Key, Val}|Rest]) -> [{Key, F(Val)}|Rest];
assoc_update(Key, F, [First|Rest])      -> [First|assoc_update(Key, F, Rest)].

assoc_update3_test() ->
  Alist = [{foo,1},{bar,2},{baz,3},{bar,0}],
  [{foo,1},{bar,3},{baz,3},{bar,0}] =
    assoc_update(bar, fun(X) -> X + 1 end, Alist).


-spec assoc_update(A, fun((B) -> B), B, alist(A, B)) -> alist(A, B).
%% Replace the newest Val associated with Key by F(Val). Associate Key
%% with F(Default) if there's no Val.
assoc_update(Key, F, _Default, [{Key,Val}|Rest]) ->
  [{Key, F(Val)}|Rest];
assoc_update(Key, F, Default, [First|Rest]) ->
  [First|assoc_update(Key, F, Default, Rest)];
assoc_update(Key, F, Default, []) ->
  [{Key, F(Default)}].

assoc_update4_test() ->
  [{foo,1}]          = assoc_update(foo, fun(X) -> X + 1 end, 0, []),
  [{foo,1}, {bar,2}] = assoc_update(bar, fun(X) -> X + 1 end, 0, [{foo,1}, {bar,1}]).


-spec keyfilter(A, alist(A, _)) -> alist(A, _).
%% @doc Return all elements of Alist with a key equal to K1.
keyfilter(K1, Alist) -> lists:filter(fun({K2, _V}) -> K1 =:= K2 end, Alist).

keyfilter_test() -> [{foo, bar}] = keyfilter(foo, [{foo, bar}]).


-spec multikeyfilter([A], alist(A, _)) -> alist(A, _).
%% @doc Return all elements of Alist with a key in Ks.
multikeyfilter(Ks, Alist) ->
  lists:filter(fun({K, _V}) -> lists:member(K, Ks) end, Alist).

multikeyfilter_test() -> [{foo, bar}] = multikeyfilter([foo], [{foo, bar}]).

%%%_ * Sublists --------------------------------------------------------
-spec butlast(Xs::[A,...]) -> [A].
%% @doc Return Xs (assumed to be non-empty) without its last element.
butlast([_])           -> [];
butlast([X|Xs])        -> [X|butlast(Xs)].

butlast_test()         -> [1, 2] = butlast([1, 2, 3]).


-spec drop(integer(), [_]) -> [_].
%% @doc Return Xs without its first N elements.
%% Returns the empty list if Xs has fewer than N elements.
drop(N, Xs) when N =< 0    -> Xs;
drop(_, [])                -> [];
drop(N, [_|Xs])            -> drop(N-1, Xs).

drop_test() ->
  [3] = drop(2, [1, 2, 3]),
  []  = drop(2, []).


-spec take(integer(), [_]) -> [_].
%% @doc Return the first N elements of Xs.
%% Returns the empty list if Xs has fewer than N elements.
take(N, _) when N =< 0     -> [];
take(_, [])                -> [];
take(N, [X|Xs])            -> [X|take(N-1, Xs)].

take_test() ->
  [1] = take(1, [1, 2, 3]),
  []  = take(1, []).


-spec partition(non_neg_integer(), [_]) -> [[_]] | [].
%% @doc Split Xs into sublists of N elements each.
%% If Xs has fewer than N elements, return a single partition containing
%% all elements.
%% If Xs is empty, return the empty list.
partition(0, []) ->
  [];
partition(N, Xs)
  when is_integer(N)
     , N > 0
     , is_list(Xs) ->
  Len = length(Xs),
  case {Len > 0, Len > N} of
    {false, false} -> [];
    {true,  true } -> [take(N, Xs)|partition(N, drop(N, Xs))];
    {true,  false} -> [Xs]
  end.

partition_test() ->
  []               = partition(0, []),
  []               = partition(2, []),
  [[1]]            = partition(2, [1]),
  [[1, 2]]         = partition(2, [1, 2]),
  [[1, 2], [3]]    = partition(2, [1, 2, 3]),
  [[1, 2], [3, 4]] = partition(2, [1, 2, 3, 4]),
  ok.


-spec strict_partition(non_neg_integer(), [_]) -> [[_]] | [].
%% @doc Split Xs into sublists of exactly N elements each.
%% If Xs is empty, return the empty list.
strict_partition(N, Xs)
  when is_integer(N)
     , N > 0
     , is_list(Xs) ->
  0 = length(Xs) rem N,
  partition(N, Xs).

strict_partition_test() ->
  [[1, 2], [3, 4]] = strict_partition(2, [1, 2, 3, 4]),
  ?assertError({badmatch, 1}, strict_partition(2, [1, 2, 3])),
  ok.


-spec pickwith(fun((A) -> boolean()), list(A)) -> {A, [A]} | false.
%% @doc Try to find an element satisfying Pred in List. Returns {Match, Other}
%%      where
%%      - Match is the first element in List for which Pred returned true.
%%      - Other is List with Match removed.
%%
%%      Returns false if no element in List satisfies Pred.
pickwith(_Pred, List) ->
  pickwith(_Pred, List, []).
pickwith(_Pred, [], _Acc) ->
  false;
pickwith( Pred, [H|T], Acc) ->
  case Pred(H) of
    false -> pickwith(Pred, T, [H|Acc]);
    true  -> {H, lists:reverse(Acc) ++ T}
  end.

pickwith_test_() ->
   F = fun(E) -> E =:= a end,
   [ ?_assertEqual(false,             pickwith(F, []))
   , ?_assertEqual(false,             pickwith(F, [b]))
   , ?_assertEqual({a, []},           pickwith(F, [a]))
   , ?_assertEqual({a, [b]},          pickwith(F, [a, b]))
   , ?_assertEqual({a, [b]},          pickwith(F, [b, a]))
   , ?_assertEqual({a, [b, c, d, e]}, pickwith(F, [b, c, a, d, e]))
   ].

%%%_ * Constructors ----------------------------------------------------
-spec cons(_, _) -> maybe_improper_list().
%% @doc Cons car onto cdr.
cons(Car, Cdr)   -> [Car|Cdr].
cons(Car)        -> fun(Cdr) -> cons(Car, Cdr) end.

cons_test()      -> [foo, bar|baz] = (cons(foo))(cons(bar, baz)).


-spec ensure(_)           -> [_].
%% @doc Return a list.
ensure(X) when is_list(X) -> X;
ensure(X)                 -> [X].

ensure_test() ->
  []   = ensure([]),
  [42] = ensure(42).


-spec to_list(_)              -> [_].
%% @doc Return the list-representation of X.
to_list(X) when is_list(X)    -> X;
to_list(X) when is_pid(X)     -> pid_to_list(X);
to_list(X) when is_atom(X)    -> ?a2l(X);
to_list(X) when is_tuple(X)   -> ?t2l(X);
to_list(X) when is_binary(X)  -> ?b2l(X);
to_list(X) when is_integer(X) -> ?i2l(X).

to_list_test() ->
  []       = to_list([]),
  "<" ++ _ = to_list(self()),
  "foo"    = to_list(foo),
  [1,2]    = to_list({1,2}),
  []       = to_list(<<>>),
  "42"     = to_list(42).


-spec repeatedly(non_neg_integer(), fun(() -> A)) -> [A].
%% @doc Call F N times and return a list of the results.
repeatedly(N, F) when is_integer(N) , N > 0       -> [F()|repeatedly(N-1, F)];
repeatedly(0, F) when is_function(F, 0)           -> [].

repeatedly_test() -> [42, 42, 42] = repeatedly(3, fun() -> 42 end).


-spec seq(pos_integer()) -> [pos_integer()].
%% @doc Return a list of integers from 1 to N.
seq(N)                   -> lists:seq(1, N).

seq_test()               -> [1] = seq(1).

%%%_ * Search ----------------------------------------------------------
-spec find(fun(), Xs::[term()]) -> maybe(term(), not_found).
%% @doc Return the first element of Xs for which Pred returns true.
find(Pred, [X|Xs]) ->
  case Pred(X) of
    true  -> {ok, X};
    false -> find(Pred, Xs)
  end;
find(_Pred, []) -> {error, not_found}.

find_test() ->
  {ok, x}            = find(fun(X) -> X =:= x end, [a, b, x, c]),
  {error, not_found} = find(fun(X) -> X =:= x end, [a, b, c]).


-spec find_result(fun(), Xs::[term()]) -> maybe(term(), not_found).
%% @doc Return the result of applying F to the first element of Xs for
%% which F returns something other than `false'
find_result(F, [X|Xs]) ->
  case F(X) of
    false -> find_result(F, Xs);
    Val  -> {ok, Val}
  end;
find_result(_F, []) -> {error, not_found}.

find_result_test() ->
  F = fun(x) -> yippie;
         (_) -> false
      end,
  {ok, yippie}       = find_result(F, [a, b, x, c]),
  {error, not_found} = find_result(F, [a, b, c]).


-spec max([A, ...])   -> A.
%% @doc Return the maximum of Xs.
max([X|Xs])           -> lists:foldl(fun max/2, X, Xs).

-spec max(A, B)       -> A | B.
max(X, Y) when X >= Y -> X;
max(X, Y) when X <  Y -> Y.

-spec min([A, ...])   -> A.
%% @doc Return the minimum of Xs.
min([X|Xs])           -> lists:foldl(fun min/2, X, Xs).

-spec min(A, B)       -> A | B.
min(X, Y) when X =< Y -> X;
min(X, Y) when X >  Y -> Y.

min_max_test() ->
  0   = min([42, 0, 666]),
  666 = max([42, 0, 666]).

%%%_ * Misc ------------------------------------------------------------
-spec flatrev([[A]])                -> [A].
%% @doc Flatten and reverse Xs.
flatrev(Xs)                         -> flatrev(Xs, []).
flatrev([X|Xs], Acc)                -> flatrev(Xs, flatrev(X, Acc));
flatrev(X, Acc) when not is_list(X) -> [X|Acc];
flatrev([], Acc)                    -> Acc.

flatrev_test() -> [1,2,3,4,5,6] = flatrev([[6],[[5,4]],[],[3,2,1]]).


-spec intersperse(_, [_]) -> [_].
%% @doc Intersperse X into Ys.
intersperse(X, Ys) ->
  lists:reverse(tl(lists:foldl(fun(Y, Acc) -> [X, Y|Acc] end, [], Ys))).

intersperse_test() ->
  [1,0,2,0,3,0,4] = intersperse(0, [1,2,3,4]),
  "H-e-l-l-o"     = intersperse($-, "Hello").


-spec join([[A]]) -> [A].
%% @doc Shallow flatten/1.
join([])         -> [];
join([X|Xs])     -> join(X, Xs).

join([],     Ys) -> join(Ys);
join([X|Xs], Ys) -> [X|join(Xs, Ys)].

join_test()      -> [1,2,[3],4,5] = join([[1,2,[3]],[4,5]]).


-spec numbered([_]) -> [{pos_integer(), _}].
%% @doc Return Xs with its elements numbered from 1.
numbered(Xs)        -> lists:zip(seq(length(Xs)), Xs).

numbered_test() ->
  []                   = numbered([]),
  [{1, foo}, {2, bar}] = numbered([foo, bar]).

%%%_* Emacs =============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
