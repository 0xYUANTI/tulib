%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Combinators.
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
-module(tulib_combinators).

%%%_* Exports ==========================================================
-export([ compose/1
        , compose/2
        , compose/3
        , compose/4
        , compose/5
        , compose/6
        , compose/7
        , fix/2
        , fix/3
        , flip/1
        , i/1
        , k/1
        , s/1
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").

%%%_* Code =============================================================
compose(F, G)                -> compose([F, G]).
compose(F, G, H)             -> compose([F, G, H]).
compose(F, G, H, I)          -> compose([F, G, H, I]).
compose(F, G, H, I, J)       -> compose([F, G, H, I, J]).
compose(F, G, H, I, J, K)    -> compose([F, G, H, I, J, K]).
compose(F, G, H, I, J, K, L) -> compose([F, G, H, I, J, K, L]).

compose(Fs)                  -> fun(X) -> do_compose(Fs, X) end.

do_compose([],     X)        -> X;
do_compose([F|Fs], X)        -> do_compose(Fs, F(X)).

compose_test() ->
  42 = (compose([]))(42),
  F  = fun(X) -> X+1 end,
  G  = fun(X) -> X*2 end,
  H  = fun(X) -> X-1 end,
  85 = (compose(F, G, H))(42).


-spec flip(fun((A, B) -> C)) -> fun((B, A) -> C).
flip(F) -> fun(X, Y) -> F(Y, X) end.

flip_test() ->
  [3,4,1,2] = lists:foldl(fun lists:append/2,       [], [[1,2], [3,4]]),
  [1,2,3,4] = lists:foldl(flip(fun lists:append/2), [], [[1,2], [3,4]]).


-spec fix(fun(), _) -> _ | no_return().
fix(F, X) ->
  fix(F, X, fun(X1, X2) -> X1 =:= X2 end).

fix(F, X, Eq) ->
  fix(X, F(X), F, Eq).

fix(X1, X2, F, Eq) ->
  case Eq(X1, X2) of
    true  -> X2;
    false -> fix(X2, F(X2), F, Eq)
  end.

fix_test() -> 42 = fix(fun(X) when X rem 2 =:= 0 -> X;
                          (X) when X rem 2 =:= 1 -> X+1
                       end, 41).


s(X) -> fun(Y) -> fun(Z) -> (X(Z))(Y(Z)) end end.
k(X) -> fun(_Y) -> X end.
i(X) -> X.

ski_test() ->
  42 = i(42),
  42 = (k(42))(foo),
  42 = ((s(fun k/1))(fun k/1))(42).

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
