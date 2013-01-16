%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Function invocation.
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
-module(tulib_call).

%%%_* Exports ==========================================================
-export([ dispatch/4
        , multicall/3
        , multi_dispatch/4
        , reduce/1
        , unwind_with/3
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").

%%%_* Code =============================================================
-spec dispatch(fun((A) -> module()), A, atom(), [_]) -> _.
%% @doc Call MFA where M is the result of applying ModuleMap to Key.
dispatch(ModuleMap, Key, F, A) -> apply(ModuleMap(Key), F, A).

-spec multicall([module()], atom(), [_]) -> _.
%% @doc Call MFA for all M in Modules.
multicall(Modules, F, A) -> multi_dispatch(fun(X) -> X end, Modules, F, A).

multicall_test() ->
  M = tulib_combinators,
  [42, 42] = multicall([M, M], i, [42]).

-spec multi_dispatch(fun((A) -> module()), [A], atom(), [_]) -> _.
%% @doc Call MFA for each M resulting from applying ModuleMap to a Key.
multi_dispatch(ModuleMap, Keys, F, A) ->
  [dispatch(ModuleMap, Key, F, A) || Key <- Keys].


-spec reduce(fun(() -> A) | A) -> A.
%% @doc
reduce(X) when is_function(X, 0) -> reduce(X());
reduce(X)                        -> X.

reduce_test() -> 42 = reduce(fun() -> fun() -> 42 end end).


-spec unwind_with(fun(([B]) -> C),
                  [A],
                  fun((A, fun((B) -> C)) -> C)) -> C.
%% @doc
unwind_with(F, Xs, G)         -> unwind_with(Xs, F, G, []).
unwind_with([X|Xs], F, G, Ys) -> F(X, fun(Y) -> unwind_with(Xs, F, G, [Y|Ys]) end);
unwind_with([],     _, G, Ys) -> G(lists:reverse(Ys)).

unwind_with_test() ->
  F         = fun(X, G) ->
                Y = X + 1,
                try G(Y)
                after io:format(user, "Y = ~p~n", [Y])
                end
              end,
  G         = fun(Ys) -> [Y * 2 || Y <- Ys] end,
  [4, 6, 8] = unwind_with(F, [1, 2, 3], G),
  ok.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
