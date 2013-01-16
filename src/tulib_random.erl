%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Utility functions for generating random numbers and such.
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
-module(tulib_random).

%%%_* Exports ==========================================================
-export([ numbers/2
        , pick/1
        , shuffle/1
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").

%%%_* Code =============================================================
-spec numbers(pos_integer(), pos_integer()) -> [pos_integer()].
%% @doc Return a list of random numbers between 0 and Max (must be > 0).
numbers(N, Max) -> [crypto:rand_uniform(0, Max) || _ <- tulib_lists:seq(N)].

numbers_test() ->
  []   = numbers(0, 1 bsl 128),
  [X]  = numbers(1, 1),
  true = X =:= 0 orelse X =:= 1,
  Xs   = numbers(1 bsl 4, 1 bsl 3),
  true = length(Xs) > length(lists:usort(Xs)).


-spec pick([A]) -> A.
%% @doc Randomly select an element from Xs.
pick(Xs) -> lists:nth(crypto:rand_uniform(1, length(Xs) + 1), Xs).


-spec shuffle([_]) -> [_].
%% @doc Return a random permutation of Xs.
shuffle(Xs) ->
  [X || {_N, X} <- lists:keysort(1, [{crypto:rand_uniform(0, length(Xs)), X} ||
                                      X <- Xs])].

shuffle_test() ->
  Xs = tulib_lists:seq(1000),
  ?assert(shuffle(Xs) =/= shuffle(Xs)).

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
