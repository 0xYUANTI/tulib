%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Utility predicates.
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
-module(tulib_predicates).

%%%_* Exports ==========================================================
-export([ is_ip_address/1
        , is_ip_port/1
        , is_list_of/2
        , is_nonempty_list_of/2
        , is_permutation/2
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/guards.hrl").

%%%_* Code =============================================================
%% IPv4
is_ip_address(X) when ?is_ip_address(X) -> true;
is_ip_address(_)                        -> false.

is_ip_port(X) when ?is_ip_port(X)       -> true;
is_ip_port(_)                           -> false.

is_ip_test() ->
  true  = is_ip_address({255,255,255,255}),
  true  = is_ip_port(65535),
  false = is_ip_address({255,255,255,256}),
  false = is_ip_port(-1).


-spec is_list_of([A], fun((A) -> boolean())) -> boolean().
is_list_of(Xs, Pred) -> is_list(Xs) andalso lists:all(Pred, Xs).

-spec is_nonempty_list_of([A], fun((A) -> boolean())) -> boolean().
is_nonempty_list_of(Xs, Pred) -> is_list_of(Xs, Pred) andalso length(Xs) > 0.

is_nonempty_list_of_test() ->
  true  = is_list_of([], fun erlang:is_integer/1),
  false = is_nonempty_list_of([], fun erlang:is_integer/1),
  false = is_nonempty_list_of([1, 2, 3], fun erlang:is_tuple/1),
  true  = is_nonempty_list_of([1, 2, 3], fun erlang:is_integer/1).


-spec is_permutation([A], [A]) -> boolean().
%% @doc Return true iff Xs is a permutation of Ys.
is_permutation(Xs, Ys) -> lists:sort(Xs) =:= lists:sort(Ys).

is_permutation_test() ->
  true  = is_permutation([1,2,3], [1,3,2]),
  false = is_permutation([1,2,3], [1,2,4]).

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
